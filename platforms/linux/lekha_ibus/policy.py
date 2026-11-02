"""Nonblocking local preedit policy with asynchronous, optional candidates.

Roman text remains the default. Candidate responses are never applied across
input generations, boundaries, focus changes or secure-field transitions.
"""
import unicodedata

BACKSPACE, RETURN, ESCAPE, TAB, ISO_LEFT_TAB = 0xff08, 0xff0d, 0xff1b, 0xff09, 0xfe20
RELEASE_MASK, SHIFT_MASK, CONTROL_MASK, ALT_MASK, SUPER_MASK = 1 << 30, 1 << 0, 1 << 2, 1 << 3, 1 << 26

def literal_purpose(purpose, input_purpose):
    """Pass through host-declared protected and structured input fields.

    Enum members vary by IBus version; unavailable members are ignored.
    The host can misreport purpose, so this is not a security guarantee.
    """
    if purpose is None:
        return True
    names = ("PASSWORD", "PIN", "URL", "EMAIL", "PHONE", "DIGITS", "NUMBER",
             "TERMINAL", "DATE", "TIME", "DATETIME")
    return any(purpose == value for name in names
               if (value := getattr(input_purpose, name, None)) is not None)

def safe_candidate(value):
    # Treat engine data as untrusted, and never allow a suggestion to inject
    # additional lines, host controls or excessive text into the composition.
    return isinstance(value, str) and 0 < len(value) <= 256 and not any(
        # A candidate must remain one token; even non-breaking spaces can
        # otherwise insert extra words or alter the host's surrounding text.
        unicodedata.category(c) in ("Cc", "Cs", "Zs", "Zl", "Zp") or
        (unicodedata.category(c) == "Cf" and c not in ("\u200c", "\u200d"))
        for c in value
    )

class CompositionPolicy:
    def __init__(self, worker, host, language="nepali"):
        if language not in ("nepali", "english", "allNepali"):
            raise ValueError("invalid language")
        self.worker, self.host = worker, host
        self.language = language
        self.raw = ""
        self.options = []
        self.selection = 0
        self.generation = 0
        self.disabled = worker is None
        self.secure = False
        self.closed = False
        self.code_before_token = False

    def _show(self):
        # Keep the original keys in the host-owned preedit even when the
        # lookup panel highlights a candidate. If the host commits preedit on
        # focus loss, it receives the user's keys rather than a preview.
        self.host.preedit(self.raw, bool(self.raw))
        lookup = getattr(self.host, "lookup", None)
        if lookup:
            lookup(self.options if self.raw and len(self.options) > 1 else [], self.selection)

    def _invalidate(self):
        self.generation += 1
        self.options = [self.raw] if self.raw else []
        self.selection = 0

    def _queue(self):
        self._invalidate()
        # Treat an open backtick span as literal. Any backtick in the current
        # token also suppresses suggestions, even when it closes the span.
        if self.raw and not self.code_before_token and "`" not in self.raw:
            self.worker.submit(self.raw, self.generation, self.language)

    def candidates_ready(self, generation, raw, values, error):
        # Called only on the IBus thread by the supplied scheduler.
        if self.closed or self.secure or self.code_before_token or "`" in raw or generation != self.generation or raw != self.raw or not raw:
            return
        if error:
            # Keep the marked original under user control and stop waiting for
            # candidates. A key or focus transition can still commit it.
            self._invalidate()
            self._show()
            return
        self.options = ([raw] + list(dict.fromkeys(v for v in values if safe_candidate(v) and v != raw)))[:9]
        self.selection = 0
        self._show()

    def flush_original(self):
        original = self.raw
        self.raw = ""
        self.code_before_token = False
        self._invalidate()
        if original:
            self.host.commit(original)
            self._show()

    def close(self):
        if self.closed: return
        self.flush_original()
        self.closed = True
        if self.worker: self.worker.close()

    def abandon_unverified_owner(self):
        """Stop without editing a host whose focus/range ownership is unknown.

        IBus can deliver focus-in before an earlier focus-out. The old preedit
        may be lost or remain host-managed, but must not be committed to a
        different client. Never emit the original to logs or another host.
        """
        if self.closed: return
        self.closed = True
        self.raw = ""
        self.code_before_token = False
        self._invalidate()
        if self.worker: self.worker.close()

    def set_secure(self, secure):
        self.secure = secure
        if secure:
            # The content-purpose notification might arrive after focus has
            # changed, so even a "restore original" commit could leak data.
            self.abandon_unverified_owner()

    def set_language(self, language):
        if language not in ("nepali", "english", "allNepali"):
            raise ValueError("invalid language")
        if self.closed or self.language == language:
            return
        # Before switching, give back exactly the original marked keys; an
        # already-selected preview must never be committed by the switch.
        self.flush_original()
        self.language = language

    def process(self, keyval, state):
        if state & RELEASE_MASK or self.disabled or self.secure or self.closed or self.language == "english": return False
        if state & (CONTROL_MASK | ALT_MASK | SUPER_MASK):
            self.flush_original(); return False
        if keyval == ESCAPE and self.raw:
            self.flush_original(); return True
        if keyval in (TAB, ISO_LEFT_TAB) and self.raw:
            if len(self.options) > 1:
                backwards = keyval == ISO_LEFT_TAB or bool(state & SHIFT_MASK)
                self.selection = (self.selection + (-1 if backwards else 1)) % len(self.options)
                self._show(); return True
            # Let focus traversal proceed only after preserving the marked text.
            self.flush_original()
            return False
        if keyval == BACKSPACE and self.raw:
            # Undo a preview first without deleting a character from the
            # original; a second Backspace edits the Roman token normally.
            if self.selection != 0:
                self.selection = 0
                self._show(); return True
            self.raw = self.raw[:-1]
            self._queue(); self._show(); return True
        if 33 <= keyval <= 126:
            if len(self.raw) >= 256:
                self.flush_original(); return False
            self.raw += chr(keyval)
            self._queue(); self._show(); return True
        if self.raw:
            # Only deliberate whitespace boundaries may accept a selected
            # preview. Cursor navigation, forward-delete, non-ASCII input and
            # unknown host keys must preserve the original before handoff.
            if keyval not in (32, RETURN):
                self.flush_original()
                return False
            # Preserve code spans across whitespace. Other host actions or
            # focus transitions reset this context to avoid carrying it to a
            # different client. Escaped/nested backticks remain unsupported.
            next_code = self.code_before_token ^ (self.raw.count("`") % 2 == 1)
            result = self.raw if self.code_before_token or "`" in self.raw else (self.options[self.selection] if self.options else self.raw)
            self.raw = ""
            self.code_before_token = next_code
            self._invalidate()
            self.host.commit(result)
            self._show()
        return False

def should_consume_key(keyval, keycode, state):
    return False
