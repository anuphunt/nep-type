#include "composition.h"
#include <utility>

namespace neptype {
bool Composition::matches_pending(const Intent& intent) const {
    if (!pending_) return false;
    const auto& expected = pending_->intent;
    return intent.kind == expected.kind && intent.generation == expected.generation &&
           intent.text == expected.text && intent.forward_after_commit == expected.forward_after_commit;
}
Intent Composition::queue(Kind kind, std::u16string text, std::u16string next, bool forward) {
    if (pending_) return {Kind::Block, 0, {}, false};
    Intent intent{kind, ++generation_, std::move(text), forward};
    pending_ = Pending{intent, std::move(next)};
    return intent;
}
Intent Composition::mark(std::u16string next) {
    auto displayed = next;
    return queue(Kind::Mark, std::move(displayed), std::move(next), false);
}
Intent Composition::commit(std::u16string text, bool forward) {
    return queue(Kind::Commit, std::move(text), {}, forward);
}
Intent Composition::character(char16_t c) {
    if (pending_) return {Kind::Block, 0, {}, false};
    // Keep punctuation with the token to avoid committing a partial URL.
    // Non-ASCII and long input fall through only after the current token is
    // safely committed; do not swallow or reinterpret those events.
    if (c < 33 || c > 126 || original_.size() >= 128) return interrupt();
    auto next = original_;
    next.push_back(c);
    return mark(std::move(next));
}
Intent Composition::backspace() {
    if (pending_) return {Kind::Block, 0, {}, false};
    if (original_.empty()) return {Kind::Pass, 0, {}, false};
    auto next = original_;
    next.pop_back(); // original contains printable ASCII only
    return mark(std::move(next));
}
Intent Composition::boundary(char16_t c) {
    if (pending_) return {Kind::Block, 0, {}, false};
    if (original_.empty()) return {Kind::Pass, 0, {}, false};
    if (c != u' ' && c != u'\n' && c != u'\t') return interrupt();
    auto text = original_;
    text.push_back(c);
    return commit(std::move(text), false);
}
Intent Composition::interrupt() {
    if (pending_) return {Kind::Block, 0, {}, false};
    if (original_.empty()) return {Kind::Pass, 0, {}, false};
    return commit(original_, true);
}
Intent Composition::choose(std::u16string candidate, std::uint64_t candidate_generation) {
    if (pending_) return {Kind::Block, 0, {}, false};
    if (original_.empty() || candidate.empty() || candidate_generation != generation_) return {Kind::Block, 0, {}, false};
    // Explicit choice only. Candidate origin must be verified by future bridge.
    return commit(std::move(candidate), false);
}
bool Composition::acknowledge(std::uint64_t generation, bool applied) {
    if (!pending_ || pending_->intent.generation != generation) return false;
    if (applied) original_ = std::move(pending_->next);
    else ++generation_; // Invalidate responses for a rejected host edit.
    pending_.reset();
    return true;
}
}
