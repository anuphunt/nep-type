"""Coalescing background candidate lookup, never called synchronously by IBus.

The schedule callback must dispatch onto the host/UI thread. The lookup process
is intentionally experimental; it is not a production native bridge.
"""
import threading
import time
from .bridge import CoreBridge, BridgeError

class CandidateWorker:
    def __init__(self, executable, schedule, deliver, timeout=0.25, core_factory=CoreBridge,
                 retry_delay=1.0, clock=time.monotonic):
        self.executable, self.schedule, self.deliver = executable, schedule, deliver
        self.timeout, self.core_factory = timeout, core_factory
        self.retry_delay, self.clock = max(0.0, retry_delay), clock
        self.condition = threading.Condition()
        self.pending = None
        self.closed = False
        self.thread = threading.Thread(target=self._run, daemon=True, name="neptype-candidate-worker")
        self.thread.start()

    def submit(self, text, generation, language="nepali"):
        with self.condition:
            if not self.closed:
                self.pending = (text, generation, language) # newer text supersedes queued work
                self.condition.notify()

    def close(self):
        # No join, process operation, or callback on the caller's event thread.
        with self.condition:
            self.closed = True
            self.pending = None
            self.condition.notify()

    def _run(self):
        core = None
        core_language = "nepali"
        retry_at = 0.0
        try:
            while True:
                with self.condition:
                    while self.pending is None and not self.closed:
                        self.condition.wait()
                    if self.closed: return
                    text, generation, language = self.pending
                    self.pending = None
                try:
                    # Keep input responsive and avoid repeatedly spawning a
                    # broken or unavailable engine on every keystroke. The
                    # Roman token stays available throughout this cooldown.
                    if core is None and self.clock() < retry_at:
                        raise BridgeError("candidate engine cooling down")
                    if language not in ("nepali", "allNepali"):
                        raise BridgeError("invalid candidate language")
                    if core is None:
                        core = self.core_factory(self.executable, timeout=self.timeout)
                        core_language = "nepali"
                    # Each lookup uses the complete local token. It deliberately
                    # does not reuse preceding-word context across host sessions.
                    core.request("cancel")
                    if language != core_language:
                        switched = core.request("set_language", language=language)
                        switched_state = switched.get("state")
                        if (not isinstance(switched_state, dict) or switched_state.get("language") != language or
                                switched_state.get("composing") is not False or switched_state.get("roman") != ""):
                            raise BridgeError("candidate mode switch failed")
                        core_language = language
                    response = core.request("append", text=text)
                    state = response.get("state")
                    if (not isinstance(state, dict) or state.get("roman") != text or
                            state.get("composing") is not True or state.get("language") != language):
                        # A delayed or duplicated reply can have the same session
                        # ID while belonging to an earlier token. Never present
                        # those candidates as suggestions for the current word.
                        raise BridgeError("candidate response does not match token")
                    values = state.get("candidates")
                    # Do not send an unbounded response to the IBus event
                    # thread. Reject the result rather than partially trusting
                    # a malformed or unexpectedly large response.
                    if (not response.get("accepted") or not isinstance(values, list) or
                            len(values) > 256 or not all(isinstance(v, str) for v in values)):
                        raise BridgeError("invalid candidate response")
                    error = False
                    retry_at = 0.0
                except Exception:
                    values, error = [], True
                    if core is not None:
                        core.close(); core = None
                    # An already-active cooldown must not extend on each key.
                    if self.clock() >= retry_at:
                        retry_at = self.clock() + self.retry_delay
                with self.condition:
                    if self.closed: return
                self.schedule(self.deliver, generation, text, values, error)
        finally:
            if core is not None: core.close()
