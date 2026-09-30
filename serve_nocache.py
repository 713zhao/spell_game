"""Static file server for the dev web builds that disables browser caching,
so a rebuilt app is picked up on a normal reload."""
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1])
    ThreadingHTTPServer(("0.0.0.0", port), partial(NoCacheHandler)).serve_forever()
