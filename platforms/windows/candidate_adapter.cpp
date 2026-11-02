#include "candidate_adapter.h"
#include <algorithm>

namespace neptype {
namespace {
bool safe_candidate(const std::u16string& value) {
    if (value.empty() || value.size() > 512) return false;
    for (std::size_t i = 0; i < value.size(); ++i) {
        const auto ch = value[i];
        if (ch < 0x20 || (ch >= 0x7f && ch <= 0x9f) || ch == 0x2028 || ch == 0x2029 ||
            ch == 0x061c || ch == 0x200e || ch == 0x200f ||
            (ch >= 0x202a && ch <= 0x202e) || (ch >= 0x2066 && ch <= 0x2069)) return false;
        if (ch >= 0xd800 && ch <= 0xdbff) {
            if (++i >= value.size() || value[i] < 0xdc00 || value[i] > 0xdfff) return false;
        } else if (ch >= 0xdc00 && ch <= 0xdfff) return false;
    }
    return true;
}
}
std::optional<CandidateQuery> CandidateAdapter::query() const {
    if (composition_.has_pending() || composition_.original().empty()) return std::nullopt;
    return CandidateQuery{session_, composition_.generation(), composition_.original()};
}
bool CandidateAdapter::current() const {
    return accepted_ && !composition_.has_pending() && accepted_->session == session_ &&
        accepted_->generation == composition_.generation() && accepted_->original == composition_.original();
}
bool CandidateAdapter::accept(const CandidateQuery& q, const std::vector<std::u16string>& values) {
    auto active = query();
    if (!active || q.session != active->session || q.generation != active->generation || q.original != active->original) return false;
    // Bounds are important at the untrusted engine boundary. Rejected data
    // invalidates the previous list instead of exposing malformed candidates.
    if (values.size() > 32) { accepted_.reset(); candidates_.clear(); return false; }
    for (const auto& value : values) {
        if (!safe_candidate(value)) { accepted_.reset(); candidates_.clear(); return false; }
    }
    accepted_ = q;
    candidates_.clear();
    candidates_.push_back(q.original);  // always preserve the typed spelling
    for (const auto& value : values) {
        if (std::find(candidates_.begin(), candidates_.end(), value) == candidates_.end()) candidates_.push_back(value);
    }
    return true;
}
std::vector<std::u16string> CandidateAdapter::candidates() const {
    return current() ? candidates_ : std::vector<std::u16string>{};
}
Intent CandidateAdapter::choose(std::size_t index) {
    if (!current() || index >= candidates_.size()) return {Kind::Block, 0, {}, false};
    return composition_.choose(candidates_[index], accepted_->generation);
}
}
