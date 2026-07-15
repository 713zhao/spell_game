"""Static file server for build/web that disables caching, so phones and
other devices always fetch the latest rebuild instead of a stale copy
(mobile browsers otherwise cache aggressively with no explicit headers)."""
import http.server
import socketserver
import os

PORT = 8080
os.chdir(os.path.join(os.path.dirname(__file__), "build", "web"))


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


with ReusableTCPServer(("0.0.0.0", PORT), NoCacheHandler) as httpd:
    print(f"Serving build/web on 0.0.0.0:{PORT} with caching disabled")
    httpd.serve_forever()
