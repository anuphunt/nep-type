#include "windows_support.h"
#include "field_policy.h"
#include "candidate_window.h"
#include "owned_range.h"
#include "keyboard_session.h"
#include "keyboard_engine.h"
#include <array>
#include <functional>
#include <map>
#include <memory>
#include <thread>
#ifdef NEPTYPE_TSF_DIAGNOSTICS
#include <cstdio>
#endif

namespace neptype::tsf {
namespace {
std::atomic<long> server_locks{0};
std::atomic<std::uint64_t> next_session{1};
void activation_trace(const char* stage, HRESULT result, TfClientId client) {
#ifdef NEPTYPE_TSF_DIAGNOSTICS
    // CI-only API diagnostics. Never includes host text or engine input.
    std::fprintf(stderr,"NepType activation %s: hr=0x%08lx client=%lu\n",stage,
        static_cast<unsigned long>(result),static_cast<unsigned long>(client));
    std::fflush(stderr);
#else
    (void)stage; (void)result; (void)client;
#endif
}

// Only synchronous key edits can consume events. Cleanup is asynchronous and
// only ends an owned composition, never rewrites text or moves the caret.
class Edit final : public ITfEditSession, private Lifetime {
public:
    explicit Edit(std::function<HRESULT(TfEditCookie)> work) : work_(std::move(work)) {}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid != IID_IUnknown && iid != IID_ITfEditSession) return E_NOINTERFACE;
        *out = static_cast<ITfEditSession*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { auto n = --refs_; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE DoEditSession(TfEditCookie cookie) override {
        if (owner_ != std::this_thread::get_id() || closed_.load() || called_) return E_UNEXPECTED;
        called_ = true;
        try { return work_(cookie); } catch (...) { return E_FAIL; }
    }
    void close() { closed_.store(true); work_ = {}; }
    bool called() const { return called_; }
private:
    std::atomic<ULONG> refs_{1};
    std::function<HRESULT(TfEditCookie)> work_;
    std::thread::id owner_ = std::this_thread::get_id();
    std::atomic<bool> closed_{false};
    bool called_ = false;
};

struct State;
class CompositionSink final : public ITfCompositionSink, private Lifetime {
public:
    explicit CompositionSink(std::weak_ptr<State> state) : state_(std::move(state)) {}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid != IID_IUnknown && iid != IID_ITfCompositionSink) return E_NOINTERFACE;
        *out = static_cast<ITfCompositionSink*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { auto n = --refs_; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE OnCompositionTerminated(TfEditCookie, ITfComposition* composition) override;
private:
    std::atomic<ULONG> refs_{1};
    std::weak_ptr<State> state_;
};
struct State {
    explicit State(ITfContext* c, KeyboardSession::Convert convert)
        : context(c), host(c), adapter(next_session.fetch_add(1)), policy(adapter, std::move(convert)) {}
    ComPtr<ITfContext> context;
    OwnedRange host;
    CandidateAdapter adapter;
    KeyboardSession policy;
    ComPtr<ITfCompositionSink> sink;
    ComPtr<ITfSource> source;
    DWORD edit_sink_cookie = TF_INVALID_COOKIE;
    bool terminated = false, disabled = false, editing = false, retired = false, literal_tail = false;
    void reset() {
        adapter = CandidateAdapter(next_session.fetch_add(1));
        terminated = false;
    }
};
HRESULT CompositionSink::OnCompositionTerminated(TfEditCookie, ITfComposition* composition) {
    if (auto state = state_.lock()) { state->host.terminated(composition); state->terminated = true; }
    return S_OK;
}

struct Key {
    WPARAM virtual_key = 0;
    char16_t text = 0;
    bool control = false, shift = false, alt = false, windows = false, repeat = false;
    bool mode() const { return control && shift && !alt && !windows && virtual_key == VK_SPACE; }
    int choice() const { return control && !shift && !alt && !windows && virtual_key >= '1' && virtual_key <= '4' ? static_cast<int>(virtual_key - '1') : -1; }
    bool shortcut() const { return control || alt || windows; }
};
bool modifier_key(WPARAM key) {
    return key == VK_SHIFT || key == VK_LSHIFT || key == VK_RSHIFT ||
        key == VK_CONTROL || key == VK_LCONTROL || key == VK_RCONTROL ||
        key == VK_MENU || key == VK_LMENU || key == VK_RMENU ||
        key == VK_LWIN || key == VK_RWIN || key == VK_CAPITAL;
}
Key translate(WPARAM key, LPARAM flags) {
    Key value; value.virtual_key = key; value.repeat = (flags & (1LL << 30)) != 0;
    BYTE state[256]{};
    if (!GetKeyboardState(state)) return value;
    value.control = (state[VK_CONTROL] & 0x80) != 0;
    value.shift = (state[VK_SHIFT] & 0x80) != 0;
    value.alt = (state[VK_MENU] & 0x80) != 0;
    value.windows = (state[VK_LWIN] & 0x80) || (state[VK_RWIN] & 0x80);
    if (!value.shortcut()) {
        wchar_t out[8]{};
        // Flag 4 leaves the dead-key state untouched (Windows 10 1607+).
        int n = ToUnicodeEx(static_cast<UINT>(key), static_cast<UINT>((flags >> 16) & 0xff), state, out, 8, 4, GetKeyboardLayout(0));
        if (n == 1 && out[0] >= 33 && out[0] <= 126) value.text = static_cast<char16_t>(out[0]);
    }
    return value;
}

class TextService final : public ITfTextInputProcessorEx, public ITfKeyEventSink,
                          public ITfThreadMgrEventSink, public ITfTextEditSink, private Lifetime {
public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid == IID_IUnknown || iid == IID_ITfTextInputProcessor || iid == IID_ITfTextInputProcessorEx)
            *out = static_cast<ITfTextInputProcessorEx*>(this);
        else if (iid == IID_ITfKeyEventSink) *out = static_cast<ITfKeyEventSink*>(this);
        else if (iid == IID_ITfThreadMgrEventSink) *out = static_cast<ITfThreadMgrEventSink*>(this);
        else if (iid == IID_ITfTextEditSink) *out = static_cast<ITfTextEditSink*>(this);
        else return E_NOINTERFACE;
        AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { auto n = --refs_; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE Activate(ITfThreadMgr* thread, TfClientId client) override { return ActivateEx(thread, client, 0); }
    HRESULT STDMETHODCALLTYPE ActivateEx(ITfThreadMgr* thread, TfClientId client, DWORD flags) override {
        activation_trace("begin",S_OK,client);
        if (!thread || client == TF_CLIENTID_NULL) return E_INVALIDARG;
        if (thread_) return E_UNEXPECTED;
        // Never instantiate the engine or sink on the Windows secure desktop.
        if (flags & TF_TMAE_SECUREMODE) return E_ACCESSDENIED;
        try {
            auto path = std::filesystem::path(module_path()).parent_path() / L"NepTypeEngine.dll";
            engine_ = std::make_shared<Engine>(path.u8string(), "");
            activation_trace("engine",S_OK,client);
            auto hr = thread->QueryInterface(IID_ITfKeystrokeMgr, reinterpret_cast<void**>(keys_.put()));
            activation_trace("query-keys",hr,client);
            if (FAILED(hr)) return hr;
            hr = thread->QueryInterface(IID_ITfSource, reinterpret_cast<void**>(source_.put()));
            activation_trace("query-source",hr,client);
            if (FAILED(hr)) return hr;
            hr = source_->AdviseSink(IID_ITfThreadMgrEventSink, static_cast<ITfThreadMgrEventSink*>(this), &sink_cookie_);
            activation_trace("advise-thread-events",hr,client);
            if (FAILED(hr)) { source_.reset(); keys_.reset(); engine_.reset(); return hr; }
            hr = keys_->AdviseKeyEventSink(client, static_cast<ITfKeyEventSink*>(this), TRUE);
            activation_trace("advise-keys",hr,client);
            if (FAILED(hr)) { source_->UnadviseSink(sink_cookie_); sink_cookie_ = TF_INVALID_COOKIE; source_.reset(); keys_.reset(); engine_.reset(); return hr; }
            thread_ = ComPtr<ITfThreadMgr>(thread); client_ = client; active_ = true;
            return S_OK;
        } catch (...) { activation_trace("exception",E_FAIL,client); engine_.reset(); return E_FAIL; }
    }
    HRESULT STDMETHODCALLTYPE Deactivate() override {
        active_ = false; window_.hide();
        leave();
        if (!states_.empty()) return E_FAIL;
        if (keys_) {
            const auto hr = keys_->UnadviseKeyEventSink(client_);
            if (FAILED(hr)) return hr;
            keys_.reset();
        }
        if (source_ && sink_cookie_ != TF_INVALID_COOKIE) {
            const auto hr = source_->UnadviseSink(sink_cookie_);
            if (FAILED(hr)) return hr;
            sink_cookie_ = TF_INVALID_COOKIE;
        }
        source_.reset(); thread_.reset(); engine_.reset(); client_ = TF_CLIENTID_NULL;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnSetFocus(BOOL focused) override {
        if (!focused) leave(); return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnInitDocumentMgr(ITfDocumentMgr*) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnUninitDocumentMgr(ITfDocumentMgr*) override { leave(); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnSetFocus(ITfDocumentMgr*, ITfDocumentMgr*) override { leave(); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnPushContext(ITfContext*) override { leave(); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnPopContext(ITfContext*) override { leave(); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnEndEdit(ITfContext* context, TfEditCookie cookie, ITfEditRecord*) override {
        auto found = states_.find(context);
        if (found == states_.end() || found->second->editing) return S_OK;
        auto state = found->second;
        if (state->host.active() && (!state->host.can_edit(cookie) || !allows_conversion(context, cookie))) {
            // Mouse selection or an external edit invalidates candidate UI
            // immediately, before another key can select an obsolete choice.
            window_.hide(); state->retired = true; cleanup(state);
            if (unadvise(state)) states_.erase(context);
        }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnTestKeyDown(ITfContext* context, WPARAM key, LPARAM flags, BOOL* eaten) override {
        if (!eaten) return E_POINTER; *eaten = FALSE;
        if (!active_ || !context || modifier_key(key)) return S_OK;
        const auto value = translate(key, flags);
        const auto found = states_.find(context);
        const bool composing = found != states_.end() && found->second->host.active();
        // Testing never edits, creates a context, calls the engine or changes
        // candidate/mode state. Field/ownership checks happen under a cookie.
        const bool tail = found != states_.end() && found->second->literal_tail;
        *eaten = value.mode() || (mode_ != 1 && value.text) || composing || tail;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnKeyDown(ITfContext* context, WPARAM key, LPARAM flags, BOOL* eaten) override {
        if (!eaten) return E_POINTER; *eaten = FALSE;
        if (!active_ || !context || modifier_key(key)) return S_OK;
        bool consumed = false;
        try {
            auto state = get(context);
            if (state->disabled || state->retired) return S_OK;
            auto value = translate(key, flags);
            auto* edit = new Edit([&, state](TfEditCookie cookie) {
                if (state->terminated) { state->reset(); window_.hide(); }
                if (!allows_conversion(context, cookie)) {
                    state->host.finish(cookie); state->reset(); window_.hide(); return S_OK;
                }
                if (state->host.active() && !state->host.can_edit(cookie)) {
                    // Selection/cursor/undo changed outside this composition.
                    // Preserve the text in place; never follow a moved range.
                    if (!state->host.finish(cookie)) { state->disabled = true; return E_FAIL; }
                    state->reset(); window_.hide();
                }
                auto& composition = state->adapter.composition();
                const bool composing = !composition.original().empty();
                if (value.mode()) {
                    if (!state->host.finish(cookie)) { state->disabled = true; return E_FAIL; }
                    state->reset(); window_.hide();
                    if (!value.repeat) mode_ = mode_ == 0 ? 2 : mode_ == 2 ? 1 : 0;
                    state->literal_tail = false;
                    consumed = true; return S_OK;
                }
                if (mode_ == 1) return S_OK;
                if (state->literal_tail) {
                    if (key == VK_SPACE || key == VK_RETURN || key == VK_TAB || value.shortcut() || !value.text)
                        state->literal_tail = false;
                    return S_OK;
                }
                Intent intent;
                bool forward = false;
                if (composing && value.choice() >= 0) {
                    intent = state->policy.choose(static_cast<std::size_t>(value.choice()));
                    if (intent.kind == Kind::Block) return S_OK;
                } else if (composing && !value.shortcut() && (key == VK_UP || key == VK_DOWN)) {
                    state->policy.cycle(key == VK_UP ? -1 : 1);
                    window_.show(context, cookie, state->adapter.candidates(), state->policy.selected(), mode_);
                    consumed = true; return S_OK;
                } else if (composing && !value.shortcut() && key == VK_ESCAPE) {
                    intent = state->policy.commit(false, false, true);
                } else if (composing && !value.shortcut() && key == VK_BACK) {
                    intent = composition.backspace();
                } else if (composing && !value.shortcut() && key == VK_SPACE) {
                    intent = state->policy.commit(true);
                } else if (composing && !value.shortcut() && (key == VK_RETURN || key == VK_TAB)) {
                    intent = state->policy.commit(false, true); forward = true;
                } else if (value.text && composition.original().size() < 128) {
                    intent = composition.character(value.text);
                } else if (composing) {
                    // Navigation, shortcuts, dead keys and long tokens retain
                    // exactly what was typed before letting Windows handle it.
                    if (!state->host.finish(cookie)) state->disabled = true;
                    if (value.text && composition.original().size() >= 128) state->literal_tail = true;
                    state->reset(); window_.hide(); return S_OK;
                } else return S_OK;
                if (state->retired || !active_) return S_OK;
                bool applied = false;
                try { applied = state->host.apply(cookie, intent); }
                catch (...) {
                    consumed = state->host.mutation_attempted(); state->disabled = true;
                    window_.hide(); return E_FAIL;
                }
                state->adapter.composition().acknowledge(intent.generation, applied);
                if (!applied) {
                    consumed = state->host.mutation_attempted();
                    state->disabled = true; state->host.finish(cookie); window_.hide(); return E_FAIL;
                }
                consumed = !forward;
                if (intent.kind == Kind::Commit || state->adapter.composition().original().empty()) {
                    state->host.finish(cookie); state->reset(); window_.hide();
                } else {
                    state->policy.refresh(mode_);
                    window_.show(context, cookie, state->adapter.candidates(), state->policy.selected(), mode_);
                }
                return S_OK;
            });
            HRESULT result = E_FAIL;
            state->editing = true;
            const auto request = context->RequestEditSession(client_, edit, TF_ES_SYNC | TF_ES_READWRITE, &result);
            const bool called = edit->called(); edit->close(); edit->Release();
            state->editing = false;
            // Denied/unrun synchronous requests pass through; no replay, no
            // deferred typing and no later callback can write using stack data.
            if (!called || FAILED(request)) {
                window_.hide(); state->retired = true; cleanup(state);
                if (unadvise(state)) states_.erase(context);
            }
            (void)result;
        } catch (...) { window_.hide(); }
        // Even allocation/cleanup failure after SetText must not replay a key
        // that the host already accepted. Keep this outside the exception path.
        *eaten = consumed ? TRUE : FALSE;
        if (consumed && key < eaten_.size()) eaten_[key] = true;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnTestKeyUp(ITfContext*, WPARAM key, LPARAM, BOOL* eaten) override {
        if (!eaten) return E_POINTER; *eaten = key < eaten_.size() && eaten_[key]; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnKeyUp(ITfContext*, WPARAM key, LPARAM, BOOL* eaten) override {
        if (!eaten) return E_POINTER; *eaten = key < eaten_.size() && eaten_[key];
        if (key < eaten_.size()) eaten_[key] = false; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) override {
        if (!eaten) return E_POINTER; *eaten = FALSE; return S_OK;
    }
private:
    std::shared_ptr<State> get(ITfContext* context) {
        auto found = states_.find(context);
        if (found != states_.end()) return found->second;
        // At most one focused composition is retained. Focus events also call
        // leave; this guard covers hosts that omit a notification.
        leave();
        if (states_.size() >= 16) throw std::runtime_error("Context cleanup failed");
        auto engine = engine_;
        auto state = std::make_shared<State>(context, [engine](const std::u16string& token, int mode) {
            return keyboard_candidates(*engine, token, mode);
        });
        auto* sink = new CompositionSink(state);
        *state->sink.put() = sink; state->host.set_sink(sink);
        if (FAILED(context->QueryInterface(IID_ITfSource, reinterpret_cast<void**>(state->source.put()))) ||
            FAILED(state->source->AdviseSink(IID_ITfTextEditSink, static_cast<ITfTextEditSink*>(this), &state->edit_sink_cookie)))
            throw std::runtime_error("Context edit notification unavailable");
        states_.emplace(context, state); return state;
    }
    void cleanup(const std::shared_ptr<State>& state) {
        if (!state->host.active()) return;
        auto* edit = new(std::nothrow) Edit([state](TfEditCookie cookie) {
            return state->host.finish(cookie) ? S_OK : E_FAIL;
        });
        if (!edit) return;
        HRESULT result = E_FAIL;
        state->context->RequestEditSession(client_, edit, TF_ES_ASYNCDONTCARE | TF_ES_READWRITE, &result);
        edit->Release();
    }
    void leave() {
        window_.hide();
        for (auto item = states_.begin(); item != states_.end();) {
            auto state = item->second; state->retired = true; cleanup(state);
            if (unadvise(state)) item = states_.erase(item); else ++item;
        }
        eaten_.fill(false);
    }
    bool unadvise(const std::shared_ptr<State>& state) {
        if (state->source && state->edit_sink_cookie != TF_INVALID_COOKIE) {
            if (FAILED(state->source->UnadviseSink(state->edit_sink_cookie))) return false;
            state->edit_sink_cookie = TF_INVALID_COOKIE;
        }
        state->source.reset(); return true;
    }
    std::atomic<ULONG> refs_{1};
    ComPtr<ITfThreadMgr> thread_;
    ComPtr<ITfKeystrokeMgr> keys_;
    ComPtr<ITfSource> source_;
    DWORD sink_cookie_ = TF_INVALID_COOKIE;
    TfClientId client_ = TF_CLIENTID_NULL;
    bool active_ = false;
    int mode_ = 0;
    std::shared_ptr<Engine> engine_;
    std::map<ITfContext*, std::shared_ptr<State>> states_;
    std::array<bool, 256> eaten_{};
    CandidateWindow window_;
};

class Factory final : public IClassFactory, private Lifetime {
public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid != IID_IUnknown && iid != IID_IClassFactory) return E_NOINTERFACE;
        *out = static_cast<IClassFactory*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { auto n = --refs_; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        try { auto* service = new TextService; auto hr = service->QueryInterface(iid, out); service->Release(); return hr; }
        catch (...) { return E_OUTOFMEMORY; }
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
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        neptype::tsf::module = instance; DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}
extern "C" HRESULT __stdcall DllGetClassObject(REFCLSID clsid, REFIID iid, void** out) {
    using namespace neptype::tsf;
    if (!out) return E_POINTER; *out = nullptr;
    if (clsid != service_id) return CLASS_E_CLASSNOTAVAILABLE;
    auto* factory = new(std::nothrow) Factory;
    if (!factory) return E_OUTOFMEMORY;
    const auto hr = factory->QueryInterface(iid, out); factory->Release(); return hr;
}
extern "C" HRESULT __stdcall DllCanUnloadNow() {
    return neptype::live_edit_sessions.load() == 0 && neptype::tsf::server_locks.load() == 0 ? S_OK : S_FALSE;
}
