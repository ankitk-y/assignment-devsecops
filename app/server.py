# Placeholder voice-gateway service. Not the focus of this exercise.
import http.server, socketserver

PORT = 8080

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
