#pragma once
#include "composition.h"
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace neptype {
// A request/response boundary, not a transport. Caller owns the worker thread,
// validates the engine process and delivers responses to the owning thread.
struct CandidateQuery {
    std::uint64_t session;
    std::uint64_t generation;
    std::u16string original;
};
class CandidateAdapter {
public:
    explicit CandidateAdapter(std::uint64_t session) : session_(session) {}
    Composition& composition() { return composition_; }
    std::optional<CandidateQuery> query() const;
    bool accept(const CandidateQuery& query, const std::vector<std::u16string>& candidates);
    // No edit occurs until the host applies and acknowledges the returned intent.
    Intent choose(std::size_t index, std::u16string suffix = {}, bool forward = false);
    std::vector<std::u16string> candidates() const;
private:
    bool current() const;
    std::uint64_t session_;
    Composition composition_;
    std::optional<CandidateQuery> accepted_;
    std::vector<std::u16string> candidates_;
};
}
