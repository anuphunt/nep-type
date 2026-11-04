#pragma once
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace neptype {
// Host-independent edit intents. A future TSF adapter must apply each intent
// in an edit session against the original composition, then acknowledge it.
// This class does not invoke TSF and performs no IO or text transformation.
enum class Kind { Pass, Block, Mark, Commit };
struct Intent {
    Kind kind = Kind::Pass;
    std::uint64_t generation = 0;
    std::u16string text;
    // Host must deliver the triggering event only after a successful commit.
    bool forward_after_commit = false;
};

class Composition {
public:
    Intent character(char16_t c);
    Intent backspace();
    Intent boundary(char16_t c);
    Intent interrupt();
    Intent choose(std::u16string candidate, std::uint64_t candidate_generation,
                  std::u16string suffix = {}, bool forward = false);
    bool acknowledge(std::uint64_t generation, bool applied);
    const std::u16string& original() const { return original_; }
    bool has_pending() const { return pending_.has_value(); }
    bool matches_pending(const Intent& intent) const;
    std::uint64_t generation() const { return generation_; }
private:
    struct Pending { Intent intent; std::u16string next; };
    Intent mark(std::u16string next);
    Intent commit(std::u16string text, bool forward);
    Intent queue(Kind kind, std::u16string text, std::u16string next, bool forward);
    std::u16string original_;
    std::uint64_t generation_ = 0;
    std::optional<Pending> pending_;
};
}
