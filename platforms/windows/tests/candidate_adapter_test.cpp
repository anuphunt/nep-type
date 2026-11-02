#include "candidate_adapter.h"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <iostream>
#include <stdexcept>
#include <string>
using namespace lekha;

static void ack(Composition& c, Intent i, bool applied = true) {
    assert(i.kind == Kind::Mark || i.kind == Kind::Commit);
    assert(c.acknowledge(i.generation, applied));
}
static void type(CandidateAdapter& a, const std::u16string& text) {
    for (auto ch : text) ack(a.composition(), a.composition().character(ch));
}
static std::u16string decode_units(const std::string& s) {
    if (s.size() % 4 != 0) throw std::invalid_argument("invalid UTF-16 units");
    std::u16string out;
    for (size_t n = 0; n < s.size(); n += 4) out.push_back(static_cast<char16_t>(std::stoul(s.substr(n, 4), nullptr, 16)));
    return out;
}
int main(int argc, char** argv) {
    CandidateAdapter a(1), b(2);
    type(a, u"ma");
    auto old = *a.query();
    assert(a.accept(old, {u"म", u"म"}));
    assert((a.candidates() == std::vector<std::u16string>{u"ma", u"म"}));
    assert(a.choose(9).kind == Kind::Block);
    auto selected = a.choose(1); assert(selected.kind == Kind::Commit && selected.text == u"म");
    assert(a.candidates().empty());
    assert(!a.accept(old, {u"म"}));
    ack(a.composition(), selected, false);
    assert(a.composition().original() == u"ma" && a.candidates().empty());
    assert(!a.accept(old, {u"म"}));
    auto retry = *a.query();
    assert(!b.accept(retry, {u"म"}));
    assert(!a.accept(retry, {std::u16string(513, u'x')}));
    assert(!a.accept(retry, std::vector<std::u16string>(33, u"x")));
    assert(!a.accept(retry, {u"a\nb"}));
    assert(!a.accept(retry, {u"a\u202eb"}));
    assert(!a.accept(retry, {std::u16string(1, static_cast<char16_t>(0xd800))}));
    assert(a.accept(retry, {u"क्\u200dष", u"\U0001f642"}));
    assert(a.accept(retry, {u"म"}));
    ack(a.composition(), a.composition().character(u'n'));
    assert(a.candidates().empty() && a.choose(1).kind == Kind::Block);
    assert(!a.accept(retry, {u"म"}));
    auto interrupted = a.composition().interrupt();
    assert(interrupted.text == u"man" && interrupted.forward_after_commit);
    ack(a.composition(), interrupted);
    if (argc == 2) {
        const auto value = decode_units(argv[1]);
        type(a, u"namaste");
        auto request = *a.query();
        assert(a.accept(request, {value}));
        auto intent = a.choose(1);
        assert(intent.kind == Kind::Commit && intent.text == u"नमस्ते");
        ack(a.composition(), intent);
    }
    std::cout << "PASS: candidate response isolation, provenance, bounds, host failure and staleness" << (argc == 2 ? "; real engine candidate" : "") << "\n";
}
