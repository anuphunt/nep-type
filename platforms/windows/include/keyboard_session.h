#pragma once
#include "candidate_adapter.h"
#include <algorithm>
#include <functional>

namespace neptype {
// The live TSF service and portable tests use the same transaction policy.
// Ranking belongs to the shared engine. No host text or clipboard is read here.
class KeyboardSession {
public:
    using Convert = std::function<std::vector<std::u16string>(const std::u16string&, int)>;
    KeyboardSession(CandidateAdapter& adapter, Convert convert)
        : adapter_(adapter), convert_(std::move(convert)) {}
    bool refresh(int mode) {
        selected_ = 0;
        auto query = adapter_.query();
        if (!query) return true;
        try {
            auto ranked = convert_(query->original, mode);
            if (!adapter_.accept(*query, ranked)) return adapter_.accept(*query, {});
            auto choices = adapter_.candidates();
            if (!ranked.empty()) {
                auto found = std::find(choices.begin(), choices.end(), ranked.front());
                if (found != choices.end()) selected_ = static_cast<std::size_t>(found - choices.begin());
            }
            return true;
        } catch (...) {
            // Conversion failure keeps the exact Roman token as the only choice.
            return adapter_.accept(*query, {});
        }
    }
    Intent commit(bool space = false, bool forward = false, bool literal = false) {
        return adapter_.choose(literal ? 0 : selected_, space ? u" " : u"", forward);
    }
    Intent choose(std::size_t index) { return adapter_.choose(index); }
    void cycle(int direction) {
        const auto count = adapter_.candidates().size();
        if (count) selected_ = (selected_ + count + direction) % count;
    }
    std::size_t selected() const { return selected_; }
private:
    CandidateAdapter& adapter_;
    Convert convert_;
    std::size_t selected_ = 0;
};
}
