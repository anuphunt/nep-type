import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from neptype_ibus.bridge import BridgeError, CoreBridge, core_environment
from neptype_ibus.worker import CandidateWorker
from neptype_ibus.policy import CompositionPolicy, TAB

class Host:
    def __init__(self): self.result=''; self.marked=''
    def commit(self, text): self.result += text
    def preedit(self, text, visible): self.marked = text if visible else ''

class BridgeTests(unittest.TestCase):
    def test_child_environment_excludes_unrelated_credentials(self):
        env = {'NEPTYPE_ALIAS_INDEX': '/local/index', 'LANG': 'en_US.UTF-8',
               'UNRELATED_SECRET': 'must-not-be-forwarded', 'HOME': '/private/home'}
        self.assertEqual(core_environment(env), {'NEPTYPE_ALIAS_INDEX': '/local/index', 'LANG': 'en_US.UTF-8'})

    def test_spawned_child_receives_only_allowed_environment(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as root:
            script = Path(root) / 'check-env'
            script.write_text('#!' + sys.executable + '\nimport json,os,sys\n'
                              'x=json.loads(sys.stdin.readline())\n'
                              'print(json.dumps({"id":x["id"],"ok":'
                              '"NEPTYPE_TEST_SECRET" not in os.environ and '
                              'os.environ.get("NEPTYPE_ALIAS_INDEX")=="/local/index"}),flush=True)\n')
            script.chmod(0o755)
            with patch.dict(os.environ, {'NEPTYPE_TEST_SECRET': 'private', 'NEPTYPE_ALIAS_INDEX': '/local/index'}):
                bridge = CoreBridge(str(script), timeout=1.0)
                bridge.close()

    def test_same_session_reply_for_old_token_is_rejected(self):
        # Session IDs alone are insufficient to associate a piped reply with
        # the word requested: a buggy child can duplicate an older response.
        import queue
        pending = queue.Queue(); host = Host(); policy = CompositionPolicy(None, host)
        class StaleCore:
            def __init__(self, executable, timeout): pass
            def request(self, op, **args):
                if op == 'cancel': return {'ok': True}
                return {'accepted': True, 'state': {'roman': 'old', 'composing': True,
                        'language': 'nepali', 'candidates': ['पुरानो']}}
            def close(self): pass
        worker = CandidateWorker('unused', lambda fn,*args: pending.put((fn,args)),
                                 policy.candidates_ready, core_factory=StaleCore)
        policy.worker, policy.disabled = worker, False
        try:
            for c in 'new': self.assertTrue(policy.process(ord(c), 0))
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                fn, args = pending.get(timeout=2)
                fn(*args)
                if args[1] == 'new':
                    self.assertTrue(args[3])
                    break
            else:
                self.fail('no final-token callback')
            self.assertEqual(policy.raw, 'new')
            self.assertEqual(policy.options, ['new'])
            self.assertEqual(host.marked, 'new')
        finally:
            worker.close()

    def test_wrong_mode_response_is_rejected(self):
        import queue
        pending = queue.Queue(); host = Host(); policy = CompositionPolicy(None, host, language='allNepali')
        class WrongModeCore:
            def __init__(self, executable, timeout): pass
            def request(self, op, **args):
                if op == 'cancel': return {'ok': True}
                if op == 'set_language': return {'state': {'roman': '', 'composing': False, 'language': 'nepali'}}
                raise AssertionError('must not append after rejected mode')
            def close(self): pass
        worker = CandidateWorker('unused', lambda fn,*args: pending.put((fn,args)), policy.candidates_ready, core_factory=WrongModeCore)
        policy.worker, policy.disabled = worker, False
        try:
            for c in 'ma': self.assertTrue(policy.process(ord(c), 0))
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                fn, args = pending.get(timeout=2); fn(*args)
                if args[1] == 'ma':
                    self.assertTrue(args[3]); break
            else: self.fail('no final callback')
            self.assertEqual(policy.options, ['ma'])
            self.assertEqual(host.marked, 'ma')
        finally: worker.close()

    def test_full_child_input_pipe_times_out_instead_of_blocking_worker(self):
        # Child answers the initial handshake, then never reads its input.
        # Fill its pipe nonblockingly to exercise the request-write deadline.
        with tempfile.TemporaryDirectory() as root:
            script = Path(root) / 'stop-reading'
            script.write_text('#!' + sys.executable + '\nimport json,sys,time\nx=json.loads(sys.stdin.readline())\nprint(json.dumps({"id":x["id"],"ok":True}),flush=True)\ntime.sleep(5)\n')
            script.chmod(0o755)
            bridge = CoreBridge(str(script), timeout=1.0)
            try:
                fd = bridge.process.stdin.fileno()
                while True:
                    try: os.write(fd, b'x' * 4096)
                    except BlockingIOError: break
                bridge.timeout = 0.05
                start = time.monotonic()
                with self.assertRaisesRegex(BridgeError, 'write timed out'):
                    bridge.request('append', text='ma')
                self.assertLess(time.monotonic() - start, 0.5)
            finally:
                bridge.close()

    def test_oversized_request_is_rejected_before_write(self):
        with tempfile.TemporaryDirectory() as root:
            script = Path(root) / 'ready'
            script.write_text('#!' + sys.executable + '\nimport json,sys,time\nx=json.loads(sys.stdin.readline())\nprint(json.dumps({"id":x["id"],"ok":True}),flush=True)\ntime.sleep(5)\n')
            script.chmod(0o755)
            bridge = CoreBridge(str(script), timeout=1.0)
            try:
                with self.assertRaisesRegex(BridgeError, 'oversized core request'):
                    bridge.request('append', text='x' * 9000)
            finally:
                bridge.close()

    def test_oversized_candidate_response_is_rejected_and_original_stays(self):
        import queue
        pending = queue.Queue()
        closed = []
        class OversizedCore:
            def __init__(self, executable, timeout): pass
            def request(self, op, **args):
                if op == 'cancel': return {'ok': True}
                return {'accepted': True, 'state': {'roman': args['text'], 'composing': True, 'language': 'nepali', 'candidates': ['विकल्प'] * 257}}
            def close(self): closed.append(True)
        host = Host(); policy = CompositionPolicy(None, host)
        worker = CandidateWorker('unused', lambda fn,*args: pending.put((fn,args)),
                                 policy.candidates_ready, core_factory=OversizedCore)
        policy.worker, policy.disabled = worker, False
        try:
            for char in 'ma': self.assertTrue(policy.process(ord(char), 0))
            callback, args = pending.get(timeout=2)
            callback(*args)
            self.assertTrue(args[3])
            self.assertEqual(policy.raw, 'ma')
            self.assertEqual(policy.options, ['ma'])
            self.assertEqual(host.marked, 'ma')
            self.assertTrue(closed)
        finally:
            worker.close()

    def test_engine_failure_is_rate_limited_and_recovers(self):
        import queue
        clock = [100.0]
        launches = []
        pending = queue.Queue()
        class BrokenThenWorkingCore:
            def __init__(self, executable, timeout):
                launches.append(clock[0])
                if len(launches) == 1:
                    raise BridgeError('unavailable')
            def request(self, op, **args):
                if op == 'cancel': return {'ok': True}
                return {'accepted': True, 'state': {'roman': args['text'], 'composing': True, 'language': 'nepali', 'candidates': ['म']}}
            def close(self): pass
        worker = CandidateWorker('unused', lambda fn,*args: pending.put(args),
                                 lambda *args: None, core_factory=BrokenThenWorkingCore,
                                 retry_delay=1, clock=lambda: clock[0])
        try:
            worker.submit('m', 1)
            self.assertEqual(pending.get(timeout=2)[3], True)
            worker.submit('ma', 2)
            self.assertEqual(pending.get(timeout=2)[3], True)
            self.assertEqual(len(launches), 1)
            clock[0] += 1.01
            worker.submit('ma', 3)
            self.assertEqual(pending.get(timeout=2)[3], False)
            self.assertEqual(len(launches), 2)
        finally: worker.close()

    def test_close_while_lookup_is_inflight_releases_core_and_delivers_nothing(self):
        import queue
        import threading
        started, release, closed = threading.Event(), threading.Event(), threading.Event()
        deliveries = queue.Queue()
        class BlockingCore:
            def __init__(self, executable, timeout): pass
            def request(self, op, **args):
                if op == 'cancel': return {'ok': True}
                started.set()
                self.assertion = release.wait(2)
                return {'accepted': True, 'state': {'roman': args['text'], 'composing': True, 'language': 'nepali', 'candidates': ['म']}}
            def close(self): closed.set()
        worker = CandidateWorker('unused', lambda fn,*args: deliveries.put((fn,args)),
                                 lambda *args: None, core_factory=BlockingCore)
        worker.submit('ma', 1)
        try:
            self.assertTrue(started.wait(1))
            worker.close()
            release.set()
            self.assertTrue(closed.wait(1))
            self.assertTrue(deliveries.empty())
        finally:
            release.set(); worker.close()

    def test_hung_initialization_never_blocks_typing_or_focus(self):
        with tempfile.TemporaryDirectory() as root:
            script = Path(root)/'hang'; script.write_text('#!/bin/sh\nsleep 5\n'); script.chmod(0o755)
            host=Host(); p=CompositionPolicy(None,host)
            start=time.monotonic()
            worker=CandidateWorker(str(script),lambda fn,*a:fn(*a),p.candidates_ready,timeout=0.05)
            p.worker=worker; p.disabled=False
            for c in 'namaste': self.assertTrue(p.process(ord(c),0))
            p.close()
            elapsed=time.monotonic()-start
            self.assertLess(elapsed,0.05)
            self.assertEqual(host.result,'namaste')
            self.assertEqual(host.marked,'')

    def test_real_timeout_keeps_original_without_blocking_key(self):
        import queue
        with tempfile.TemporaryDirectory() as root:
            script=Path(root)/"hang"; script.write_text("#!/bin/sh\nsleep 5\n"); script.chmod(0o755)
            pending=queue.Queue(); host=Host(); p=CompositionPolicy(None,host)
            worker=CandidateWorker(str(script),lambda fn,*a:pending.put((fn,a)),p.candidates_ready,timeout=0.05)
            p.worker=worker; p.disabled=False
            try:
                for c in 'ma': self.assertTrue(p.process(ord(c),0))
                fn,args=pending.get(timeout=2); fn(*args)
                self.assertEqual(host.marked,'ma')
                self.assertFalse(p.process(ord(' '),0)); self.assertEqual(host.result,'ma')
            finally: p.close()

    @unittest.skipUnless(os.environ.get('NEPTYPE_TEST_CORE'), 'No core binary provided')
    def test_live_core_all_nepali_requires_explicit_choice(self):
        import queue
        pending=queue.Queue(); host=Host(); p=CompositionPolicy(None,host, language='allNepali')
        worker=CandidateWorker(os.environ['NEPTYPE_TEST_CORE'],lambda fn,*a:pending.put((fn,a)),p.candidates_ready,timeout=2)
        p.worker=worker; p.disabled=False
        try:
            for c in 'office': self.assertTrue(p.process(ord(c),0))
            deadline=time.monotonic()+4
            while len(p.options)<2 and time.monotonic()<deadline:
                fn,args=pending.get(timeout=4); fn(*args)
            self.assertEqual(host.marked,'office')
            self.assertIn('office',p.options)
            self.assertTrue(any(any('\u0900' <= c <= '\u097f' for c in value) for value in p.options[1:]))
            self.assertTrue(p.process(TAB,0)); selected=p.options[p.selection]
            self.assertFalse(p.process(ord(' '),0)); self.assertEqual(host.result,selected)
        finally: p.close()

    @unittest.skipUnless(os.environ.get('NEPTYPE_TEST_CORE'), 'No core binary provided')
    def test_live_core_explicit_candidate(self):
        import queue
        pending=queue.Queue(); host=Host(); p=CompositionPolicy(None,host)
        worker=CandidateWorker(os.environ['NEPTYPE_TEST_CORE'],lambda fn,*a:pending.put((fn,a)),p.candidates_ready,timeout=2)
        p.worker=worker; p.disabled=False
        try:
            for c in 'namaste': self.assertTrue(p.process(ord(c),0))
            deadline=time.monotonic()+3
            while len(p.options)<2 and time.monotonic()<deadline:
                fn,args=pending.get(timeout=3); fn(*args)
            self.assertEqual(host.marked,'namaste')
            self.assertTrue(p.process(TAB,0)); self.assertEqual(host.marked,'namaste'); self.assertEqual(p.options[p.selection], 'नमस्ते')
            self.assertFalse(p.process(ord(' '),0)); self.assertEqual(host.result,'नमस्ते')
        finally: p.close()
