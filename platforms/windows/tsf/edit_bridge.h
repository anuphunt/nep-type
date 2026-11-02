#pragma once
#ifdef LEKHA_TSF_TEST
#include "fake_tsf.h"
#else
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <msctf.h>
#endif
#include "candidate_adapter.h"
#include <memory>

namespace lekha {
// The implementation must apply only to the composition it owns, under the
// supplied TSF cookie. There is deliberately no concrete Windows host yet.
class HostEdit {
public:
    virtual ~HostEdit() = default;
    virtual bool owns_context(ITfContext*) const { return true; }
    virtual bool apply(TfEditCookie cookie, const Intent& intent) = 0;
};
class EditBridge {
public:
    struct State;
    explicit EditBridge(std::uint64_t session);
    CandidateAdapter& adapter();
    // Only synchronous read/write sessions are supported. A false/unknown
    // host result poisons the bridge: never consume another key or retry it.
    bool apply(ITfContext* context, TfClientId client, const Intent& intent,
               std::shared_ptr<HostEdit> host);
    bool usable() const;
    // Ownership can no longer be established after a focus or lifecycle break.
    void abandon();
private:
    std::shared_ptr<State> state_;
};
}
