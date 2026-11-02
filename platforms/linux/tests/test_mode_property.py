import sys
import types
import unittest
from unittest.mock import patch

class ModePropertyTests(unittest.TestCase):
    def test_mode_property_and_focus_recreation(self):
        class FakeEngine:
            def __init__(self, *a, **kw): self.events = []
            def register_properties(self, props): self.events.append(('register', props.items[0].label))
            def update_property(self, prop): self.events.append(('update', prop.label))
            def commit_text(self, text): self.events.append(('commit', text))
            def update_preedit_text(self, text, cursor, visible): self.events.append(('preedit', text, visible))
            def hide_lookup_table(self): pass
        class FakeProp:
            @staticmethod
            def new(key, kind, label, icon, tooltip, sensitive, visible, state, children):
                return types.SimpleNamespace(key=key, label=label, tooltip=tooltip)
        class FakeList:
            def __init__(self): self.items=[]
            @staticmethod
            def new(): return FakeList()
            def append(self, value): self.items.append(value)
        ibus=types.SimpleNamespace(Engine=FakeEngine, Text=types.SimpleNamespace(new_from_string=lambda x:x),
            Property=FakeProp, PropList=FakeList, PropType=types.SimpleNamespace(NORMAL=0), PropState=types.SimpleNamespace(UNCHECKED=0))
        repository=types.ModuleType('gi.repository'); repository.IBus=ibus
        repository.GObject=types.SimpleNamespace(type_register=lambda _:None)
        repository.GLib=types.SimpleNamespace(idle_add=lambda fn,*a:fn(*a))
        gi=types.ModuleType('gi'); gi.repository=repository
        with patch.dict(sys.modules, {'gi':gi, 'gi.repository':repository}):
            sys.modules.pop('neptype_ibus.engine', None)
            from neptype_ibus.engine import NepTypeEngine
            from neptype_ibus.policy import CompositionPolicy
            class Worker:
                def submit(self,*args): pass
                def close(self): pass
            e=NepTypeEngine(); e.do_enable(); self.assertIn(('register','नेपाली'),e.events)
            self.assertIn('Tab or Shift-Tab', e._mode_property().tooltip)
            self.assertIn('Space or Return', e._mode_property().tooltip)
            self.assertIn('Backspace restores', e._mode_property().tooltip)
            e.policy=CompositionPolicy(Worker(),e)
            self.assertTrue(e.do_process_key_event(ord('m'),0,0))
            e.do_property_activate('wrong-property', 0)
            self.assertEqual(e.language, 'nepali')
            e.do_property_activate('neptype-language', 0)
            self.assertEqual(e.language, 'nepali')
            self.assertEqual(e.policy.raw, 'm')
            self.assertNotIn(('commit','m'),e.events)
            self.assertIn('Finish or cancel', e._mode_property().tooltip)
            # The user may explicitly finish the word, then switch. A queued
            # property event itself never commits an unverified composition.
            self.assertFalse(e.do_process_key_event(32,0,0))
            self.assertIn(('commit','m'),e.events)
            e.do_property_activate('neptype-language', 0)
            self.assertEqual(e.language, 'english')
            self.assertIn(('update','English'),e.events)
            self.assertFalse(e.do_process_key_event(ord('a'),0,0))
            e.do_focus_out(); e.do_focus_in()
            self.assertIn(('register','English'),e.events)
            self.assertFalse(e.do_process_key_event(ord('a'),0,0))
            self.assertEqual(e.policy.language, 'english')
            e.do_property_activate('neptype-language',0)
            self.assertEqual(e.policy.language, 'allNepali')
            self.assertIn(('update','सबै ने'),e.events)
            e.do_property_activate('neptype-language',0)
            self.assertEqual(e.policy.language, 'nepali')

if __name__ == '__main__': unittest.main()
