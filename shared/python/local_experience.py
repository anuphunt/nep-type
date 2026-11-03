"""Bounded local pad state. No network or host-editor access."""
import json
import os
from pathlib import Path

class LocalExperience:
    def __init__(self, directory=None):
        self.directory = Path(directory or Path(os.environ.get("XDG_STATE_HOME", Path.home()/".local/state"))/"neptype")
        self.path = self.directory / "pad-v1.json"
        self.data = {"source":"", "mode":0, "spellings":{}, "guide_seen":False}
        try:
            if self.path.stat().st_size <= 2_000_000:
                value = json.loads(self.path.read_text(encoding="utf-8"))
                if isinstance(value, dict):
                    source = value.get("source", "")
                    if isinstance(source,str) and len(source.encode()) <= 1_048_576: self.data["source"] = source
                    self.data["mode"] = value.get("mode") if value.get("mode") in (0,2) else 0
                    self.data["guide_seen"] = value.get("guide_seen") is True
                    values = value.get("spellings", {})
                    if isinstance(values,dict):
                        self.data["spellings"] = {k:v for k,v in list(values.items())[:256] if self.valid(k,v)}
        except (OSError, ValueError, TypeError): pass

    @staticmethod
    def valid(key, value):
        return isinstance(key,str) and 0<len(key)<=64 and key.isascii() and key.isalpha() and isinstance(value,str) and len(value.encode())<=1024 and not any(c in value for c in "\0\t\r\n")

    def remember(self, key, value, candidates):
        if self.valid(key,value) and value in candidates and candidates:
            values = self.data["spellings"]
            if value == candidates[0] and values.get(key.lower()) != value: values.pop(key.lower(), None)
            else:
                if len(values)>=256 and key.lower() not in values: values.pop(sorted(values)[0])
                values[key.lower()] = value

    def save(self):
        if len(self.data["source"].encode("utf-8")) > 1_048_576: return False
        try:
            self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
            temporary = self.path.with_suffix(".tmp")
            descriptor = os.open(temporary, os.O_WRONLY|os.O_CREAT|os.O_TRUNC, 0o600)
            with os.fdopen(descriptor,"w",encoding="utf-8") as stream: json.dump(self.data,stream,ensure_ascii=False)
            os.chmod(temporary,0o600)
            os.replace(temporary,self.path)
            return True
        except (OSError, ValueError): return False
