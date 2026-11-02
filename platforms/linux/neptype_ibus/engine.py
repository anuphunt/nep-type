"""Opt-in asynchronous IBus experiment; unverified in a real IBus session."""
import os
from gi.repository import GObject, IBus, GLib
from .policy import CompositionPolicy, literal_purpose
from .worker import CandidateWorker

class NepTypeEngine(IBus.Engine):
    __gtype_name__ = "NepTypeExperimentalEngine"

    def __init__(self, *args, **kwargs):
        # IBus's optional focus-id API identifies *input contexts*, not apps.
        # Enable only by explicit experiment until tested against real GI and
        # IBus versions. Older daemons keep the conservative untagged path.
        self.focus_id_mode = os.environ.get("NEPTYPE_IBUS_FOCUS_ID") == "1"
        if self.focus_id_mode:
            kwargs["has_focus_id"] = True
        super().__init__(*args, **kwargs)
        self.policy = None
        self.secure = False
        self.active_context_id = None
        # In-memory engine-wide mode; IBus client identifiers cannot reliably
        # distinguish apps on all supported desktops, so do not persist per-app.
        self.language = "nepali"

    def _mode_property(self):
        label = {"nepali": "नेपाली", "english": "English", "allNepali": "सबै ने"}[self.language]
        tooltip = ("Finish or cancel the current word before switching language."
                   if self.policy and self.policy.raw else
                   "Cycle Nepali + EN, English and All Nepali suggestions. Tab or Shift-Tab previews a choice; Space or Return uses it. Backspace restores the original.")
        return IBus.Property.new(
            "neptype-language", IBus.PropType.NORMAL,
            IBus.Text.new_from_string(label), "",
            IBus.Text.new_from_string(tooltip),
            True, True, IBus.PropState.UNCHECKED, None,
        )

    def _register_mode(self):
        props = IBus.PropList.new()
        props.append(self._mode_property())
        self.register_properties(props)

    def do_enable(self):
        self._register_mode()

    def _forget_policy(self):
        if self.policy:
            self.policy.abandon_unverified_owner()
            self.policy = None
            # The lookup panel can contain a previous client's text. Hiding
            # it is a UI operation only; never edit the unverified recipient.
            self.hide_lookup_table()

    def do_focus_in(self):
        # Upstream IBus can deliver focus-in before the old focus-out. Without
        # verified context IDs we cannot send the old token to this client.
        self.active_context_id = None
        self._forget_policy()
        self._register_mode()

    def do_focus_in_id(self, object_path, client):
        # Never retain the client name: it is often a generic toolkit name,
        # and is not needed to associate an out-of-order focus-out event.
        self._forget_policy()
        self.active_context_id = object_path if isinstance(object_path, str) and object_path.startswith("/") else None
        self._register_mode()

    def do_focus_out_id(self, object_path):
        # A delayed focus-out for a different context must not abandon the
        # currently focused client's composition or candidate worker.
        if self.active_context_id is None or object_path != self.active_context_id:
            return
        self.active_context_id = None
        self._forget_policy()

    def do_property_activate(self, name, state):
        if name != "neptype-language":
            return
        # Property callbacks carry no input-context ID. They may be delivered
        # after focus moved, so do not commit a possibly old token to the
        # current host to accomplish a mode switch. User can finish the token
        # and switch afterward; no raw text is discarded or logged here.
        if self.policy and self.policy.raw:
            self.update_property(self._mode_property())
            return
        target = {"nepali": "english", "english": "allNepali", "allNepali": "nepali"}[self.language]
        if self.policy:
            self.policy.set_language(target)
        self.language = target
        self.update_property(self._mode_property())

    def preedit(self, text, visible):
        rendered = IBus.Text.new_from_string(text)
        # Experimental: ask IBus to commit its original Roman preedit on
        # focus loss. This is off by default until real hosts are tested.
        # We never call commit_text from a focus callback with unknown owner.
        focus_mode = getattr(IBus, "PreeditFocusMode", None)
        update = getattr(self, "update_preedit_text_with_mode", None)
        if (os.environ.get("NEPTYPE_IBUS_FOCUS_COMMIT") == "1" and
                focus_mode is not None and hasattr(focus_mode, "COMMIT") and callable(update)):
            update(rendered, len(text), visible, focus_mode.COMMIT)
        else:
            self.update_preedit_text(rendered, len(text), visible)

    def commit(self, text):
        self.commit_text(IBus.Text.new_from_string(text))

    def lookup(self, options, selection):
        if not options:
            self.hide_lookup_table()
            return
        # Bound the list to a single page so callback indices are unambiguous.
        options = options[:9]
        table = IBus.LookupTable.new(9, min(selection, len(options) - 1), True, True)
        for index, value in enumerate(options):
            table.append_candidate(IBus.Text.new_from_string(value))
            # These are descriptive labels, not numeric key shortcuts.
            label = "Original" if index == 0 else "Choice"
            table.append_label(IBus.Text.new_from_string(label))
        self.update_lookup_table(table, True)

    def do_candidate_clicked(self, index, button, state):
        # IBus supplies no generation identifier with a click. A queued click
        # could refer to a replaced table, so never apply it to current text.
        # Tab remains the explicit, generation-local selection mechanism.
        pass

    def _ensure_policy(self):
        if self.policy is None:
            executable = os.environ.get("NEPTYPE_IBUS_CORE_EXECUTABLE")
            policy = CompositionPolicy(None, self, language=self.language)
            # Launching, IPC and teardown happen only in the worker thread.
            if executable and os.path.isabs(executable):
                worker = CandidateWorker(executable, GLib.idle_add, policy.candidates_ready)
                policy.worker, policy.disabled = worker, False
            policy.secure = self.secure
            self.policy = policy
        return self.policy

    def do_process_key_event(self, keyval, keycode, state):
        if self.secure or (self.focus_id_mode and self.active_context_id is None): return False
        return self._ensure_policy().process(keyval, state)

    def do_reset(self):
        self._forget_policy()

    def do_focus_out(self):
        self.active_context_id = None
        self._forget_policy()

    def do_disable(self): self.do_focus_out()

    def do_set_content_type(self, purpose, hints):
        # Structured fields such as URLs and terminals should receive literal
        # input too. Host declarations are hints, never proof of safety.
        self.secure = literal_purpose(purpose, IBus.InputPurpose)
        if self.policy and self.secure:
            self._forget_policy()

GObject.type_register(NepTypeEngine)
