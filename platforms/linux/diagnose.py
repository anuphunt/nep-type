#!/usr/bin/env python3
"""Read-only diagnostics for the uninstalled Linux experiment; never connects to IBus."""
import importlib
import json
import os
import platform
import shutil
import sys


def file_status(path, *, executable=False):
    if not path:
        return "not configured"
    if not os.path.isabs(path):
        return "must be an absolute path"
    if not os.path.isfile(path):
        return "not a regular file"
    if not os.access(path, os.R_OK):
        return "not readable"
    if executable and not os.access(path, os.X_OK):
        return "not executable"
    return "available (contents and architecture not verified)"


def diagnostics(environ=None):
    env = os.environ if environ is None else environ
    try:
        gi = importlib.import_module("gi")
        gi.require_version("IBus", "1.0")
        importlib.import_module("gi.repository.IBus")
        bindings = "available (daemon and host not tested)"
    except (ImportError, ValueError, AttributeError, OSError, RuntimeError):
        bindings = "unavailable (PyGObject / IBus bindings)"
    return {
        "system": platform.system(),
        "machine": platform.machine(),
        "python": platform.python_version(),
        "ibus_command": "available" if shutil.which("ibus") else "not found",
        "ibus_bindings": bindings,
        "core": file_status(env.get("NEPTYPE_IBUS_CORE_EXECUTABLE"), executable=True),
        "google_alias_index": file_status(env.get("NEPTYPE_ALIAS_INDEX")),
        "aksharantar_index": file_status(env.get("NEPTYPE_AKSHARANTAR_INDEX")),
        "focus_id_experiment": env.get("NEPTYPE_IBUS_FOCUS_ID") == "1",
        "focus_commit_experiment": env.get("NEPTYPE_IBUS_FOCUS_COMMIT") == "1",
        "notice": "Read-only check. No daemon connection, input source registration, architecture validation or real typing test was performed.",
    }


if __name__ == "__main__":
    json.dump(diagnostics(), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
