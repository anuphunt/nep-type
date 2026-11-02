"""Opt-in, bounded experimental bridge to lekha-conformance; not a production ABI."""
import json
import os
import select
import subprocess
import time
import threading
import uuid

class BridgeError(Exception):
    pass

def core_environment(source):
    """Pass only the core's local resource paths and locale to the child.

    Environment variables can contain unrelated credentials. The configured
    executable still receives typed tokens over stdin, so it must be trusted.
    """
    allowed = ("LEKHA_ALIAS_INDEX", "LEKHA_AKSHARANTAR_INDEX", "LANG", "LC_ALL", "LC_CTYPE")
    return {key: source[key] for key in allowed if key in source}

class CoreBridge:
    def __init__(self, executable, timeout=0.100):
        self.timeout = timeout
        self.id = uuid.uuid4().hex
        self.buffer = b""
        try:
            self.process = subprocess.Popen([executable], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                            stderr=subprocess.DEVNULL, bufsize=0,
                                            env=core_environment(os.environ))
            # A stuck or misbehaving child must not leave the worker blocked in
            # a pipe write after focus loss. Requests use bounded nonblocking
            # writes and the same deadline as the response.
            os.set_blocking(self.process.stdin.fileno(), False)
            self.request("create")
        except Exception as exc:
            self.close()
            raise BridgeError("core unavailable") from exc

    def request(self, op, **args):
        request = {"id": self.id, "op": op, **args}
        try:
            data = (json.dumps(request, ensure_ascii=False) + "\n").encode()
            if len(data) > 8192:
                raise BridgeError("oversized core request")
            deadline = time.monotonic() + self.timeout
            sent = 0
            while sent < len(data):
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([], [self.process.stdin], [], remaining)[1]:
                    raise BridgeError("core write timed out")
                try:
                    written = os.write(self.process.stdin.fileno(), data[sent:])
                except BlockingIOError:
                    continue
                if written <= 0:
                    raise BridgeError("core write failed")
                sent += written
            while b"\n" not in self.buffer:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                    raise BridgeError("core timed out")
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise BridgeError("core closed")
                self.buffer += chunk
                if len(self.buffer) > 1_000_000:
                    raise BridgeError("oversized core response")
            line, self.buffer = self.buffer.split(b"\n", 1)
            response = json.loads(line.decode("utf-8"))
            if response.get("id") != self.id or not response.get("ok"):
                raise BridgeError("invalid core response")
            return response
        except (OSError, ValueError, BrokenPipeError) as exc:
            raise BridgeError("core request failed") from exc

    def close(self):
        process = getattr(self, "process", None)
        if process is not None:
            if process.poll() is None:
                try: process.terminate()
                except ProcessLookupError: pass
            # Reap off the event thread; a stubborn child is killed after 0.5s.
            def reap():
                try: process.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            threading.Thread(target=reap, daemon=True).start()
            for stream in (process.stdin, process.stdout):
                if stream:
                    stream.close()
            self.process = None
