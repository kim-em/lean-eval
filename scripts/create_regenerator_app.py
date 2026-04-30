#!/usr/bin/env python3
"""Create the lean-eval-regenerator GitHub App via the App Manifest flow.

Spins up a local server, opens GitHub's confirmation page in the browser
with a pre-filled manifest, captures the redirect callback, exchanges the
temporary code for an App ID + private key, sets the repo secrets, and
prints the install URL.

User interaction: click "Create GitHub App" once on github.com, then click
through the install flow.
"""
from __future__ import annotations

import http.server
import json
import os
import secrets
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import urllib.request
import webbrowser

PORT = 8989
STATE = secrets.token_urlsafe(16)
REPO = "leanprover/lean-eval"

MANIFEST = {
    "name": "lean-eval-regenerator",
    "url": "https://github.com/leanprover/lean-eval",
    "hook_attributes": {"active": False, "url": "https://example.com/unused"},
    "redirect_url": f"http://localhost:{PORT}/callback",
    "public": False,
    "default_permissions": {"contents": "write"},
    "default_events": [],
}

result: dict = {}
done = threading.Event()


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):  # quiet
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/start":
            html = f"""<!doctype html><html><body>
<p>Submitting manifest to GitHub…</p>
<form id="f" action="https://github.com/settings/apps/new?state={STATE}" method="post">
  <input type="hidden" name="manifest" value='{json.dumps(MANIFEST).replace("'", "&apos;")}'>
</form>
<script>document.getElementById('f').submit();</script>
</body></html>
"""
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(html.encode())
            return

        if parsed.path == "/callback":
            qs = urllib.parse.parse_qs(parsed.query)
            if qs.get("state", [""])[0] != STATE:
                self.send_response(400); self.end_headers()
                self.wfile.write(b"state mismatch"); return
            code = qs.get("code", [""])[0]
            try:
                req = urllib.request.Request(
                    f"https://api.github.com/app-manifests/{code}/conversions",
                    method="POST",
                    headers={"Accept": "application/vnd.github+json"},
                )
                with urllib.request.urlopen(req) as resp:
                    result.update(json.loads(resp.read()))
            except Exception as e:
                self.send_response(500); self.end_headers()
                self.wfile.write(f"conversion failed: {e}".encode())
                done.set(); return
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(
                b"<h1>App created. You can close this window and return to your terminal.</h1>"
            )
            done.set()
            return

        self.send_response(404); self.end_headers()


def main():
    server = socketserver.TCPServer(("localhost", PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    start_url = f"http://localhost:{PORT}/start"
    print(f"Opening {start_url} in your browser…", flush=True)
    print("On the GitHub page that appears, click 'Create GitHub App'.", flush=True)
    webbrowser.open(start_url)

    if not done.wait(timeout=600):
        print("timed out waiting for callback", file=sys.stderr); sys.exit(1)

    server.shutdown()

    if "id" not in result:
        print("conversion did not return an app:", result, file=sys.stderr); sys.exit(1)

    app_id = result["id"]
    pem = result["pem"]
    slug = result["slug"]
    html_url = result["html_url"]

    print(f"\nApp created.")
    print(f"  Name: {result.get('name')}")
    print(f"  Slug: {slug}")
    print(f"  ID:   {app_id}")
    print(f"  URL:  {html_url}")

    # Persist PEM to disk in case secret-set fails — user can rerun manually.
    pem_path = tempfile.NamedTemporaryFile(
        prefix="lean-eval-regenerator-", suffix=".pem", delete=False
    ).name
    with open(pem_path, "w") as f:
        f.write(pem)
    os.chmod(pem_path, 0o600)
    print(f"  PEM:  {pem_path} (chmod 600)")

    # Set the repo secrets via gh CLI.
    print(f"\nSetting repo secrets on {REPO}…", flush=True)
    subprocess.run(
        ["gh", "secret", "set", "LEAN_EVAL_REGENERATOR_APP_ID",
         "-R", REPO, "--body", str(app_id)],
        check=True,
    )
    with open(pem_path) as f:
        subprocess.run(
            ["gh", "secret", "set", "LEAN_EVAL_REGENERATOR_PRIVATE_KEY",
             "-R", REPO],
            input=f.read(), text=True, check=True,
        )

    print("\nSecrets set:")
    subprocess.run(
        ["gh", "secret", "list", "-R", REPO,
         "--json", "name", "--jq",
         '.[] | select(.name | startswith("LEAN_EVAL_REGENERATOR"))'],
        check=False,
    )

    print(f"\n=> Now click this to install on the repo (1 click + select repo + confirm):")
    print(f"   {html_url}/installations/new")
    print(f"\n=> When done, tell Claude the App ID is {app_id}.")


if __name__ == "__main__":
    main()
