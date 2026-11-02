import sys
import shlex
import types
from unittest.mock import patch
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from lekha_ibus.policy import should_consume_key, literal_purpose
from generate_descriptor import build_descriptor

class FoundationTests(unittest.TestCase):
    def test_structured_and_protected_purposes_use_literal_input(self):
        # Enum values are supplied by IBus, not baked into the prototype.
        names = ("PASSWORD", "PIN", "URL", "EMAIL", "PHONE", "DIGITS", "NUMBER", "TERMINAL", "DATE", "TIME", "DATETIME")
        purpose = types.SimpleNamespace(**{name: index + 1 for index, name in enumerate(names)})
        for name in names:
            with self.subTest(name=name): self.assertTrue(literal_purpose(getattr(purpose, name), purpose))
        self.assertTrue(literal_purpose(None, purpose))
        self.assertFalse(literal_purpose(0, purpose))
        # Old GI versions may omit newer names; no None member makes 0 literal.
        self.assertFalse(literal_purpose(0, types.SimpleNamespace(PASSWORD=1, PIN=2)))

    def test_all_events_remain_with_host(self):
        for event in [(ord('a'), 38, 0), (ord('Z'), 52, 1), (0xff08, 22, 0), (0xff0d, 36, 0), (0, 0, 0), (0x1f600, 0, 0)]:
            with self.subTest(event=event):
                self.assertFalse(should_consume_key(*event))

    def test_adapter_passes_events_without_editing(self):
        class FakeEngine:
            def hide_lookup_table(self): pass
        ibus = types.SimpleNamespace(Engine=FakeEngine)
        gobject = types.SimpleNamespace(type_register=lambda _: None)
        repository = types.ModuleType("gi.repository")
        repository.IBus, repository.GObject, repository.GLib = ibus, gobject, types.SimpleNamespace(idle_add=lambda fn,*a:fn(*a))
        gi = types.ModuleType("gi")
        gi.repository = repository
        with patch.dict(sys.modules, {"gi": gi, "gi.repository": repository}):
            from lekha_ibus.engine import LekhaEngine
            adapter = LekhaEngine()
            self.assertFalse(adapter.do_process_key_event(ord("a"), 38, 0))
            self.assertFalse(adapter.do_process_key_event(0xff08, 22, 0))
            self.assertIsNone(adapter.do_reset())

    def test_mock_ibus_preedit_and_focus_commit(self):
        class FakeEngine:
            def __init__(self, *args, **kwargs): self.events = []
            def update_preedit_text(self, text, cursor, visible): self.events.append(("preedit",text,cursor,visible))
            def commit_text(self, text): self.events.append(("commit",text))
            def hide_lookup_table(self): self.events.append(("hide_lookup",))
            def update_lookup_table(self, table, visible): self.events.append(("lookup",table.values,table.cursor,visible)); self.labels = table.labels
        class FakeTable:
            def __init__(self, size, cursor, visible, round): self.values = []; self.labels=[]; self.cursor = cursor
            def append_candidate(self, value): self.values.append(value)
            def append_label(self, value): self.labels.append(value)
        ibus = types.SimpleNamespace(Engine=FakeEngine, Text=types.SimpleNamespace(new_from_string=lambda x:x), LookupTable=types.SimpleNamespace(new=FakeTable), InputPurpose=types.SimpleNamespace(PASSWORD=1,PIN=2,URL=3,TERMINAL=4))
        repository = types.ModuleType("gi.repository")
        repository.IBus, repository.GObject, repository.GLib = ibus, types.SimpleNamespace(type_register=lambda _:None), types.SimpleNamespace(idle_add=lambda fn,*a:fn(*a))
        gi = types.ModuleType("gi"); gi.repository = repository
        class Worker:
            def submit(self, raw, generation, language="nepali"): pass
            def close(self): pass
        with patch.dict(sys.modules, {"gi":gi,"gi.repository":repository}):
            sys.modules.pop("lekha_ibus.engine",None)
            from lekha_ibus.engine import LekhaEngine
            from lekha_ibus.policy import CompositionPolicy
            adapter=LekhaEngine(); adapter.policy=CompositionPolicy(Worker(),adapter)
            self.assertTrue(adapter.do_process_key_event(ord('m'),0,0))
            self.assertTrue(adapter.do_process_key_event(ord('a'),0,0))
            adapter.policy.candidates_ready(adapter.policy.generation, "ma", ["म"], False)
            self.assertIn(("lookup", ["ma", "म"], 0, True), adapter.events)
            self.assertEqual(adapter.labels, ["Original", "Choice"])
            adapter.do_candidate_clicked(1,1,0)
            self.assertEqual(adapter.policy.selection, 0)
            # A queued click from the old table remains ignored after a new
            # generation publishes a completely different list.
            self.assertTrue(adapter.do_process_key_event(ord('n'),0,0))
            adapter.policy.candidates_ready(adapter.policy.generation, "man", ["मन"], False)
            adapter.do_candidate_clicked(1,1,0)
            self.assertEqual(adapter.policy.selection, 0)
            self.assertEqual(adapter.policy.raw, "man")
            adapter.do_focus_out()
            self.assertNotIn(("commit", "man"), adapter.events)
            adapter.do_set_content_type(1,0)
            self.assertFalse(adapter.do_process_key_event(ord('x'),0,0))
            adapter.do_set_content_type(3,0)
            self.assertFalse(adapter.do_process_key_event(ord('x'),0,0))
            adapter.do_set_content_type(4,0)
            self.assertFalse(adapter.do_process_key_event(ord('x'),0,0))

    def test_focus_in_before_focus_out_never_commits_old_token(self):
        class FakeEngine:
            def __init__(self, *args, **kwargs): self.events = []
            def update_preedit_text(self, text, cursor, visible): self.events.append(("preedit",text,cursor,visible))
            def commit_text(self, text): self.events.append(("commit",text))
            def hide_lookup_table(self): self.events.append(("hide",))
            def register_properties(self, props): pass
        class FakeProps:
            def append(self, item): pass
        ibus = types.SimpleNamespace(Engine=FakeEngine, Text=types.SimpleNamespace(new_from_string=lambda x:x),
            Property=types.SimpleNamespace(new=lambda *a: object()), PropList=types.SimpleNamespace(new=FakeProps),
            PropType=types.SimpleNamespace(NORMAL=0), PropState=types.SimpleNamespace(UNCHECKED=0),
            InputPurpose=types.SimpleNamespace(PASSWORD=1,PIN=2))
        repository = types.ModuleType("gi.repository")
        repository.IBus, repository.GObject, repository.GLib = ibus, types.SimpleNamespace(type_register=lambda _:None), types.SimpleNamespace(idle_add=lambda fn,*a:fn(*a))
        gi = types.ModuleType("gi"); gi.repository = repository
        class Worker:
            def __init__(self): self.closed=False
            def submit(self, raw, generation, language="nepali"): pass
            def close(self): self.closed=True
        with patch.dict(sys.modules, {"gi":gi,"gi.repository":repository}):
            sys.modules.pop("lekha_ibus.engine",None)
            from lekha_ibus.engine import LekhaEngine
            from lekha_ibus.policy import CompositionPolicy
            adapter=LekhaEngine(); old_worker=Worker(); old=CompositionPolicy(old_worker,adapter); adapter.policy=old
            old.process(ord('m'),0); old.process(ord('a'),0)
            old_events=list(adapter.events)
            adapter.do_focus_in()
            self.assertEqual(adapter.events,old_events + [("hide",)]) # no edit or preedit in newly focused client
            self.assertTrue(old_worker.closed); self.assertIsNone(adapter.policy)
            old.candidates_ready(old.generation-1,'ma',['म'],False)
            self.assertEqual(adapter.events,old_events + [("hide",)])
            # A purpose change or reset may likewise describe a new client;
            # neither event may commit a previous client's preedit.
            secure_worker=Worker(); adapter.policy=CompositionPolicy(secure_worker,adapter)
            adapter.policy.process(ord('x'),0)
            prior_events=list(adapter.events)
            adapter.do_set_content_type(1,0)
            self.assertEqual(adapter.events,prior_events + [("hide",)])
            self.assertTrue(secure_worker.closed); self.assertIsNone(adapter.policy)
            adapter.do_set_content_type(0,0)
            reset_worker=Worker(); adapter.policy=CompositionPolicy(reset_worker,adapter)
            adapter.policy.process(ord('z'),0)
            prior_events=list(adapter.events)
            adapter.do_reset()
            self.assertEqual(adapter.events,prior_events + [("hide",)])
            self.assertTrue(reset_worker.closed); self.assertIsNone(adapter.policy)

    def test_focus_commit_mode_is_opt_in_and_preedit_is_original(self):
        class FakeEngine:
            def __init__(self, *args, **kwargs): self.events=[]
            def update_preedit_text(self, text, cursor, visible): self.events.append(("default",text,cursor,visible))
            def update_preedit_text_with_mode(self, text, cursor, visible, mode): self.events.append(("mode",text,cursor,visible,mode))
            def update_lookup_table(self, table, visible): pass
            def hide_lookup_table(self): pass
        class FakeTable:
            def __init__(self,*args): pass
            def append_candidate(self, item): pass
            def append_label(self, item): pass
        ibus=types.SimpleNamespace(Engine=FakeEngine,Text=types.SimpleNamespace(new_from_string=lambda x:x),
            LookupTable=types.SimpleNamespace(new=FakeTable),PreeditFocusMode=types.SimpleNamespace(COMMIT=42))
        repository=types.ModuleType("gi.repository")
        repository.IBus,repository.GObject,repository.GLib=ibus,types.SimpleNamespace(type_register=lambda _:None),types.SimpleNamespace(idle_add=lambda fn,*a:fn(*a))
        gi=types.ModuleType("gi"); gi.repository=repository
        class Worker:
            def submit(self, raw, generation, language="nepali"): pass
            def close(self): pass
        with patch.dict(sys.modules,{"gi":gi,"gi.repository":repository}), patch.dict("os.environ",{},clear=True):
            sys.modules.pop("lekha_ibus.engine",None)
            from lekha_ibus.engine import LekhaEngine
            from lekha_ibus.policy import CompositionPolicy,TAB
            adapter=LekhaEngine(); p=CompositionPolicy(Worker(),adapter)
            p.process(ord("m"),0); p.process(ord("a"),0)
            p.candidates_ready(p.generation,"ma",["म"],False); p.process(TAB,0)
            self.assertEqual(adapter.events[-1],("default","ma",2,True))
            self.assertEqual(p.options[p.selection],"म")
            with patch.dict("os.environ",{"LEKHA_IBUS_FOCUS_COMMIT":"1"}):
                p._show()
                self.assertEqual(adapter.events[-1],("mode","ma",2,True,42))
            # Focus callbacks only relinquish ownership: they never issue a
            # cross-client explicit commit. Actual IBus delivery is untested.
            adapter.policy=p; adapter.do_focus_out()
            self.assertTrue(p.closed)
            # Unsupported runtimes keep the ordinary update path.
            with patch.dict("os.environ",{"LEKHA_IBUS_FOCUS_COMMIT":"1"}):
                saved = ibus.PreeditFocusMode
                del ibus.PreeditFocusMode
                try:
                    adapter.preedit("roman",True)
                    self.assertEqual(adapter.events[-1],("default","roman",5,True))
                finally:
                    ibus.PreeditFocusMode = saved

    def test_descriptor_is_valid_xml_and_respects_paths(self):
        root = ET.fromstring(build_descriptor(Path('/tmp/Lekha project'), '/usr/bin/python3'))
        self.assertEqual(root.findtext('name'), 'org.freedesktop.IBus.Lekha')
        self.assertEqual(shlex.split(root.findtext("exec")), [str((Path("/tmp/Lekha project") / "run-engine.sh").resolve()), "/usr/bin/python3"])
        self.assertEqual(root.findtext('engines/engine/name'), 'lekha')
        self.assertIn('experimental', root.findtext('engines/engine/longname'))
        self.assertIn('Pass-through by default', root.findtext('engines/engine/description'))

    def test_focus_id_late_old_focus_out_does_not_abandon_new_context(self):
        class FakeEngine:
            def __init__(self, *args, **kwargs): self.events = []; self.construct_kwargs = kwargs
            def update_preedit_text(self, text, cursor, visible): self.events.append(("preedit", text))
            def commit_text(self, text): self.events.append(("commit", text))
            def hide_lookup_table(self): self.events.append(("hide",))
            def register_properties(self, props): pass
        class FakeProps:
            def append(self, item): pass
        ibus = types.SimpleNamespace(Engine=FakeEngine, Text=types.SimpleNamespace(new_from_string=lambda x:x),
            Property=types.SimpleNamespace(new=lambda *a: object()), PropList=types.SimpleNamespace(new=FakeProps),
            PropType=types.SimpleNamespace(NORMAL=0), PropState=types.SimpleNamespace(UNCHECKED=0),
            InputPurpose=types.SimpleNamespace(PASSWORD=1,PIN=2))
        repository = types.ModuleType("gi.repository")
        repository.IBus, repository.GObject, repository.GLib = ibus, types.SimpleNamespace(type_register=lambda _:None), types.SimpleNamespace(idle_add=lambda fn,*a:fn(*a))
        gi = types.ModuleType("gi"); gi.repository = repository
        class Worker:
            def __init__(self): self.closed=False
            def submit(self, raw, generation, language="nepali"): pass
            def close(self): self.closed=True
        with patch.dict(sys.modules, {"gi":gi,"gi.repository":repository}), patch.dict("os.environ", {"LEKHA_IBUS_FOCUS_ID":"1"}):
            sys.modules.pop("lekha_ibus.engine",None)
            from lekha_ibus.engine import LekhaEngine
            from lekha_ibus.policy import CompositionPolicy
            adapter=LekhaEngine()
            self.assertTrue(adapter.construct_kwargs["has_focus_id"])
            self.assertFalse(adapter.do_process_key_event(ord("a"),0,0)) # no known context
            adapter.do_focus_in_id("/context/old", "generic toolkit")
            old_worker=Worker(); old=CompositionPolicy(old_worker, adapter); adapter.policy=old
            old.process(ord("a"),0)
            adapter.do_focus_in_id("/context/new", "generic toolkit")
            self.assertTrue(old.closed); self.assertTrue(old_worker.closed)
            self.assertNotIn(("commit", "a"), adapter.events)
            new_worker=Worker(); current=CompositionPolicy(new_worker, adapter); adapter.policy=current
            current.process(ord("b"),0); before=list(adapter.events)
            adapter.do_focus_out_id("/context/old")
            self.assertEqual(adapter.events, before)
            self.assertIs(adapter.policy, current)
            self.assertFalse(current.closed); self.assertEqual(current.raw, "b")
            adapter.do_focus_out_id("/context/new")
            self.assertTrue(current.closed); self.assertTrue(new_worker.closed)
            self.assertNotIn(("commit", "b"), adapter.events)
            self.assertFalse(adapter.do_process_key_event(ord("c"),0,0))
            adapter.do_focus_in_id("invalid", "client")
            self.assertFalse(adapter.do_process_key_event(ord("c"),0,0))

if __name__ == '__main__':
    unittest.main()
