import unittest
from lekha_ibus.policy import CompositionPolicy, BACKSPACE, TAB, ISO_LEFT_TAB, SHIFT_MASK, CONTROL_MASK, RELEASE_MASK

class Host:
    def __init__(self): self.committed = ''; self.display = ''
    def preedit(self, text, visible): self.display = text if visible else ''
    def commit(self, text): self.committed += text
    def lookup(self, options, selection): self.candidates = (list(options), selection)
class Worker:
    def __init__(self): self.jobs=[]; self.closed=False
    def submit(self, raw, generation, language="nepali"): self.jobs.append((raw,generation)); self.last_language = language
    def close(self): self.closed=True

class PolicyTests(unittest.TestCase):
    def setUp(self): self.host=Host(); self.worker=Worker(); self.p=CompositionPolicy(self.worker,self.host)
    def type(self, text):
        for char in text: self.assertTrue(self.p.process(ord(char), 0))
    def deliver(self, values, error=False):
        raw,generation=self.worker.jobs[-1]; self.p.candidates_ready(generation,raw,values,error)
    def test_original_default_and_boundary(self):
        self.type('ma'); self.deliver(['म','ma']); self.assertEqual(self.host.display,'ma')
        self.assertFalse(self.p.process(ord(' '),0)); self.assertEqual(self.host.committed,'ma')
    def test_all_nepali_mode_queues_matching_mode_and_keeps_original(self):
        self.p.set_language('allNepali')
        self.type('office')
        self.assertEqual(self.worker.last_language, 'allNepali')
        self.deliver(['अफिस'])
        self.assertEqual(self.host.display, 'office')
        self.assertEqual(self.p.options, ['office', 'अफिस'])
        self.assertTrue(self.p.process(TAB, 0))
        self.assertFalse(self.p.process(ord(' '), 0))
        self.assertEqual(self.host.committed, 'अफिस')

    def test_old_mode_response_cannot_change_new_mode_word(self):
        self.type('ma')
        raw, generation = self.worker.jobs[-1]
        self.p.set_language('allNepali')
        self.type('ma')
        self.p.candidates_ready(generation, raw, ['पुरानो'], False)
        self.assertEqual(self.p.options, ['ma'])
        self.assertEqual(self.worker.last_language, 'allNepali')

    def test_explicit_candidate_and_input_invalidates(self):
        self.type('ma'); self.deliver(['म','ma']); self.assertTrue(self.p.process(TAB,0)); self.assertEqual(self.host.display,'ma')
        self.type('x'); self.assertEqual(self.host.display,'max'); self.assertFalse(self.p.process(ord(' '),0)); self.assertEqual(self.host.committed,'max')
    def test_explicit_candidate_commit(self):
        self.type('ma'); self.deliver(['म','ma']); self.assertTrue(self.p.process(TAB,0))
        self.assertFalse(self.p.process(ord(' '),0)); self.assertEqual(self.host.committed,'म')
    def test_navigation_and_unknown_keys_preserve_original_not_preview(self):
        # Includes arrows, home/end, forward delete, non-ASCII and a dead key.
        for key in [0xff51, 0xff53, 0xff50, 0xff57, 0xffff, 0x0101f600, 0xfe50]:
            with self.subTest(key=key):
                self.setUp(); self.type('ma'); self.deliver(['म']); self.assertTrue(self.p.process(TAB,0))
                raw, generation = self.worker.jobs[-1]
                self.assertFalse(self.p.process(key,0))
                self.assertEqual(self.host.committed,'ma'); self.assertEqual(self.host.display,'')
                self.p.candidates_ready(generation,raw,['म'],False)
                self.assertEqual(self.host.committed,'ma'); self.assertEqual(self.host.display,'')
    def test_cursor_move_then_typing_does_not_commit_preview_at_new_location(self):
        # Fake host applies an unconsumed left arrow and following literal key.
        self.type('ma'); self.deliver(['म']); self.assertTrue(self.p.process(TAB, 0))
        self.assertFalse(self.p.process(0xff51, 0))
        text = self.host.committed
        cursor = len(text) - 1  # the host processes Left after the raw commit
        text = text[:cursor] + 'X' + text[cursor:]
        self.assertEqual(text, 'mXa')
    def test_backspace_and_release(self):
        self.type('ma'); self.assertFalse(self.p.process(BACKSPACE,RELEASE_MASK)); self.assertTrue(self.p.process(BACKSPACE,0)); self.assertEqual(self.host.display,'m')
    def test_stale_response_cannot_rewrite_new_input(self):
        self.type('m'); raw,generation=self.worker.jobs[-1]; self.type('a')
        self.p.candidates_ready(generation,raw,['म'],False); self.assertEqual(self.host.display,'ma'); self.assertEqual(self.p.options,['ma'])
    def test_timeout_keeps_original_and_late_response_is_ignored(self):
        self.type('ma'); raw,generation=self.worker.jobs[-1]; self.deliver([],True)
        self.p.candidates_ready(generation,raw,['म'],False); self.assertEqual(self.host.display,'ma')
        self.p.process(ord(' '),0); self.assertEqual(self.host.committed,'ma')
    def test_focus_and_secure_fields_reject_late_response(self):
        self.type('ma'); raw,generation=self.worker.jobs[-1]; self.p.set_secure(True)
        # Ownership might have changed before the callback: never commit old
        # text to the new protected client or send another host update.
        prior_display = self.host.display
        self.p.candidates_ready(generation,raw,['म'],False)
        self.assertEqual(self.host.committed,''); self.assertEqual(self.host.display,prior_display)
        self.assertFalse(self.p.process(ord('x'),0)); self.assertTrue(self.worker.closed)
        self.assertTrue(self.p.closed); self.assertEqual(self.p.raw, '')
    def test_close_rejects_queued_responses(self):
        self.type('ma'); raw,generation=self.worker.jobs[-1]; self.p.close()
        self.p.candidates_ready(generation,raw,['म'],False); self.assertEqual(self.host.committed,'ma'); self.assertEqual(self.host.display,'')
    def test_candidate_view_and_keyboard_selection(self):
        self.type('ma'); self.deliver(['म', 'मा'])
        self.assertEqual(self.host.candidates, (['ma', 'म', 'मा'], 0))
        self.assertTrue(self.p.process(TAB, 0)); self.assertEqual(self.host.display, 'ma'); self.assertEqual(self.host.candidates[1], 1)
        self.assertTrue(self.p.process(TAB, 0)); self.assertEqual(self.host.display, 'ma'); self.assertEqual(self.host.candidates[1], 2)
        self.p.flush_original(); self.assertEqual(self.host.committed, 'ma')
        self.assertEqual(self.host.candidates, ([], 0))
    def test_reverse_cycle_and_backspace_restores_original_first(self):
        self.type('pani'); self.deliver(['पनि', 'पानी'])
        self.assertTrue(self.p.process(TAB, SHIFT_MASK)); self.assertEqual(self.host.display, 'pani'); self.assertEqual(self.host.candidates[1], 2)
        self.assertTrue(self.p.process(ISO_LEFT_TAB, 0)); self.assertEqual(self.host.display, 'pani'); self.assertEqual(self.host.candidates[1], 1)
        self.assertTrue(self.p.process(BACKSPACE, 0)); self.assertEqual(self.host.display, 'pani')
        self.assertEqual(self.p.raw, 'pani')
        self.assertTrue(self.p.process(BACKSPACE, 0)); self.assertEqual(self.host.display, 'pan')
        self.assertEqual(self.p.raw, 'pan')
    def test_invalid_candidates_cannot_inject_or_hide_original(self):
        self.type('ma'); self.deliver(['\nInjected', 'a\x00b', 'a\u2028b', '\u202eabc', 'a b', 'a\u00a0b', 'x' * 257, '\ud800', 'म', 'म'])
        self.assertEqual(self.p.options, ['ma', 'म'])
        self.assertTrue(self.p.process(TAB, 0)); self.assertEqual(self.host.display, 'ma')
        self.p.process(ord(' '), 0); self.assertEqual(self.host.committed, 'म')
    def test_tab_without_suggestions_preserves_before_traversal(self):
        self.type('ma'); self.assertFalse(self.p.process(TAB, 0))
        self.assertEqual(self.host.committed, 'ma'); self.assertEqual(self.host.display, '')
    def test_literal_identifier_invalidates_choice(self):
        self.type('ma'); self.deliver(['म']); self.p.process(TAB, 0)
        self.type('.py'); self.assertEqual(self.host.display, 'ma.py')
        self.p.process(ord(' '), 0); self.assertEqual(self.host.committed, 'ma.py')
    def test_backtick_code_across_spaces_disables_suggestions(self):
        self.type('`git')
        self.assertFalse(self.worker.jobs)
        self.p.process(ord(' '), 0)
        self.type('push`'); self.assertFalse(self.worker.jobs)
        self.p.process(ord(' '), 0)
        self.type('ma'); self.assertEqual(self.worker.jobs[-1][0], 'ma')
        self.assertEqual(self.host.committed, '`gitpush`')  # spaces go to host separately
    def test_deleted_backtick_reenables_candidates(self):
        self.type('`'); self.assertFalse(self.worker.jobs)
        self.p.process(BACKSPACE, 0); self.type('ma')
        self.assertEqual(self.worker.jobs[-1][0], 'ma')
    def test_shortcut_and_no_core(self):
        self.type('ma'); self.assertFalse(self.p.process(ord('c'),CONTROL_MASK)); self.assertEqual(self.host.committed,'ma')
        p=CompositionPolicy(None,self.host); self.assertFalse(p.process(ord('a'),0))
    def test_explicit_mode_switch_preserves_original_and_rejects_late_result(self):
        self.type('ma'); raw,generation=self.worker.jobs[-1]
        self.deliver(['म']); self.p.process(TAB, 0)
        self.assertEqual(self.host.display, 'ma')
        self.p.set_language('english')
        self.assertEqual(self.host.committed, 'ma')
        self.assertEqual(self.host.display, '')
        self.p.candidates_ready(generation,raw,['म'],False)
        for char in 'Hello123': self.assertFalse(self.p.process(ord(char), 0))
        self.assertEqual(self.host.committed, 'ma')
        self.p.set_language('nepali'); self.type('ma')
        self.assertEqual(self.host.display, 'ma')

    def test_invalid_mode_never_discards_composition(self):
        self.type('ma')
        with self.assertRaises(ValueError): self.p.set_language('automatic')
        self.assertEqual(self.p.raw, 'ma')
        self.assertEqual(self.host.display, 'ma')

if __name__ == '__main__': unittest.main()
