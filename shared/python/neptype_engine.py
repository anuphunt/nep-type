"""Thin ctypes binding to ABI 2. All language decisions stay in Rust."""
import ctypes as C
import os
import sys
import threading
import json
from pathlib import Path

class EngineError(RuntimeError):
    pass

class Engine:
    def __init__(self, library=None, dictionaries=None):
        root = Path(__file__).resolve().parents[2]
        suffix = ".dylib" if sys.platform == "darwin" else ".so"
        library = library or os.environ.get("NEPTYPE_ENGINE_LIBRARY") or root / ("build/shared-engine/libNepTypeEngine" + suffix)
        dictionaries = dictionaries or os.environ.get("NEPTYPE_DICTIONARY_DIR") or root / "build/shared-engine/dictionaries"
        self._lock = threading.Lock()
        self._handle = None
        try:
            self._lib = C.CDLL(str(Path(library).resolve()))
            api = {
                "abi_version": (C.c_uint32, []),
                "create": (C.c_void_p, [C.c_char_p]), "destroy": (None, [C.c_void_p]),
                "candidates": (C.c_void_p, [C.c_void_p, C.c_char_p, C.c_int32]),
                "document": (C.c_void_p, [C.c_void_p, C.c_char_p, C.c_int32, C.c_int32, C.c_char_p]),
                "set_preferences": (C.c_bool, [C.c_void_p, C.c_char_p]),
            }
            for name, (returns, args) in api.items():
                function = getattr(self._lib, "neptype_engine_" + name)
                function.restype, function.argtypes = returns, args
            for name in ("output", "token"):
                function = getattr(self._lib, "neptype_result_" + name)
                function.restype, function.argtypes = C.c_char_p, [C.c_void_p]
            for name in ("token_start", "token_length", "candidate_count"):
                function = getattr(self._lib, "neptype_result_" + name)
                function.restype, function.argtypes = C.c_int32, [C.c_void_p]
            self._lib.neptype_result_candidate.restype = C.c_char_p
            self._lib.neptype_result_candidate.argtypes = [C.c_void_p, C.c_int32]
            self._lib.neptype_result_destroy.argtypes = [C.c_void_p]
            self._lib.neptype_result_destroy.restype = None
            self._lib.neptype_dictionary_id.restype, self._lib.neptype_dictionary_id.argtypes = C.c_char_p, []
            self.dictionary_id = self._lib.neptype_dictionary_id().decode("ascii")
            if self._lib.neptype_engine_abi_version() != 2:
                raise EngineError("Unsupported shared engine ABI")
            self._handle = self._lib.neptype_engine_create(self._bytes(str(Path(dictionaries).resolve())))
            if not self._handle:
                raise EngineError("Shared dictionaries could not be loaded")
        except (OSError, AttributeError) as error:
            raise EngineError("Shared engine library is unavailable") from error

    @staticmethod
    def _bytes(text):
        if "\0" in text:
            raise EngineError("Embedded NUL is not supported by ABI 2")
        return text.encode("utf-8", errors="strict")

    def _read(self, result):
        if not result:
            raise EngineError("Shared engine rejected the request")
        try:
            lib = self._lib
            return {
                "output": lib.neptype_result_output(result).decode("utf-8"),
                "token": lib.neptype_result_token(result).decode("utf-8"),
                "token_start": lib.neptype_result_token_start(result),
                "token_length": lib.neptype_result_token_length(result),
                "candidates": [lib.neptype_result_candidate(result, i).decode("utf-8")
                               for i in range(lib.neptype_result_candidate_count(result))],
            }
        finally:
            self._lib.neptype_result_destroy(result)

    def candidates(self, roman, mode=0):
        with self._lock:
            if not self._handle: raise EngineError("Engine is closed")
            return self._read(self._lib.neptype_engine_candidates(self._handle, self._bytes(roman), mode))["candidates"]

    def set_preferences(self, preferences):
        with self._lock:
            if not self._handle: raise EngineError("Engine is closed")
            if not self._lib.neptype_engine_set_preferences(self._handle, self._bytes(json.dumps(preferences))):
                raise EngineError("Invalid preferences")

    def document(self, source, mode=0, caret=None, choice=None):
        if caret is None: caret = len(source.encode("utf-16-le")) // 2
        with self._lock:
            if not self._handle: raise EngineError("Engine is closed")
            return self._read(self._lib.neptype_engine_document(
                self._handle, self._bytes(source), mode, caret, None if choice is None else self._bytes(choice)))

    def close(self):
        with self._lock:
            if self._handle:
                self._lib.neptype_engine_destroy(self._handle)
                self._handle = None
