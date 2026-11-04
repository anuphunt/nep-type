#pragma once
#include "edit_bridge.h"

namespace neptype {
// Owns exactly one TSF context. Every mutation must run on the owning thread
// within a granted write edit. Native-host acceptance remains a release gate.
class OwnedRange final : public HostEdit {
public:
    explicit OwnedRange(ITfContext* context);
    ~OwnedRange() override;
    OwnedRange(const OwnedRange&) = delete;
    OwnedRange& operator=(const OwnedRange&) = delete;
    bool owns_context(ITfContext* context) const override { return context && context == context_; }
    bool apply(TfEditCookie cookie, const Intent& intent) override;
    bool usable() const { return usable_; }
    bool active() const { return composition_ != nullptr; }
    bool mutation_attempted() const { return mutation_attempted_; }
    bool can_edit(TfEditCookie cookie) const;
    bool finish(TfEditCookie cookie);
#ifndef NEPTYPE_TSF_TEST
    void set_sink(ITfCompositionSink* sink) { sink_ = sink; }
#endif
    void terminated(ITfComposition* composition);
private:
    ITfContext* context_ = nullptr;
    ITfComposition* composition_ = nullptr;
    std::u16string last_text_;
    bool usable_ = true;
    bool mutation_attempted_ = false;
#ifndef NEPTYPE_TSF_TEST
    ITfCompositionSink* sink_ = nullptr; // weak; TSF retains it during composition
#endif
};
}
