#!/usr/bin/env python3
import http.server
import pathlib
import sys


document = pathlib.Path(sys.argv[2]) / "secret.txt"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            body = document.read_bytes()
        except PermissionError:
            self.send_error(403, "SELinux denied access")
            return
        except OSError:
            self.send_error(404, "File unavailable")
            return
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format_string, *args):
        print(format_string % args, flush=True)


http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
