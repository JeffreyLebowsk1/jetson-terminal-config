#!/usr/bin/env python3
"""
Jetson Webcam Server — streams video+audio from a USB camera.

Video: MJPEG stream via ffmpeg → served as multipart/x-mixed-replace
Audio: Opus in WebM container via ffmpeg → served as chunked stream
HTML:  Resizable player with mute toggle + volume slider

Usage:
    python3 webcam-server.py [--port 8920] [--video /dev/video0] [--res 1280x720]
                             [--fps 15] [--audio hw:CARD=C920e] [--no-audio]
                             [--rtp udp://0.0.0.0:5000]
"""

import argparse
import os
import signal
import subprocess
import sys
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from io import BytesIO

# ── Configuration ─────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Jetson Webcam Server")
    p.add_argument("--port", type=int, default=8920)
    p.add_argument("--video", default="/dev/video0", help="V4L2 video device")
    p.add_argument("--res", default="1280x720", help="Resolution WxH")
    p.add_argument("--fps", type=int, default=15, help="Frame rate")
    p.add_argument("--audio", default="auto", help="ALSA device or 'auto' or 'none'")
    p.add_argument("--no-audio", action="store_true", help="Disable audio")
    p.add_argument("--rtp", default=None, help="RTP/UDP source URL (e.g. udp://0.0.0.0:5000)")
    return p.parse_args()


# ── MJPEG Video Stream ───────────────────────────────────────────────

class MJPEGStream:
    """Captures MJPEG frames from ffmpeg and distributes to HTTP clients."""

    def __init__(self, device, resolution, fps, rtp_source=None):
        self.device = device
        self.resolution = resolution
        self.fps = fps
        self.rtp_source = rtp_source
        self.frame = b""
        self.lock = threading.Lock()
        self.event = threading.Event()
        self.process = None

    def start(self):
        if self.rtp_source:
            # Parse udp://host:port from rtp_source
            import re
            m = re.match(r"udp://([^:]+):(\d+)", self.rtp_source)
            host = m.group(1) if m else "0.0.0.0"
            port = m.group(2) if m else "5000"
            # Write SDP so ffmpeg knows it is H264 RTP
            sdp = (
                "v=0\n"
                f"o=- 0 0 IN IP4 {host}\n"
                "s=GStreamer\n"
                f"c=IN IP4 {host}\n"
                "t=0 0\n"
                f"m=video {port} RTP/AVP 96\n"
                "a=rtpmap:96 H264/90000\n"
            )
            sdp_path = "/tmp/webcam_rtp.sdp"
            with open(sdp_path, "w") as f:
                f.write(sdp)
            cmd = [
                "ffmpeg", "-hide_banner", "-loglevel", "warning",
                "-protocol_whitelist", "file,udp,rtp",
                "-fflags", "nobuffer",
                "-flags", "low_delay",
                "-i", sdp_path,
                "-c:v", "mjpeg",
                "-q:v", "5",
                "-r", str(self.fps),
                "-f", "mjpeg",
                "-"
            ]
        else:
            # Direct V4L2 capture
            cmd = [
                "ffmpeg", "-hide_banner", "-loglevel", "error",
                "-f", "v4l2",
                "-input_format", "mjpeg",
                "-video_size", self.resolution,
                "-framerate", str(self.fps),
                "-i", self.device,
                "-c:v", "mjpeg",
                "-q:v", "5",
                "-f", "mjpeg",
                "-"
            ]
        self.process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        t = threading.Thread(target=self._read_frames, daemon=True)
        t.start()

    def _read_frames(self):
        buf = b""
        soi = b"\xff\xd8"  # JPEG start
        eoi = b"\xff\xd9"  # JPEG end
        stream = self.process.stdout
        while True:
            chunk = stream.read(4096)
            if not chunk:
                break
            buf += chunk
            while True:
                start = buf.find(soi)
                if start == -1:
                    buf = b""
                    break
                end = buf.find(eoi, start + 2)
                if end == -1:
                    buf = buf[start:]
                    break
                frame = buf[start:end + 2]
                buf = buf[end + 2:]
                with self.lock:
                    self.frame = frame
                self.event.set()
                self.event.clear()

    def get_frame(self):
        with self.lock:
            return self.frame

    def stop(self):
        if self.process:
            self.process.terminate()


# ── Audio Stream ──────────────────────────────────────────────────────

class AudioStream:
    """Captures audio from ALSA and serves as Opus/WebM chunks."""

    def __init__(self, device):
        self.device = device
        self.process = None

    def start(self):
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error",
            "-f", "alsa",
            "-ac", "1",
            "-ar", "48000",
            "-i", self.device,
            "-c:a", "libopus",
            "-b:a", "64k",
            "-f", "webm",
            "-"
        ]
        self.process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )

    def stop(self):
        if self.process:
            self.process.terminate()


# ── HTML Page ─────────────────────────────────────────────────────────

def build_html(has_audio, port):
    audio_section = ""
    audio_script = ""
    if has_audio:
        audio_section = """
        <div class="audio-controls">
          <button id="muteBtn" onclick="toggleMute()" title="Toggle audio">🔊</button>
          <input type="range" id="volumeSlider" min="0" max="100" value="70"
                 oninput="setVolume(this.value)" title="Volume">
          <span id="volumeLabel">70%</span>
        </div>
        <audio id="audioStream" autoplay></audio>
        """
        audio_script = f"""
        const audio = document.getElementById('audioStream');
        audio.src = '/audio';
        audio.volume = 0.7;

        function toggleMute() {{
          audio.muted = !audio.muted;
          document.getElementById('muteBtn').textContent = audio.muted ? '🔇' : '🔊';
        }}
        function setVolume(v) {{
          audio.volume = v / 100;
          audio.muted = (v == 0);
          document.getElementById('muteBtn').textContent = (v == 0) ? '🔇' : '🔊';
          document.getElementById('volumeLabel').textContent = v + '%';
        }}
        """
    else:
        audio_section = '<div class="audio-controls"><span style="color:#666">Audio not available</span></div>'
        audio_script = "function toggleMute(){} function setVolume(v){}"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Jetson Dog Cam</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    background: #1a1a2e; color: #eee; font-family: 'Segoe UI', system-ui, sans-serif;
    display: flex; flex-direction: column; align-items: center; min-height: 100vh;
    padding: 12px;
  }}
  h1 {{ font-size: 1.1rem; color: #e2b714; margin-bottom: 8px; }}
  .cam-wrapper {{
    position: relative; resize: both; overflow: hidden;
    border: 2px solid #333; border-radius: 8px; background: #000;
    min-width: 320px; min-height: 240px;
    width: 640px; max-width: 95vw;
  }}
  .cam-wrapper img {{
    display: block; width: 100%; height: auto;
  }}
  .controls {{
    display: flex; align-items: center; gap: 12px;
    margin-top: 10px; padding: 8px 16px;
    background: #16213e; border-radius: 6px;
  }}
  .audio-controls {{
    display: flex; align-items: center; gap: 8px;
  }}
  #muteBtn {{
    background: none; border: none; font-size: 1.4rem; cursor: pointer;
    padding: 4px 8px; border-radius: 4px;
  }}
  #muteBtn:hover {{ background: rgba(255,255,255,0.1); }}
  #volumeSlider {{
    width: 120px; accent-color: #e2b714;
  }}
  #volumeLabel {{ font-size: 0.85rem; color: #aaa; min-width: 3ch; }}
  .size-btns {{ display: flex; gap: 6px; }}
  .size-btns button {{
    background: #0f3460; border: 1px solid #444; color: #eee;
    padding: 4px 10px; border-radius: 4px; cursor: pointer; font-size: 0.8rem;
    transition: background 0.15s;
  }}
  .size-btns button:hover {{ background: #1a4a8a; }}
  .size-btns button.active {{ background: #e2b714; color: #1a1a2e; border-color: #e2b714; }}
  .status {{ font-size: 0.75rem; color: #666; margin-top: 6px; }}
  .grip {{
    position: absolute; bottom: 2px; right: 2px;
    width: 16px; height: 16px; cursor: nwse-resize; opacity: 0.4;
  }}
</style>
</head>
<body>
  <h1>🐕 Jetson Dog Cam</h1>
  <div class="cam-wrapper" id="camWrapper">
    <img id="camImg" src="/stream" alt="Webcam stream">
    <svg class="grip" viewBox="0 0 16 16"><path d="M14 16L16 14M10 16L16 10M6 16L16 6" stroke="#888" stroke-width="1.5"/></svg>
  </div>
  <div class="controls">
    {audio_section}
    <div class="size-btns">
      <button id="btnS" onclick="resize(320,'S')">S</button>
      <button id="btnM" onclick="resize(640,'M')" class="active">M</button>
      <button id="btnL" onclick="resize(960,'L')">L</button>
      <button id="btnXL" onclick="resize(1280,'XL')">XL</button>
      <button onclick="toggleFullscreen()">&#x26F6;</button>
    </div>
  </div>
  <div class="status" id="status">Connected</div>
  <script>
    const wrapper = document.getElementById('camWrapper');
    const img = document.getElementById('camImg');

    function resize(w, label) {{
      wrapper.style.width = w + 'px';
      wrapper.style.height = 'auto';
      document.querySelectorAll('.size-btns button').forEach(b => b.classList.remove('active'));
      var btn = document.getElementById('btn' + label);
      if (btn) btn.classList.add('active');
    }}
    function toggleFullscreen() {{
      if (!document.fullscreenElement) {{
        wrapper.requestFullscreen();
      }} else {{
        document.exitFullscreen();
      }}
    }}
    img.onerror = () => {{
      document.getElementById('status').textContent = 'Stream lost — retrying...';
      setTimeout(() => {{ img.src = '/stream?' + Date.now(); }}, 2000);
    }};
    {audio_script}
  </script>
</body>
</html>"""


# ── HTTP Handler ──────────────────────────────────────────────────────

video_stream = None
audio_stream = None
has_audio = False

class CamHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress request logs

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/?"):
            self._serve_html()
        elif self.path.startswith("/stream"):
            self._serve_mjpeg()
        elif self.path == "/audio" and has_audio:
            self._serve_audio()
        else:
            self.send_error(404)

    def _serve_html(self):
        page = build_html(has_audio, args.port).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(page)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(page)

    def _serve_mjpeg(self):
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        import time
        last_frame = b""
        try:
            while True:
                frame = video_stream.get_frame()
                if frame and frame != last_frame:
                    self.wfile.write(b"--frame\r\n")
                    self.wfile.write(b"Content-Type: image/jpeg\r\n")
                    self.wfile.write(f"Content-Length: {len(frame)}\r\n\r\n".encode())
                    self.wfile.write(frame)
                    self.wfile.write(b"\r\n")
                    self.wfile.flush()
                    last_frame = frame
                time.sleep(1.0 / 30)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _serve_audio(self):
        self.send_response(200)
        self.send_header("Content-Type", "audio/webm")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        try:
            while True:
                chunk = audio_stream.process.stdout.read(4096)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass


# ── Auto-detect audio ─────────────────────────────────────────────────

def find_audio_device():
    """Try to find the webcam's built-in mic or any capture device."""
    try:
        out = subprocess.check_output(
            ["arecord", "-l"], stderr=subprocess.DEVNULL, text=True
        )
        # Look for the Logitech webcam mic
        for line in out.splitlines():
            if "920" in line.lower() or "logi" in line.lower() or "webcam" in line.lower():
                # Extract card number
                parts = line.split()
                for i, p in enumerate(parts):
                    if p == "card":
                        card = parts[i + 1].rstrip(":")
                        return f"hw:{card},0"
        # Fallback: try pulse
        result = subprocess.run(
            ["pactl", "list", "short", "sources"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "input" in line.lower() or "monitor" not in line.lower():
                    return "default"
    except Exception:
        pass
    return None


# ── Main ──────────────────────────────────────────────────────────────

args = None

def main():
    global video_stream, audio_stream, has_audio, args
    args = parse_args()

    # Video
    video_stream = MJPEGStream(args.video, args.res, args.fps, rtp_source=args.rtp)
    video_stream.start()
    if args.rtp:
        print(f"[video] Receiving RTP stream from {args.rtp}")
    else:
        print(f"[video] Streaming from {args.video} at {args.res} {args.fps}fps")

    # Audio
    if args.no_audio or args.audio == "none":
        has_audio = False
        print("[audio] Disabled")
    else:
        audio_dev = args.audio if args.audio != "auto" else find_audio_device()
        if audio_dev:
            audio_stream = AudioStream(audio_dev)
            audio_stream.start()
            has_audio = True
            print(f"[audio] Streaming from {audio_dev}")
        else:
            has_audio = False
            print("[audio] No capture device found — video only")

    # Server
    server = HTTPServer(("0.0.0.0", args.port), CamHandler)
    print(f"\n  🐕 Dog Cam running at http://0.0.0.0:{args.port}")
    print(f"     Open in browser: http://{_get_ip()}:{args.port}")
    print(f"     Press Ctrl+C to stop\n")

    def shutdown(sig, frame):
        print("\nShutting down...")
        video_stream.stop()
        if audio_stream:
            audio_stream.stop()
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    server.serve_forever()


def _get_ip():
    """Best-effort LAN IP detection."""
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"


if __name__ == "__main__":
    main()
