#include "edit_bridge.h"
#include <cassert>
#include <iostream>
#include <thread>
using namespace lekha;
class FakeContext final : public ITfContext {
public:
    ULONG refs = 1; bool deny = false, skip = false, dishonest = false, foreign = false; int calls = 0;
    HRESULT QueryInterface(REFIID, void** out) override { if (!out) return E_POINTER; *out = nullptr; return E_NOINTERFACE; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { return --refs; }
    HRESULT RequestEditSession(TfClientId client, ITfEditSession* edit, DWORD flags, HRESULT* result) override {
        assert(client == 9 && flags == (TF_ES_SYNC | TF_ES_READWRITE)); ++calls;
        if (deny) return E_FAIL;
        if (skip) { *result = S_OK; return S_OK; }
        if (foreign) { std::thread t([&] { *result = edit->DoEditSession(17); }); t.join(); return S_OK; }
        *result = edit->DoEditSession(17);
        return dishonest ? E_FAIL : S_OK;
    }
};
class FakeHost final : public HostEdit {
public:
    bool accept = true; int calls = 0; std::u16string marked;
    bool apply(TfEditCookie cookie, const Intent& intent) override {
        assert(cookie == 17); ++calls;
        if (!accept) return false;
        marked = intent.text; return true;
    }
};
int main() {
    FakeContext context;
    auto host = std::make_shared<FakeHost>();
    EditBridge bridge(1);
    auto first = bridge.adapter().composition().character(u'm');
    assert(!bridge.apply(nullptr,9,first,host));
    // A matching generation alone does not authorize a different host edit.
    auto forged = first; forged.text = u"other";
    assert(!bridge.apply(&context,9,forged,host));
    forged = first; forged.kind = Kind::Commit;
    assert(!bridge.apply(&context,9,forged,host));
    forged = first; forged.forward_after_commit = true;
    assert(!bridge.apply(&context,9,forged,host));
    assert(context.calls == 0 && host->calls == 0 && bridge.usable());
    assert(bridge.apply(&context,9,first,host));
    assert(host->marked == u"m" && bridge.adapter().composition().original() == u"m");
    auto second = bridge.adapter().composition().character(u'a');
    assert(bridge.apply(&context,9,second,host));
    auto query = bridge.adapter().query(); assert(query && query->original == u"ma");
    assert(bridge.adapter().accept(*query,{u"म"}));
    auto choose = bridge.adapter().choose(1);
    assert(bridge.apply(&context,9,choose,host));
    assert(host->marked == u"म" && bridge.adapter().composition().original().empty());
    EditBridge denied(2); auto pending = denied.adapter().composition().character(u'x');
    context.deny = true; assert(!denied.apply(&context,9,pending,host)); assert(!denied.usable());
    assert(!denied.apply(&context,9,pending,host)); context.deny = false;
    EditBridge failure(3); auto item = failure.adapter().composition().character(u'q'); host->accept = false;
    assert(!failure.apply(&context,9,item,host)); assert(!failure.usable()); assert(failure.adapter().composition().original().empty());
    host->accept = true; EditBridge skipped(4); auto x = skipped.adapter().composition().character(u'a');
    context.skip=true; assert(!skipped.apply(&context,9,x,host)); assert(!skipped.usable()); context.skip=false;
    EditBridge inconsistent(5); auto y=inconsistent.adapter().composition().character(u'b');
    context.dishonest=true; assert(!inconsistent.apply(&context,9,y,host)); assert(!inconsistent.usable());
    context.dishonest=false; context.foreign=true;
    EditBridge foreign(6); auto z=foreign.adapter().composition().character(u'z'); int oldCalls=host->calls;
    assert(!foreign.apply(&context,9,z,host)); assert(!foreign.usable()); assert(host->calls==oldCalls);
    EditBridge abandoned(7); auto a = abandoned.adapter().composition().character(u'a');
    abandoned.abandon(); context.foreign = false;
    assert(!abandoned.apply(&context,9,a,host) && !abandoned.usable() && host->calls==oldCalls);
    std::cout << "PASS: mocked synchronous TSF edit dispatch, candidate, rejection and no-retry guards\n";
}
