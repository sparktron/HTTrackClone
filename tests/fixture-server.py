#!/usr/bin/env python3
"""Deterministic loopback HTTP/HTTPS fixture for the crawl test suite."""

import argparse
import html
import http.server
import signal
import ssl
import threading
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


GIF = (
    b"GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04"
    b"\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;"
)


class FixtureHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, _format, *_args):
        pass

    def send_bytes(self, status, body, content_type="text/html; charset=utf-8", headers=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for name, value in headers or ():
            self.send_header(name, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def send_html(self, body, charset="utf-8", headers=None):
        self.send_bytes(200, body.encode(charset), f"text/html; charset={charset}", headers)

    def do_GET(self):
        parsed = urlsplit(self.path)
        path = parsed.path

        if path == "/simple/basic.html":
            self.send_html(
                """<!doctype html><link rel=stylesheet href=/simple/site.css>
                <img src=/assets/pixel.gif><a href=/simple/next.html>next</a>
                <a href=/redirect/simple>redirect</a>"""
            )
        elif path == "/simple/next.html":
            self.send_html("<!doctype html><title>next</title>")
        elif path == "/simple/final.html":
            self.send_html("<!doctype html><title>redirect target</title>")
        elif path == "/simple/site.css":
            self.send_bytes(200, b"body { background: url('/assets/pixel.gif'); }", "text/css")
        elif path == "/assets/pixel.gif":
            self.send_bytes(200, GIF, "image/gif")
        elif path == "/redirect/simple":
            self.send_response(302)
            self.send_header("Location", "/simple/final.html")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif path == "/cookies/entrance.php":
            self.send_html(
                "<a href=/cookies/second.html>cookie-protected page</a>",
                headers=[("Set-Cookie", "fixture=accepted; Path=/cookies")],
            )
        elif path in ("/cookies/second.html", "/cookies/third.html"):
            if "fixture=accepted" not in self.headers.get("Cookie", ""):
                self.send_bytes(403, b"missing cookie", "text/plain")
            elif path.endswith("second.html"):
                self.send_html("<a href=/cookies/third.html>third</a>")
            else:
                self.send_html("<!doctype html><title>cookie complete</title>")
        elif path == "/unicode-links/idna.html":
            port = self.server.server_port
            self.send_html(
                "<a href='/unicode-links/caf%C3%A9.html'>unicode path</a>"
                f"<a href='http://café.invalid:{port}/filtered.html'>IDNA link</a>"
            )
        elif path in ("/unicode-links/caf%C3%A9.html", "/unicode-links/café.html"):
            self.send_html("<!doctype html><title>café</title>")
        elif path == "/unicode-links/bogus.html":
            self.send_bytes(200, b"<a href='http://\xff.invalid/'>bad hostname</a>")
        elif path.startswith("/international/") and path.endswith(".html"):
            charset = {
                "/international/iso88591.html": "iso-8859-1",
                "/international/gb18030.html": "gb18030",
            }.get(path, "utf-8")
            body = "<!doctype html><a href='/international/result.html?q=café'>café</a>"
            self.send_html(body, charset=charset)
        elif path == "/international/result.html":
            value = html.escape(parse_qs(parsed.query).get("q", [""])[0])
            self.send_html(f"<!doctype html><title>{value}</title>")
        elif path == "/overflow/longquerywithaccents.php":
            query = ("café-" * 900).encode("utf-8").hex()
            self.send_html(f"<a href='/overflow/result.html?q={query}'>long URL</a>")
        elif path == "/overflow/result.html":
            self.send_html("<!doctype html><title>long URL target</title>")
        elif path == "/parsing/events.html":
            self.send_html(
                """<!doctype html><body background=/parsing/background.gif
                onload="location='/parsing/event-target.html'">
                <script>var next = '/parsing/script-target.html';</script></body>"""
            )
        elif path == "/parsing/css.html":
            self.send_html("<style>body{background:url('/parsing/background.gif')}</style>")
        elif path == "/parsing/javascript.html":
            self.send_html("<script src=/parsing/app.js></script>")
        elif path == "/parsing/app.js":
            self.send_bytes(200, b"location.href='/parsing/script-target.html';", "text/javascript")
        elif path == "/parsing/query.html":
            self.send_html("<a href='/parsing/query-target.html?a=1&amp;b=two'>query</a>")
        elif path == "/parsing/hash.html":
            self.send_html("<a href='/parsing/hash-target.html#fragment'>fragment</a>")
        elif path.startswith("/parsing/"):
            content_type = "image/gif" if path.endswith(".gif") else "text/html; charset=utf-8"
            body = GIF if path.endswith(".gif") else b"<!doctype html><title>parsed target</title>"
            self.send_bytes(200, body, content_type)
        else:
            self.send_bytes(404, b"not found", "text/plain")


def serve(server):
    server.serve_forever(poll_interval=0.05)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()

    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
    httpsd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(args.cert, args.key)
    httpsd.socket = context.wrap_socket(httpsd.socket, server_side=True)

    Path(args.state).write_text(
        f"FIXTURE_HTTP_PORT={httpd.server_port}\nFIXTURE_HTTPS_PORT={httpsd.server_port}\n",
        encoding="ascii",
    )

    stopping = threading.Event()

    def stop(_signum, _frame):
        stopping.set()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    threads = [threading.Thread(target=serve, args=(server,), daemon=True) for server in (httpd, httpsd)]
    for thread in threads:
        thread.start()
    stopping.wait()
    for server in (httpd, httpsd):
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
