#include "composition.h"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <iostream>
using namespace lekha;

static void ok(Composition& c, const Intent& i) {
    assert(i.kind == Kind::Mark || i.kind == Kind::Commit);
    assert(c.acknowledge(i.generation, true));
}
int main() {
    Composition c, other;
    auto a = c.character(u'm'); assert(a.kind == Kind::Mark && a.text == u"m");
    assert(c.character(u'a').kind == Kind::Block); // pending host transaction
    assert(!c.acknowledge(a.generation + 1, true));
    ok(c, a);
    auto b = c.character(u'a'); ok(c, b);
    auto stale = c.choose(u"म", a.generation); assert(stale.kind == Kind::Block);
    auto selected = c.choose(u"म", c.generation()); assert(selected.text == u"म"); ok(c, selected);
    assert(c.original().empty());
    for (char16_t ch : std::u16string(u"https://a.com")) ok(c, c.character(ch));
    auto space = c.boundary(u' '); assert(space.text == u"https://a.com "); ok(c, space);
    for (char16_t ch : std::u16string(u"ma")) ok(c, c.character(ch));
    auto fail = c.interrupt(); assert(fail.text == u"ma" && fail.forward_after_commit);
    assert(c.acknowledge(fail.generation, false)); assert(c.original() == u"ma");
    assert(c.choose(u"म", fail.generation).kind == Kind::Block);
    auto retry = c.interrupt(); ok(c, retry);
    assert(c.original().empty());
    ok(other, other.character(u'x')); assert(other.original() == u"x" && c.original().empty());
    auto del = other.backspace(); assert(del.text.empty()); ok(other, del);
    assert(other.backspace().kind == Kind::Pass);
    assert(c.character(u'न').kind == Kind::Pass);
    for (int i = 0; i < 128; ++i) ok(c, c.character(u'a'));
    auto capped = c.character(u'b');
    assert(capped.kind == Kind::Commit && capped.forward_after_commit && capped.text.size() == 128);
    ok(c, capped);
    assert(!c.acknowledge(capped.generation, true));
    auto proposal = c.character(u'x');
    assert(c.acknowledge(proposal.generation, false));
    assert(c.original().empty());
    assert(c.choose(u"x", proposal.generation).kind == Kind::Block);
    std::cout << "PASS: composition transaction, originals, context isolation, stale candidate, failure and literal boundary\n";
}
