// Experimental COM/TSF lifecycle only. No registration or text edits.
// Until a real engine and host-owned edit sessions are verified, all keys pass.
#ifdef LEKHA_TSF_TEST
#include "fake_tsf.h"
#else
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <msctf.h>
#endif
#include <atomic>
#include <new>
#include "edit_bridge.h"
#include "module_lifetime.h"

namespace {
// Private, development-only identity: no profile or COM registry entries are created.
const GUID CLSID_LekhaTextService = {0xb6a68f96, 0x5819, 0x4b7f, {0x85,0x69,0xa1,0x15,0x90,0xd1,0x20,0x01}};
std::atomic<long> live_objects{0};
std::atomic<long> server_locks{0};
std::atomic<std::uint64_t> next_session{1};

class TextService final : public ITfTextInputProcessor, public ITfKeyEventSink {
public:
    TextService() { ++live_objects; }
    ~TextService() {
#ifdef LEKHA_TSF_TEST
        if (test_context_) test_context_->Release();
#endif
        if (manager_) manager_->Release(); --live_objects;
    }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (IsEqualIID(iid, IID_IUnknown) || IsEqualIID(iid, IID_ITfTextInputProcessor))
            *out = static_cast<ITfTextInputProcessor*>(this);
        else if (IsEqualIID(iid, IID_ITfKeyEventSink))
            *out = static_cast<ITfKeyEventSink*>(this);
        else return E_NOINTERFACE;
        AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { ULONG remaining = --refs_; if (!remaining) delete this; return remaining; }
    HRESULT STDMETHODCALLTYPE Activate(ITfThreadMgr* thread, TfClientId client) override {
        if (!thread || client == TF_CLIENTID_NULL) return E_INVALIDARG;
        if (manager_) return E_UNEXPECTED;
        ITfKeystrokeMgr* keys = nullptr;
        HRESULT hr = thread->QueryInterface(IID_ITfKeystrokeMgr, reinterpret_cast<void**>(&keys));
        if (FAILED(hr)) return hr;
        hr = keys->AdviseKeyEventSink(client, static_cast<ITfKeyEventSink*>(this), TRUE);
        if (FAILED(hr)) { keys->Release(); return hr; }
        manager_ = keys; client_ = client;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE Deactivate() override {
        if (!manager_) return S_OK;
        // Keep ownership if unadvise fails: releasing a still-advised sink
        // would produce a dangling pointer. The host may retry Deactivate.
        HRESULT hr = manager_->UnadviseKeyEventSink(client_);
        if (FAILED(hr)) return hr;
#ifdef LEKHA_TSF_TEST
        if (test_context_) { bridge_.abandon(); testDisable(); }
#endif
        ITfKeystrokeMgr* old = manager_; manager_ = nullptr; client_ = TF_CLIENTID_NULL;
        old->Release();
        return S_OK;
    }
#ifdef LEKHA_TSF_TEST
    lekha::EditBridge& testBridge() { return bridge_; }
    bool testEnable(ITfContext* context, std::shared_ptr<lekha::HostEdit> host) {
        if (!manager_ || !bridge_.usable() || !context || !host || !host->owns_context(context) || test_context_) return false;
        context->AddRef(); test_context_ = context; test_host_ = std::move(host); return true;
    }
    void testDisable() {
        test_host_.reset(); if (test_context_) test_context_->Release(); test_context_ = nullptr;
    }
    bool testHandles(ITfContext* context, WPARAM key) {
        if (!manager_ || !test_host_ || context != test_context_ || !bridge_.usable()) return false;
        if (key >= 33 && key <= 126) return true;
        return (key == 8 || key == 9 || key == 10 || key == 32) && !bridge_.adapter().composition().original().empty();
    }
    HRESULT testDown(ITfContext* context, WPARAM key, BOOL* eaten) {
        if (!eaten) return E_POINTER;
        *eaten = FALSE;
        if (!testHandles(context, key)) return S_OK;
        auto& composition = bridge_.adapter().composition();
        lekha::Intent intent = key == 8 ? composition.backspace()
            : (key == 9 || key == 10 || key == 32) ? composition.boundary(static_cast<char16_t>(key))
            : composition.character(static_cast<char16_t>(key));
        if (intent.kind != lekha::Kind::Mark && intent.kind != lekha::Kind::Commit) return S_OK;
        // In the mock, a failed edit may already have mutated host text. Never
        // replay that key; disable this path and surface uncertainty to tests.
        *eaten = TRUE;
        if (!bridge_.apply(context, client_, intent, test_host_)) testDisable();
        return S_OK;
    }
#endif
    HRESULT STDMETHODCALLTYPE OnSetFocus(BOOL focused) override {
#ifdef LEKHA_TSF_TEST
        if (!focused && test_context_) { bridge_.abandon(); testDisable(); }
#else
        (void)focused;
#endif
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnTestKeyDown(ITfContext* context, WPARAM key, LPARAM, BOOL* eaten) override {
#ifdef LEKHA_TSF_TEST
        if (!eaten) return E_POINTER;
        *eaten = testHandles(context, key) ? TRUE : FALSE; return S_OK;
#else
        (void)context; (void)key; return pass(eaten);
#endif
    }
    HRESULT STDMETHODCALLTYPE OnTestKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override { return pass(eaten); }
    HRESULT STDMETHODCALLTYPE OnKeyDown(ITfContext* context, WPARAM key, LPARAM, BOOL* eaten) override {
#ifdef LEKHA_TSF_TEST
        return testDown(context, key, eaten);
#else
        (void)context; (void)key; return pass(eaten);
#endif
    }
    HRESULT STDMETHODCALLTYPE OnKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override { return pass(eaten); }
    HRESULT STDMETHODCALLTYPE OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) override { return pass(eaten); }
private:
    static HRESULT pass(BOOL* eaten) { if (!eaten) return E_POINTER; *eaten = FALSE; return S_OK; }
    std::atomic<ULONG> refs_{1};
    // Dormant until a concrete safe host range adapter and engine exist.
    lekha::EditBridge bridge_{next_session.fetch_add(1)};
#ifdef LEKHA_TSF_TEST
    ITfContext* test_context_ = nullptr;
    std::shared_ptr<lekha::HostEdit> test_host_;
#endif
    ITfKeystrokeMgr* manager_ = nullptr;
    TfClientId client_ = TF_CLIENTID_NULL;
};

class Factory final : public IClassFactory {
public:
    Factory() { ++live_objects; }
    ~Factory() { --live_objects; }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (!IsEqualIID(iid, IID_IUnknown) && !IsEqualIID(iid, IID_IClassFactory)) return E_NOINTERFACE;
        *out = static_cast<IClassFactory*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { ULONG remaining = --refs_; if (!remaining) delete this; return remaining; }
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        TextService* service = nullptr;
        try { service = new(std::nothrow) TextService(); }
        catch (...) { return E_OUTOFMEMORY; }
        if (!service) return E_OUTOFMEMORY;
        HRESULT hr = service->QueryInterface(iid, out); service->Release(); return hr;
    }
    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override {
        if (lock) { ++server_locks; return S_OK; }
        auto n = server_locks.load();
        do { if (n <= 0) return E_UNEXPECTED; } while (!server_locks.compare_exchange_weak(n, n - 1));
        return S_OK;
    }
private:
    std::atomic<ULONG> refs_{1};
};
}

extern "C" __declspec(dllexport) HRESULT __stdcall DllGetClassObject(REFCLSID clsid, REFIID iid, void** out) {
    if (!out) return E_POINTER; *out = nullptr;
    if (!IsEqualCLSID(clsid, CLSID_LekhaTextService)) return CLASS_E_CLASSNOTAVAILABLE;
    auto* factory = new(std::nothrow) Factory();
    if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(iid, out); factory->Release(); return hr;
}
extern "C" __declspec(dllexport) HRESULT __stdcall DllCanUnloadNow() {
    return live_objects.load() == 0 && server_locks.load() == 0 && lekha::live_edit_sessions.load() == 0 ? S_OK : S_FALSE;
}

#ifdef LEKHA_TSF_TEST
extern "C" lekha::EditBridge* LekhaTestBridge(ITfTextInputProcessor* service) {
    return service ? &static_cast<TextService*>(service)->testBridge() : nullptr;
}
#endif

#ifdef LEKHA_TSF_TEST
extern "C" bool LekhaTestEnableSink(ITfTextInputProcessor* service, ITfContext* context, lekha::HostEdit* host) {
    if (!service || !host) return false;
    return static_cast<TextService*>(service)->testEnable(context, std::shared_ptr<lekha::HostEdit>(host, [](lekha::HostEdit*){}));
}
#endif
