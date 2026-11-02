#!/usr/bin/env python3
"""Write frozen references; deliberately does not import or invoke Lekha."""
import hashlib
import json
from pathlib import Path

# One author's proposed readings. Different intended senses and orthographies
# can be valid; no claim is made that this is natural or representative data.
groups = {
    "daily": [
        ("pyaas", ["प्यास"]), ("chiso", ["चिसो"]), ("tato", ["तातो"]),
        ("bhok", ["भोक"]), ("bistarai", ["बिस्तारै"]), ("chhito", ["छिटो"]),
        ("dherai", ["धेरै"]), ("thorai", ["थोरै"]), ("saafa", ["सफा"]),
        ("mitho", ["मिठो", "मीठो"]), ("sasto", ["सस्तो"]), ("mahango", ["महँगो", "महंगो"]),
    ],
    "people_places": [
        ("sathi", ["साथी"]), ("chimeki", ["छिमेकी"]), ("pariwaar", ["परिवार"]),
        ("bhai", ["भाइ"]), ("didi", ["दिदी"]), ("baje", ["बाजे"]),
        ("gaon", ["गाउँ"]), ("sahar", ["सहर", "शहर"]), ("pasal", ["पसल"]),
        ("jungle", ["जंगल", "जङ्गल"]), ("kotha", ["कोठा"]), ("chautara", ["चौतारा"]),
    ],
    "actions": [
        ("khanu", ["खानु"]), ("padhnu", ["पढ्नु"]), ("siknu", ["सिक्नु"]),
        ("lekhnus", ["लेख्नुस्"]), ("hidnu", ["हिँड्नु", "हिंड्नु"]), ("basnu", ["बस्नु"]),
        ("sodhnus", ["सोध्नुस्"]), ("kholnu", ["खोल्नु"]), ("sunnu", ["सुन्नु"]),
        ("pakaaunu", ["पकाउनु"]), ("lyaaunu", ["ल्याउनु"]), ("sutnu", ["सुत्नु"]),
    ],
    "variant_spellings": [
        ("namaskaar", ["नमस्कार"]), ("dhanyabaad", ["धन्यवाद"]), ("shubhakamana", ["शुभकामना"]),
        ("aawaj", ["आवाज"]), ("jindagi", ["जिन्दगी", "जिंदगी"]), ("samasya", ["समस्या"]),
        ("awashyak", ["आवश्यक"]), ("kaam", ["काम"]), ("sapana", ["सपना"]),
        ("bujhai", ["बुझाइ"]), ("bhetghat", ["भेटघाट"]), ("samachar", ["समाचार"]),
    ],
    "inflections": [
        ("khayeko", ["खाएको"]), ("padheko", ["पढेको"]), ("aayeko", ["आएको"]),
        ("gayera", ["गएर"]), ("bhayera", ["भएर"]), ("gareko", ["गरेको"]),
        ("bhandai", ["भन्दै"]), ("bujhchhu", ["बुझ्छु"]), ("sunchhu", ["सुन्छु"]),
        ("lekheko", ["लेखेको"]), ("kholera", ["खोलेर"]), ("sodheko", ["सोधेको"]),
    ],
    "english_control": [
        ("schedule", ["schedule"]), ("printer", ["printer"]), ("weekend", ["weekend"]),
        ("review", ["review"]), ("folder", ["folder"]), ("charger", ["charger"]),
        ("flight", ["flight"]), ("garden", ["garden"]), ("library", ["library"]),
        ("receipt", ["receipt"]),
    ],
    "name_control": [
        ("Elena", ["Elena"]), ("Sophie", ["Sophie"]), ("Mason", ["Mason"]),
        ("Nora", ["Nora"]), ("Avery", ["Avery"]), ("Daniel", ["Daniel"]),
        ("Rohan", ["Rohan"]), ("Sanjay", ["Sanjay"]), ("Maya", ["Maya"]),
        ("Kiran", ["Kiran"]),
    ],
}
rows = []
for category, entries in groups.items():
    role = "preserve" if category.endswith("_control") else "nepali"
    for roman, acceptable in entries:
        rows.append({"id": f"C{len(rows)+1:03}", "category": category,
                     "role": role, "roman": roman, "acceptable": acceptable})
corpus = {"version": "suggestion-probe-v1", "description": "Synthetic unreviewed candidate recall and original-preservation fixture, frozen without running Lekha.", "cases": rows}
path = Path(__file__).with_name("corpus.json")
path.write_text(json.dumps(corpus, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"{len(rows)} cases; sha256 {hashlib.sha256(path.read_bytes()).hexdigest()}")
