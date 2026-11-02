#!/usr/bin/env python3
"""Print an IBus component descriptor; does not install or register it."""
import argparse
import os
import shlex
import xml.etree.ElementTree as ET
from pathlib import Path


def build_descriptor(project_dir: Path, python: str) -> str:
    # IBus executes this command; quote paths, including those containing spaces.
    launcher = project_dir.resolve() / "run-engine.sh"
    component = ET.Element("component")
    for tag, value in [("name", "org.freedesktop.IBus.Lekha"), ("description", "Lekha experimental input method; pass-through unless core is configured"), ("exec", shlex.join([str(launcher), python])), ("version", "0.0.1"), ("license", "Unspecified"), ("author", "Lekha project"), ("homepage", ""), ("textdomain", "lekha")]:
        ET.SubElement(component, tag).text = value
    engines = ET.SubElement(component, "engines")
    engine = ET.SubElement(engines, "engine")
    for tag, value in [("name", "lekha"), ("longname", "Lekha (experimental)"), ("description", "Pass-through by default; optional offline candidates"), ("language", "ne"), ("license", "Unspecified"), ("author", "Lekha project"), ("layout", "default")]:
        ET.SubElement(engine, tag).text = value
    ET.indent(component)
    return ET.tostring(component, encoding="unicode", xml_declaration=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python", default="python3", help="Python executable available on the target machine")
    args = parser.parse_args()
    print(build_descriptor(Path(__file__).parent, args.python))
