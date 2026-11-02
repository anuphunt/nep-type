#include "fake_tsf.h"
#include "edit_bridge.h"
#include <cassert>
#include <iostream>
extern "C" HRESULT DllGetClassObject(REFCLSID, REFIID, void**);
extern "C" HRESULT DllCanUnloadNow();
extern "C" lekha::EditBridge* LekhaTestBridge(ITfTextInputProcessor*);
extern "C" bool LekhaTestEnableSink(ITfTextInputProcessor*, ITfContext*, lekha::HostEdit*);
class MockContext : public ITfContext {
public:
    ULONG refs = 1; bool reject = false, retain = false;
    ITfEditSession* retained = nullptr;
    HRESULT QueryInterface(REFIID, void** out) override { if (out) *out = nullptr; return E_NOINTERFACE; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { return --refs; }
    HRESULT RequestEditSession(TfClientId, ITfEditSession* edit, DWORD, HRESULT* result) override {
        if (reject) return E_FAIL;
        if (retain) { edit->AddRef(); retained = edit; *result = S_OK; return S_OK; }
        *result = edit->DoEditSession(17); return S_OK;
    }
};
class MockHost : public lekha::HostEdit {
public:
    ITfContext* context; std::u16string text; int calls = 0;
    explicit MockHost(ITfContext* c):context(c) {}
    bool owns_context(ITfContext* c) const override { return c == context; }
    bool apply(TfEditCookie, const lekha::Intent& intent) override { ++calls; text = intent.text; return true; }
};
constexpr GUID CLSID_Lekha = {0xb6a68f96, 0x5819, 0x4b7f, {0x85,0x69,0xa1,0x15,0x90,0xd1,0x20,0x01}};
class FakeKeys : public ITfKeystrokeMgr {
public:
    ULONG refs = 1; ITfKeyEventSink* sink = nullptr; TfClientId id = 0;
    bool failAdvise = false, failUnadvise = false;
    HRESULT QueryInterface(REFIID i, void** out) override { if (!out) return E_POINTER; *out = nullptr; if (!IsEqualIID(i,IID_ITfKeystrokeMgr) && !IsEqualIID(i,IID_IUnknown)) return E_NOINTERFACE; *out=this; AddRef(); return S_OK; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { return --refs; }
    HRESULT AdviseKeyEventSink(TfClientId c, ITfKeyEventSink* s, BOOL foreground) override { if (failAdvise) return E_UNEXPECTED; assert(foreground && !sink); id=c; sink=s; sink->AddRef(); return S_OK; }
    HRESULT UnadviseKeyEventSink(TfClientId c) override { if (failUnadvise) return E_UNEXPECTED; assert(c==id && sink); auto* old=sink; sink=nullptr; id=0; old->Release(); return S_OK; }
};
class FakeThread : public ITfThreadMgr {
public:
    FakeKeys keys; ULONG refs = 1;
    HRESULT QueryInterface(REFIID iid, void** out) override { return keys.QueryInterface(iid,out); }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { return --refs; }
};
int main() {
    assert(DllCanUnloadNow() == S_OK);
    void* raw = nullptr; GUID other{42,0,0,{}};
    assert(DllGetClassObject(other,IID_IClassFactory,&raw) == CLASS_E_CLASSNOTAVAILABLE && !raw);
    assert(DllGetClassObject(CLSID_Lekha,IID_IClassFactory,nullptr) == E_POINTER);
    assert(DllGetClassObject(CLSID_Lekha,IID_IClassFactory,&raw) == S_OK);
    auto* factory=static_cast<IClassFactory*>(raw); assert(DllCanUnloadNow()==S_FALSE);
    assert(factory->LockServer(TRUE)==S_OK); assert(factory->LockServer(FALSE)==S_OK);
    assert(factory->LockServer(FALSE)==E_UNEXPECTED);
    assert(factory->CreateInstance(factory,IID_ITfTextInputProcessor,&raw)==CLASS_E_NOAGGREGATION && !raw);
    assert(factory->CreateInstance(nullptr,IID_ITfTextInputProcessor,&raw)==S_OK);
    auto* service=static_cast<ITfTextInputProcessor*>(raw);
    auto* bridge = LekhaTestBridge(service);
    assert(bridge && bridge->usable() && !bridge->adapter().query());
    FakeThread thread;
    assert(service->Activate(nullptr, 1)==E_INVALIDARG);
    thread.keys.failAdvise=true; assert(service->Activate(&thread,1)==E_UNEXPECTED); assert(thread.keys.refs==1);
    thread.keys.failAdvise=false; assert(service->Activate(&thread,1)==S_OK);
    assert(service->Activate(&thread,1)==E_UNEXPECTED);
    BOOL eaten=TRUE;
    assert(thread.keys.sink->OnTestKeyDown(nullptr,'a',0,&eaten)==S_OK && !eaten);
    eaten=TRUE; assert(thread.keys.sink->OnTestKeyUp(nullptr,'a',0,&eaten)==S_OK && !eaten);
    eaten=TRUE; assert(thread.keys.sink->OnKeyDown(nullptr,'a',0,&eaten)==S_OK && !eaten);
    eaten=TRUE; assert(thread.keys.sink->OnKeyUp(nullptr,'a',0,&eaten)==S_OK && !eaten);
    eaten=TRUE; assert(thread.keys.sink->OnPreservedKey(nullptr,other,&eaten)==S_OK && !eaten);
    assert(thread.keys.sink->OnSetFocus(FALSE)==S_OK);
    assert(thread.keys.sink->OnPreservedKey(nullptr,other,nullptr)==E_POINTER);
    // Mock-only end-to-end sink path. WPARAM here is injected text, not a
    // real Windows virtual key; production callbacks remain pass-through.
    MockContext context; MockHost host(&context);
    assert(LekhaTestEnableSink(service, &context, &host));
    eaten=FALSE; assert(thread.keys.sink->OnTestKeyDown(&context,'m',0,&eaten)==S_OK && eaten);
    assert(host.calls==0 && bridge->adapter().composition().original().empty());
    eaten=FALSE; assert(thread.keys.sink->OnKeyDown(&context,'m',0,&eaten)==S_OK && eaten && host.text==u"m");
    eaten=FALSE; assert(thread.keys.sink->OnKeyDown(&context,'a',0,&eaten)==S_OK && eaten && host.text==u"ma");
    assert(bridge->adapter().composition().original()==u"ma");
    auto query = bridge->adapter().query();
    assert(query && bridge->adapter().accept(*query, {u"म"}));
    auto chosen = bridge->adapter().choose(1);
    assert(bridge->apply(&context, 1, chosen, std::shared_ptr<lekha::HostEdit>(&host, [](lekha::HostEdit*){})));
    assert(host.text == u"म" && bridge->adapter().composition().original().empty());
    eaten=FALSE; assert(thread.keys.sink->OnKeyDown(&context,'a',0,&eaten)==S_OK && eaten && host.text==u"a");
    eaten=FALSE; assert(thread.keys.sink->OnKeyDown(&context,' ',0,&eaten)==S_OK && eaten && host.text==u"a ");
    assert(bridge->adapter().composition().original().empty());
    MockContext otherContext; eaten=TRUE;
    assert(thread.keys.sink->OnTestKeyDown(&otherContext,'x',0,&eaten)==S_OK && !eaten);
    context.reject = true; eaten=FALSE;
    assert(thread.keys.sink->OnKeyDown(&context,'x',0,&eaten)==S_OK && eaten && !bridge->usable());
    eaten=TRUE; assert(thread.keys.sink->OnTestKeyDown(&context,'y',0,&eaten)==S_OK && !eaten);
    // A hostile or broken host may retain an uncalled synchronous session.
    // After its service is released, that reference must still pin the DLL.
    MockContext retainedContext; MockHost retainedHost(&retainedContext);
    lekha::EditBridge retainedBridge(99);
    auto pending = retainedBridge.adapter().composition().character(u'z');
    retainedContext.retain = true;
    assert(!retainedBridge.apply(&retainedContext, 1, pending, std::shared_ptr<lekha::HostEdit>(&retainedHost, [](lekha::HostEdit*){})));
    assert(retainedContext.retained && !retainedBridge.usable());
    assert(retainedContext.retained->DoEditSession(17)==E_UNEXPECTED && retainedHost.calls==0);
    thread.keys.failUnadvise=true; assert(service->Deactivate()==E_UNEXPECTED && thread.keys.sink);
    thread.keys.failUnadvise=false; assert(service->Deactivate()==S_OK && !thread.keys.sink && thread.keys.refs==1);
    assert(service->Deactivate()==S_OK);
    // Focus loss must not let a stale mock context consume later keys or be
    // rebound while its host-owned composition is unresolved.
    void* secondRaw = nullptr;
    assert(factory->CreateInstance(nullptr,IID_ITfTextInputProcessor,&secondRaw)==S_OK);
    auto* secondService = static_cast<ITfTextInputProcessor*>(secondRaw);
    assert(secondService->Activate(&thread,2)==S_OK);
    MockContext focusedContext; MockHost focusedHost(&focusedContext);
    assert(LekhaTestEnableSink(secondService, &focusedContext, &focusedHost));
    eaten=FALSE; assert(thread.keys.sink->OnKeyDown(&focusedContext,'n',0,&eaten)==S_OK && eaten);
    assert(focusedHost.text==u"n" && focusedContext.refs==2);
    assert(thread.keys.sink->OnSetFocus(FALSE)==S_OK && focusedContext.refs==1);
    eaten=TRUE; assert(thread.keys.sink->OnTestKeyDown(&focusedContext,'x',0,&eaten)==S_OK && !eaten);
    assert(!LekhaTestEnableSink(secondService, &focusedContext, &focusedHost));
    assert(focusedHost.text==u"n" && focusedHost.calls==1);
    assert(secondService->Deactivate()==S_OK); secondService->Release();
    void* thirdRaw = nullptr;
    assert(factory->CreateInstance(nullptr,IID_ITfTextInputProcessor,&thirdRaw)==S_OK);
    auto* thirdService = static_cast<ITfTextInputProcessor*>(thirdRaw);
    assert(thirdService->Activate(&thread,3)==S_OK);
    MockContext deactivatedContext; MockHost deactivatedHost(&deactivatedContext);
    assert(LekhaTestEnableSink(thirdService, &deactivatedContext, &deactivatedHost));
    eaten=FALSE; assert(thread.keys.sink->OnKeyDown(&deactivatedContext,'p',0,&eaten)==S_OK && eaten);
    assert(thirdService->Deactivate()==S_OK && deactivatedContext.refs==1);
    assert(thirdService->Activate(&thread,4)==S_OK);
    assert(!LekhaTestEnableSink(thirdService, &deactivatedContext, &deactivatedHost));
    eaten=TRUE; assert(thread.keys.sink->OnTestKeyDown(&deactivatedContext,'x',0,&eaten)==S_OK && !eaten);
    assert(deactivatedHost.text==u"p" && deactivatedHost.calls==1);
    assert(thirdService->Deactivate()==S_OK); thirdService->Release();
    service->Release(); factory->Release(); assert(DllCanUnloadNow()==S_FALSE);
    retainedContext.retained->Release(); retainedContext.retained = nullptr;
    assert(DllCanUnloadNow()==S_OK);
    std::cout << "PASS: mocked TSF COM lifecycle and fail-closed key pass-through\n";
}
