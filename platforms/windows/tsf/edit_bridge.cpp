#include "edit_bridge.h"
#include "module_lifetime.h"
#include <atomic>
#include <new>
#include <thread>

namespace neptype {
struct EditBridge::State {
    explicit State(std::uint64_t session) : adapter(session) {}
    CandidateAdapter adapter;
    bool usable = true;
};

namespace {
// Synchronous edit sessions complete before request returns. Shared state and
// host ownership still prevent use-after-free if a broken host retains this.
class Session final : public ITfEditSession {
public:
    Session(std::shared_ptr<EditBridge::State> state, Intent intent, std::shared_ptr<HostEdit> host)
        : state_(std::move(state)), intent_(std::move(intent)), host_(std::move(host)) { ++live_edit_sessions; }
    ~Session() { --live_edit_sessions; }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (!IsEqualIID(iid, IID_IUnknown) && !IsEqualIID(iid, IID_ITfEditSession)) return E_NOINTERFACE;
        *out = static_cast<ITfEditSession*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
    ULONG STDMETHODCALLTYPE Release() override { auto n = --refs_; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE DoEditSession(TfEditCookie cookie) override {
        // A synchronous TSF callback must run on the requesting thread and
        // before RequestEditSession returns. Never touch the unsynchronized
        // transaction state for a late or cross-thread callback.
        if (std::this_thread::get_id() != owner_ || closed_.load()) return E_UNEXPECTED;
        if (called_ || !state_->usable || !state_->adapter.composition().matches_pending(intent_)) return E_UNEXPECTED;
        called_ = true;
        // Failure is ambiguous: host may have applied part of the edit.
        bool applied = false;
        try { applied = host_->apply(cookie, intent_); }
        catch (...) { state_->usable = false; return E_FAIL; }
        bool matched = state_->adapter.composition().acknowledge(intent_.generation, applied);
        if (!applied || !matched) { state_->usable = false; return E_FAIL; }
        return S_OK;
    }
    bool called() const { return called_; }
    void close() { closed_.store(true); }
private:
    std::atomic<ULONG> refs_{1};
    std::shared_ptr<EditBridge::State> state_;
    Intent intent_;
    std::shared_ptr<HostEdit> host_;
    bool called_ = false;
    const std::thread::id owner_ = std::this_thread::get_id();
    std::atomic<bool> closed_{false};
};
}

EditBridge::EditBridge(std::uint64_t session) : state_(std::make_shared<State>(session)) {}
CandidateAdapter& EditBridge::adapter() { return state_->adapter; }
bool EditBridge::usable() const { return state_->usable; }
void EditBridge::abandon() { state_->usable = false; }
bool EditBridge::apply(ITfContext* context, TfClientId client, const Intent& intent,
                       std::shared_ptr<HostEdit> host) {
    if (!state_->usable || !context || client == TF_CLIENTID_NULL || !host || !host->owns_context(context) ||
        (intent.kind != Kind::Mark && intent.kind != Kind::Commit) ||
        !state_->adapter.composition().matches_pending(intent)) return false;
    auto* session = new(std::nothrow) Session(state_, intent, std::move(host));
    if (!session) { state_->usable = false; return false; }
    HRESULT result = E_FAIL;
    HRESULT request = context->RequestEditSession(client, session, TF_ES_SYNC | TF_ES_READWRITE, &result);
    session->close();
    bool called = session->called();
    session->Release();
    // An accepted synchronous request must call back and return success.
    // If it did not, do not retry or advance; TSF ownership is unverified.
    if (FAILED(request) || FAILED(result) || !called) { state_->usable = false; return false; }
    return state_->usable;
}
}
