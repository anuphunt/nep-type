#!/usr/bin/env python3
"""Write fixed human-readable synthetic references; never invokes the engine."""
import json
from pathlib import Path
def en(token): return (token, "english", [token])
def ne(token, *accepted): return (token, "nepali", list(accepted))
def lit(token): return (token, "literal", [token])
cases = []
def add(category, source, expected, annotations):
    cursor = 0
    for token, role, acceptable in annotations:
        position = source.find(token, cursor)
        if position < 0: raise ValueError((category, source, token))
        cursor = position + len(token)
        if not acceptable: raise ValueError(token)
    cases.append({"id":f"B{len(cases)+1:03}", "category":category, "split":"heldout", "source":"synthetic",
                  "input":source, "expected":expected if isinstance(expected,list) else [expected],
                  "annotations":[{"token":t,"role":r,"acceptable":a} for t,r,a in annotations]})
# English-only controls: annotations deliberately select distinctive words.
add("english","Please bring the blue folder tomorrow.","Please bring the blue folder tomorrow.",[en("Please"),en("blue"),en("folder"),en("tomorrow")])
add("english","The bus arrived after lunch.","The bus arrived after lunch.",[en("bus"),en("arrived"),en("lunch")])
add("english","I left my umbrella near the door.","I left my umbrella near the door.",[en("left"),en("umbrella"),en("door")])
add("english","The little bird is singing outside.","The little bird is singing outside.",[en("little"),en("bird"),en("singing"),en("outside")])
add("english","We should check the weather first.","We should check the weather first.",[en("check"),en("weather"),en("first")])
add("english","Can you send the final report tonight?","Can you send the final report tonight?",[en("send"),en("final"),en("report"),en("tonight")])
add("english","The children walked home together.","The children walked home together.",[en("children"),en("walked"),en("home"),en("together")])
add("english","My sister likes fresh orange juice.","My sister likes fresh orange juice.",[en("sister"),en("fresh"),en("orange"),en("juice")])
add("english","This place feels quiet and warm.","This place feels quiet and warm.",[en("place"),en("quiet"),en("warm")])
add("english","The train was late because of rain.","The train was late because of rain.",[en("train"),en("late"),en("rain")])
add("english","We can meet near the library.","We can meet near the library.",[en("meet"),en("near"),en("library")])
# Nepali examples use proposed references; many spellings are acceptable.
add("nepali","aaja gharma ko ko chan?","आज घरमा को को छन्?",[ne("aaja","आज"),ne("gharma","घरमा"),ne("chan","छन्")])
add("nepali","bholi bihana chadai uthnu parcha.","भोलि बिहान चाँडै उठ्नु पर्छ.",[ne("bholi","भोलि"),ne("bihana","बिहान"),ne("chadai","चाँडै","चाँडो"),ne("uthnu","उठ्नु"),ne("parcha","पर्छ")])
add("nepali","yo kitab kasle lyayo?","यो किताब कसले ल्यायो?",[ne("yo","यो"),ne("kitab","किताब"),ne("kasle","कसले"),ne("lyayo","ल्यायो")])
add("nepali","mero sathi ahile gharma cha.","मेरो साथी अहिले घरमा छ.",[ne("mero","मेरो"),ne("sathi","साथी"),ne("ahile","अहिले"),ne("gharma","घरमा"),ne("cha","छ")])
add("nepali","hami beluka sangai khana khanchau.","हामी बेलुका सँगै खाना खान्छौँ.",[ne("hami","हामी"),ne("beluka","बेलुका"),ne("sangai","सँगै"),ne("khana","खाना"),ne("khanchau","खान्छौँ","खान्छौं")])
add("nepali","timilai kun rang man parcha?","तिमीलाई कुन रङ मन पर्छ?",[ne("timilai","तिमीलाई"),ne("kun","कुन"),ne("rang","रङ","रंग"),ne("man","मन"),ne("parcha","पर्छ")])
add("nepali","aama le mitho chiya banaunu bhayo.","आमा ले मिठो चिया बनाउनु भयो.",[ne("aama","आमा"),ne("le","ले"),ne("mitho","मिठो","मीठो"),ne("chiya","चिया"),ne("banaunu","बनाउनु"),ne("bhayo","भयो")])
add("nepali","pani parepachi bato chiplo huncha.","पानी परेपछि बाटो चिप्लो हुन्छ.",[ne("pani","पानी"),ne("parepachi","परेपछि"),ne("bato","बाटो"),ne("chiplo","चिप्लो"),ne("huncha","हुन्छ")])
add("nepali","maile hijo tyo geet sune.","मैले हिजो त्यो गीत सुनेँ.",[ne("maile","मैले"),ne("hijo","हिजो"),ne("tyo","त्यो"),ne("geet","गीत"),ne("sune","सुनेँ","सुने")])
add("nepali","dherai din pachi bhetda ramailo lagyo.","धेरै दिन पछि भेट्दा रमाइलो लाग्यो.",[ne("dherai","धेरै"),ne("din","दिन"),ne("pachi","पछि"),ne("ramailo","रमाइलो"),ne("lagyo","लाग्यो")])
add("nepali","kripaya dhoka bistari banda garnus.","कृपया ढोका बिस्तारै बन्द गर्नुस्.",[ne("kripaya","कृपया"),ne("dhoka","ढोका"),ne("bistari","बिस्तारै","बिस्तरी"),ne("banda","बन्द"),ne("garnus","गर्नुस्","गर्नुस")])
# English words embedded in Nepali requests.
add("mixed","aaja meeting sakiepachi call gara.","आज meeting सकिएपछि call गर.",[ne("aaja","आज"),en("meeting"),ne("sakiepachi","सकिएपछि"),en("call"),ne("gara","गर")])
add("mixed","mero laptop ko charger kata cha?","मेरो laptop को charger कहाँ छ?",[ne("mero","मेरो"),en("laptop"),ne("ko","को"),en("charger"),ne("kata","कहाँ","कता"),ne("cha","छ")])
add("mixed","yo file email ma pathaideu.","यो file email मा पठाइदेऊ.",[ne("yo","यो"),en("file"),en("email"),ne("ma","मा"),ne("pathaideu","पठाइदेऊ","पठाइदेउ")])
add("mixed","hami Sunday park ma bhetau.","हामी Sunday park मा भेटौँ.",[ne("hami","हामी"),en("Sunday"),en("park"),ne("ma","मा"),ne("bhetau","भेटौँ","भेटौं")])
add("mixed","please mero photo download gara.","please मेरो photo download गर.",[en("please"),ne("mero","मेरो"),en("photo"),en("download"),ne("gara","गर")])
add("mixed","aaja office bata late aauchu.","आज office बाट late आउँछु.",[ne("aaja","आज"),en("office"),ne("bata","बाट"),en("late"),ne("aauchu","आउँछु")])
add("mixed","timro phone ko screen futyo?","तिम्रो phone को screen फुट्यो?",[ne("timro","तिम्रो"),en("phone"),ne("ko","को"),en("screen"),ne("futyo","फुट्यो")])
add("mixed","project ko deadline next week ho.","project को deadline next week हो.",[en("project"),ne("ko","को"),en("deadline"),en("next"),en("week"),ne("ho","हो")])
add("mixed","maile coffee order gareko chu.","मैले coffee order गरेको छु.",[ne("maile","मैले"),en("coffee"),en("order"),ne("gareko","गरेको"),ne("chu","छु")])
add("mixed","bholi dentist ko appointment cha.","भोलि dentist को appointment छ.",[ne("bholi","भोलि"),en("dentist"),ne("ko","को"),en("appointment"),ne("cha","छ")])
add("mixed","yo link copy garera group ma halnu.","यो link copy गरेर group मा हाल्नु.",[ne("yo","यो"),en("link"),en("copy"),ne("garera","गरेर"),en("group"),ne("ma","मा"),ne("halnu","हाल्नु")])
# Ambiguity and language intent; each case asserts one proposed context.
add("ambiguity","mero man aaja khusi cha.","मेरो मन आज खुसी छ.",[ne("mero","मेरो"),ne("man","मन"),ne("aaja","आज"),ne("khusi","खुसी","खुशी"),ne("cha","छ")])
add("ambiguity","The man found the key.","The man found the key.",[en("The"),en("man"),en("found"),en("key")])
add("ambiguity","ma ghar ma baschu.","म घर मा बस्छु.",[ne("ma","म"),ne("ghar","घर"),ne("ma","मा"),ne("baschu","बस्छु")])
add("ambiguity","Please give me some water.","Please give me some water.",[en("Please"),en("give"),en("water")])
add("ambiguity","malai pani chahinchha.","मलाई पानी चाहिन्छ.",[ne("malai","मलाई"),ne("pani","पानी"),ne("chahinchha","चाहिन्छ")])
add("ambiguity","ma pani janchu.","म पनि जान्छु.",[ne("ma","म"),ne("pani","पनि"),ne("janchu","जान्छु")])
add("ambiguity","aaja kam samaya cha.","आज कम समय छ.",[ne("aaja","आज"),ne("kam","कम"),ne("samaya","समय"),ne("cha","छ")])
add("ambiguity","mero kam sakiyo.","मेरो काम सकियो.",[ne("mero","मेरो"),ne("kam","काम"),ne("sakiyo","सकियो")])
add("ambiguity","I will call my mom.","I will call my mom.",[en("I"),en("will"),en("call"),en("mom")])
add("ambiguity","usle ramro geet gayo.","उसले राम्रो गीत गायो.",[ne("usle","उसले"),ne("ramro","राम्रो"),ne("geet","गीत"),ne("gayo","गायो")])
add("ambiguity","cricket khelna park janchau?","cricket खेल्न park जान्छौ?",[en("cricket"),ne("khelna","खेल्न"),en("park"),ne("janchau","जान्छौ","जान्छौँ","जान्छौं")])
# Literal spans and sensitive-looking strings are fictional examples.
add("literal","Visit https://example.org/help tomorrow.","Visit https://example.org/help tomorrow.",[en("Visit"),lit("https://example.org/help"),en("tomorrow")])
add("literal","Send an email to hello@example.org.","Send an email to hello@example.org.",[en("Send"),en("email"),lit("hello@example.org")])
add("literal","mero file src/main.swift ma cha.","मेरो file src/main.swift मा छ.",[ne("mero","मेरो"),en("file"),lit("src/main.swift"),ne("ma","मा"),ne("cha","छ")])
add("literal","Keep user_name as written.","Keep user_name as written.",[en("Keep"),lit("user_name"),en("written")])
add("literal","Use HTTPS://EXAMPLE.ORG/ABC for help.","Use HTTPS://EXAMPLE.ORG/ABC for help.",[en("Use"),lit("HTTPS://EXAMPLE.ORG/ABC"),en("help")])
add("literal","👋 namaste sathi!","👋 नमस्ते साथी!",[lit("👋"),ne("namaste","नमस्ते"),ne("sathi","साथी")])
add("literal","The version2 file is ready.","The version2 file is ready.",[en("The"),lit("version2"),en("file"),en("ready")])
add("literal","Open settings.json and restart.","Open settings.json and restart.",[en("Open"),lit("settings.json"),en("restart")])
add("literal","hamro meeting room 2 ma cha.","हाम्रो meeting room 2 मा छ.",[ne("hamro","हाम्रो"),en("meeting"),en("room"),lit("2"),ne("ma","मा"),ne("cha","छ")])
add("literal","Keep myVariable unchanged.","Keep myVariable unchanged.",[en("Keep"),lit("myVariable"),en("unchanged")])
add("literal","Visit www.example.org/notes now.","Visit www.example.org/notes now.",[en("Visit"),lit("www.example.org/notes"),en("now")])
assert len(cases) == 55
target = Path(__file__).with_name("corpus.json")
target.write_text(json.dumps({"version":"platform-blind-v1","description":"Author-separated synthetic references; unreviewed and nonrepresentative.","cases":cases}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print("Wrote", len(cases), "cases")
