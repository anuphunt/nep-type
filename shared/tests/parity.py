#!/usr/bin/env python3
"""Cross-language ABI conformance against the shared Rust engine through the Swift adapter."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import threading
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"shared/python"))
from neptype_engine import Engine, EngineError
parser = argparse.ArgumentParser()
parser.add_argument("library"); parser.add_argument("dictionaries"); parser.add_argument("reference"); parser.add_argument("cpp_probe")
parser.add_argument("--java"); parser.add_argument("--jni-dir"); parser.add_argument("--classes")
args = parser.parse_args()
tokens=["ma","pani","namaste","bhetau","football","office","meeting","hello","xyzzy","man","k","ram","NEPAL","foo_bar","fooBar","abc.com","https://example.com",chr(96)+"ma"+chr(96),"a@b.com","test123","(namaste)","bholi.","😀","क"]
tokens += ["".join(chars) for chars in zip("abcdefghijklmnopqrstuvwxyz"*2,"a"*26+"i"*26)]
engine=Engine(args.library,args.dictionaries)
try: Engine(args.library, str(Path(args.dictionaries)/"missing")); raise AssertionError("missing dictionaries accepted")
except EngineError: pass
expected_id=json.loads((ROOT/"engine/data/manifest.json").read_text())["id"]
assert engine.dictionary_id==expected_id
comparisons=0
def lines(command):
    return subprocess.run(command,check=True,text=True,capture_output=True).stdout.splitlines()
assert lines([args.cpp_probe,args.library,args.dictionaries,"--dictionary-id"])==[expected_id]
if args.java:
    assert lines([args.java,"-Djava.library.path="+args.jni_dir,"-cp",args.classes,"SharedEngineProbe",args.dictionaries,"--dictionary-id"])==[expected_id]
for mode in (0,1,2):
    expected=lines([args.reference,args.dictionaries,str(mode)]+tokens)
    actual=["\t".join(value.encode().hex() for value in engine.candidates(word,mode)) for word in tokens]
    assert actual==expected,("Python/Swift",mode)
    assert lines([args.cpp_probe,args.library,args.dictionaries,str(mode)]+tokens)==expected,("C++/Swift",mode)
    comparisons+=len(tokens)*2
    if args.java:
        command=[args.java,"-Djava.library.path="+args.jni_dir,"-cp",args.classes,"SharedEngineProbe",args.dictionaries,str(mode)]+tokens
        assert lines(command)==expected,("JNI/Swift",mode)
        comparisons+=len(tokens)
assert engine.document("namaste! ma office janchu.",caret=3)["output"]=="नमस्ते! म office जान्छु।"
assert engine.document("ma pani",caret=6,choice="पानी")["output"]=="म पानी"
assert engine.document("ma pani!",caret=6)["output"]=="म पानी!"
assert engine.document("👋 ma pani",caret=8)["token_start"]==6
literal="hello 🙂 https://example.com foo_bar"
assert engine.document(literal,mode=1)["output"]==literal
for value,mode in [("ma",99),("a"*257,0),("a\0b",0)]:
    try: engine.candidates(value,mode); raise AssertionError("invalid request accepted")
    except EngineError: pass
try: engine.document("ma pani",caret=6,choice="not offered"); raise AssertionError("invalid choice accepted")
except EngineError: pass
other=Engine(args.library,args.dictionaries)
assert other.document("ma pani",caret=6)["output"]=="म पनि", "document choices leaked between handles"
other.close()
errors=[]
def check_thread():
    try:
        for _ in range(10): assert "म" in engine.candidates("ma")
    except Exception as error: errors.append(str(error))
threads=[threading.Thread(target=check_thread) for _ in range(4)]
for thread in threads: thread.start()
for thread in threads: thread.join()
assert not errors, errors
engine.close(); engine.close()
try: engine.candidates("ma"); raise AssertionError("closed handle used")
except EngineError: pass
print(json.dumps({"passed":True,"cross_language_comparisons":comparisons,"document_unicode_and_lifetime_checks":True}))
