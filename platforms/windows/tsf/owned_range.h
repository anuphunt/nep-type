#pragma once
#include "edit_bridge.h"

namespace lekha {
// Experimental owner for exactly one TSF context. Never wire to the live sink
// until selection, composition termination and lifetime behavior are verified
// on Windows. Every call must be made on the owning thread within a write edit.
class OwnedRange final : public HostEdit {
public:
    explicit OwnedRange(ITfContext* context);
    ~OwnedRange() override;
    OwnedRange(const OwnedRange&) = delete;
    OwnedRange& operator=(const OwnedRange&) = delete;
    bool owns_context(ITfContext* context) const override { return context && context == context_; }
    bool apply(TfEditCookie cookie, const Intent& intent) override;
    bool usable() const { return usable_; }
private:
    ITfContext* context_ = nullptr;
    ITfComposition* composition_ = nullptr;
    std::u16string last_text_;
    bool usable_ = true;
};
}
