#include "keyboard_session.h"
#include "keyboard_engine.h"
#include <cassert>
#include <chrono>
#include <iostream>

using namespace neptype;
static void type(CandidateAdapter& adapter, const std::u16string& text) {
    for (auto ch : text) {
        auto intent = adapter.composition().character(ch);
        assert(intent.kind == Kind::Mark && adapter.composition().acknowledge(intent.generation, true));
    }
}
int main(int argc, char** argv) {
    assert(keyboard_utf16("\xF0\x9F\x98\x80") == u"😀");
    for (const auto& bad : {std::string("\xC0\xAF"), std::string("\xED\xA0\x80"), std::string("\xF4\x90\x80\x80"), std::string("\xE0\xA4")}) {
        bool rejected = false;
        try { keyboard_utf16(bad); } catch (...) { rejected = true; }
        assert(rejected);
    }
    CandidateAdapter adapter(1);
    KeyboardSession policy(adapter, [](const std::u16string& word, int mode) {
        assert(word == u"namaste" && mode == 0);
        return std::vector<std::u16string>{u"नमस्ते", u"नमस्कार"};
    });
    type(adapter, u"namaste"); assert(policy.refresh(0));
    auto choices = adapter.candidates(); assert(choices[0] == u"namaste" && choices[1] == u"नमस्ते");
    assert(adapter.choose(1,u"\n").kind == Kind::Block && !adapter.composition().has_pending());
    auto accept = policy.commit(true);
    assert(accept.kind == Kind::Commit && accept.text == u"नमस्ते " && !accept.forward_after_commit);
    assert(adapter.composition().acknowledge(accept.generation, true));
    type(adapter, u"namaste"); assert(policy.refresh(0));
    auto roman = policy.commit(false, false, true);
    assert(roman.text == u"namaste"); assert(adapter.composition().acknowledge(roman.generation, true));
    type(adapter, u"namaste"); assert(policy.refresh(0)); policy.cycle(1);
    auto other = policy.commit(false, true); assert(other.text == u"नमस्कार" && other.forward_after_commit);
    assert(adapter.composition().acknowledge(other.generation, true));
    type(adapter, u"namaste"); assert(policy.refresh(0));
    auto back = adapter.composition().backspace(); assert(adapter.composition().acknowledge(back.generation, true));
    assert(policy.commit().kind == Kind::Block); // choices became stale after editing
    auto interrupted = adapter.composition().interrupt();
    assert(interrupted.text == u"namast" && interrupted.forward_after_commit);
    assert(adapter.composition().acknowledge(interrupted.generation, true));
    KeyboardSession failing(adapter, [](const std::u16string&, int) -> std::vector<std::u16string> { throw 1; });
    type(adapter, u"https://neptype.com"); assert(failing.refresh(0));
    auto preserved = failing.commit(true); assert(preserved.text == u"https://neptype.com ");
    assert(adapter.composition().acknowledge(preserved.generation, true));
    KeyboardSession malformed(adapter, [](const std::u16string&, int) { return std::vector<std::u16string>{u"bad\ntext"}; });
    type(adapter,u"safe"); assert(malformed.refresh(0)); assert(malformed.commit().text == u"safe");
    if (argc > 1) {
        Engine engine(argv[1], "");
        CandidateAdapter real(2);
        KeyboardSession live(real, [&](const std::u16string& word, int mode) { return keyboard_candidates(engine, word, mode); });
        const auto begin = std::chrono::steady_clock::now();
        for (int i = 0; i < 100; ++i) {
            type(real,u"namaste"); assert(live.refresh(0));
            auto commit = live.commit(true); assert(commit.text == u"नमस्ते ");
            assert(real.composition().acknowledge(commit.generation,true));
        }
        for (const auto& word : {u"https://neptype.com", u"name@example.com", u"123.45"}) {
            type(real,word); assert(live.refresh(0)); auto commit=live.commit(true);
            assert(commit.text == std::u16string(word)+u" ");
            assert(real.composition().acknowledge(commit.generation,true));
        }
        type(real,u"hello"); assert(live.refresh(1)); assert(live.commit().text == u"hello");
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-begin).count();
        std::cout << "Real shared engine: 100 conversions and literal URL/email/number checks, " << elapsed << " ms\n";
    }
    std::cout << "PASS: keyboard policy, default/explicit/literal choice, boundaries, staleness and engine failure\n";
}
