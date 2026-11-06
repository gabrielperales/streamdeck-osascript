#!/usr/bin/env python3
"""End-to-end test that plays the part of the Stream Deck app.

It launches the real plugin binary from a .sdPlugin folder the way Stream Deck
does (-port/-pluginUUID/-registerEvent/-info), serves the WebSocket the plugin
connects to, and drives it with willAppear/keyDown events. Scripts prove they
ran by writing a marker file. This covers what the unit tests do not: the
compiled binary, argument parsing and the WebSocket layer (ESDConnectionManager).

Usage: python3 Tests/fake_streamdeck.py [--arch arm64|x86_64] path/to/com.example.sdPlugin

--arch runs one slice of a universal binary (x86_64 needs Rosetta on Apple silicon).

Standard library only, so it runs on a stock macOS runner.
"""

import base64
import hashlib
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
TIMEOUT = 15  # seconds to wait for the plugin at each step


class WebSocketConnection:
    """Minimal RFC 6455 server side: text/binary messages, ping, close."""

    def __init__(self, sock):
        self.sock = sock
        self.buffer = b""

    def _read_exact(self, n):
        while len(self.buffer) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("plugin closed the connection")
            self.buffer += chunk
        data, self.buffer = self.buffer[:n], self.buffer[n:]
        return data

    def handshake(self):
        while b"\r\n\r\n" not in self.buffer:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("connection closed during handshake")
            self.buffer += chunk
        head, self.buffer = self.buffer.split(b"\r\n\r\n", 1)
        headers = {}
        for line in head.decode("latin-1").split("\r\n")[1:]:
            name, _, value = line.partition(":")
            headers[name.strip().lower()] = value.strip()
        key = headers.get("sec-websocket-key")
        if not key:
            raise ConnectionError("not a WebSocket upgrade request")
        accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
        self.sock.sendall(
            (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
            ).encode()
        )

    def _send_frame(self, opcode, payload):
        header = bytes([0x80 | opcode])
        length = len(payload)
        if length < 126:
            header += bytes([length])
        elif length < 1 << 16:
            header += bytes([126]) + struct.pack(">H", length)
        else:
            header += bytes([127]) + struct.pack(">Q", length)
        self.sock.sendall(header + payload)

    def send_json(self, obj):
        self._send_frame(0x1, json.dumps(obj).encode())

    def receive_json(self):
        message = b""
        while True:
            b1, b2 = self._read_exact(2)
            fin, opcode = b1 & 0x80, b1 & 0x0F
            length = b2 & 0x7F
            if length == 126:
                (length,) = struct.unpack(">H", self._read_exact(2))
            elif length == 127:
                (length,) = struct.unpack(">Q", self._read_exact(8))
            mask = self._read_exact(4) if b2 & 0x80 else b"\0\0\0\0"
            payload = bytes(c ^ mask[i % 4] for i, c in enumerate(self._read_exact(length)))
            if opcode == 0x8:
                raise ConnectionError("plugin sent close")
            if opcode == 0x9:
                self._send_frame(0xA, payload)
                continue
            if opcode == 0xA:
                continue
            message += payload
            if fin:
                return json.loads(message.decode())

    def close(self):
        try:
            self._send_frame(0x8, struct.pack(">H", 1000))
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.sock.close()


def wait_for_file(path, timeout=TIMEOUT):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if os.path.exists(path):
            with open(path) as f:
                content = f.read()
            if content:
                return content
        time.sleep(0.1)
    return None


def main():
    args = sys.argv[1:]
    arch = None
    if len(args) == 3 and args[0] == "--arch":
        arch, args = args[1], args[2:]
    if len(args) != 1:
        sys.exit(__doc__)
    plugin_dir = os.path.abspath(args[0])
    with open(os.path.join(plugin_dir, "manifest.json")) as f:
        manifest = json.load(f)
    binary = os.path.join(plugin_dir, manifest["CodePath"])
    action_uuid = manifest["Actions"][0]["UUID"]
    plugin_uuid = "fake-streamdeck-plugin-instance"

    # .streamDeckPlugin packages (from `streamdeck pack` and the older
    # DistributionTool alike) do not keep the executable bit; the Stream Deck
    # app sets it when it installs the plugin, so do the same here.
    if not os.access(binary, os.X_OK):
        print(f"note: {manifest['CodePath']} is not executable; setting +x as Stream Deck does on install")
        os.chmod(binary, os.stat(binary).st_mode | 0o111)

    failures = []

    def check(condition, description):
        print(("ok   " if condition else "FAIL ") + description)
        if not condition:
            failures.append(description)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    server.settimeout(TIMEOUT)
    port = server.getsockname()[1]

    info = {
        "application": {"language": "en", "platform": "mac", "version": "6.4.0"},
        "devices": [{"id": "fake-device", "type": 0, "size": {"columns": 5, "rows": 3}}],
    }
    launcher = ["arch", f"-{arch}"] if arch else []
    process = subprocess.Popen(
        launcher + [binary, "-port", str(port), "-pluginUUID", plugin_uuid,
         "-registerEvent", "registerPlugin", "-info", json.dumps(info)],
        cwd=plugin_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    tmp = tempfile.mkdtemp(prefix="fake-streamdeck-")
    connection = None
    try:
        sock, _ = server.accept()
        sock.settimeout(TIMEOUT)
        connection = WebSocketConnection(sock)
        connection.handshake()

        registration = connection.receive_json()
        check(registration.get("event") == "registerPlugin"
              and registration.get("uuid") == plugin_uuid,
              f"plugin registers itself ({registration})")

        def press_key(context, language, script):
            connection.send_json({
                "event": "willAppear", "action": action_uuid, "context": context,
                "device": "fake-device",
                "payload": {"settings": {"language": language, "scriptText": script},
                            "coordinates": {"column": 0, "row": 0}, "state": 0,
                            "isInMultiAction": False},
            })
            for event in ("keyDown", "keyUp"):
                connection.send_json({
                    "event": event, "action": action_uuid, "context": context,
                    "device": "fake-device",
                    "payload": {"settings": {}, "coordinates": {"column": 0, "row": 0},
                                "state": 0, "isInMultiAction": False},
                })

        applescript_marker = os.path.join(tmp, "applescript")
        press_key("key-applescript", "AppleScript",
                  f'do shell script "printf applescript > " & quoted form of "{applescript_marker}"')
        check(wait_for_file(applescript_marker) == "applescript",
              "AppleScript key runs its script on keyDown")

        jxa_marker = os.path.join(tmp, "jxa")
        press_key("key-jxa", "JavaScript",
                  "var app = Application.currentApplication(); app.includeStandardAdditions = true; "
                  f"app.doShellScript('printf jxa > ' + {json.dumps(jxa_marker)});")
        check(wait_for_file(jxa_marker) == "jxa", "JavaScript (JXA) key runs its script on keyDown")

        # A key dropped from the action list appears with no script; the script
        # typed in the Property Inspector arrives as didReceiveSettings.
        edited_marker = os.path.join(tmp, "edited")
        connection.send_json({
            "event": "willAppear", "action": action_uuid, "context": "key-edited",
            "device": "fake-device",
            "payload": {"settings": {}, "coordinates": {"column": 1, "row": 0},
                        "state": 0, "isInMultiAction": False},
        })
        connection.send_json({
            "event": "didReceiveSettings", "action": action_uuid, "context": "key-edited",
            "device": "fake-device",
            "payload": {"settings": {"language": "AppleScript", "scriptText":
                        f'do shell script "printf edited > " & quoted form of "{edited_marker}"'},
                        "coordinates": {"column": 1, "row": 0}, "isInMultiAction": False},
        })
        for event in ("keyDown", "keyUp"):
            connection.send_json({
                "event": event, "action": action_uuid, "context": "key-edited",
                "device": "fake-device",
                "payload": {"settings": {}, "coordinates": {"column": 1, "row": 0},
                            "state": 0, "isInMultiAction": False},
            })
        check(wait_for_file(edited_marker) == "edited",
              "a script saved in the Property Inspector (didReceiveSettings) runs without the key reappearing")

        broken_marker = os.path.join(tmp, "after-error")
        press_key("key-broken", "AppleScript", "this is not valid AppleScript (")
        press_key("key-after-error", "AppleScript",
                  f'do shell script "printf ok > " & quoted form of "{broken_marker}"')
        check(wait_for_file(broken_marker) == "ok", "a script error does not stop later keys")
        check(process.poll() is None, "plugin is still running after a script error")

        connection.close()
        connection = None
        try:
            code = process.wait(timeout=TIMEOUT)
            check(code == 0, f"plugin exits cleanly when Stream Deck closes the socket (exit {code})")
        except subprocess.TimeoutExpired:
            check(False, "plugin exits when Stream Deck closes the socket")
    except (ConnectionError, socket.timeout, OSError, ValueError) as error:
        check(False, f"WebSocket session with the plugin: {error!r}")
    finally:
        if connection:
            connection.close()
        if process.poll() is None:
            process.kill()
        output = process.communicate()[0].decode(errors="replace")
        server.close()

    if failures:
        print("\nPlugin output:\n" + output)
        sys.exit(f"{len(failures)} check(s) failed")
    print("\nAll end-to-end checks passed")


if __name__ == "__main__":
    main()
