#pragma once
#include <cstdint>
#include <string>

namespace neptype {
// The displayed row belongs to one completed document request and selection.
// Text equality alone cannot detect a caret move within an unchanged document.
struct PadCandidateView {
    uint64_t generation = 0;
    std::wstring source;
    uint32_t selectionStart = 0, selectionEnd = 0;
    int32_t tokenStart = -1, tokenLength = 0;
    bool ready = false;

    bool matches(uint64_t currentGeneration, const std::wstring& text,
                 uint32_t start, uint32_t end) const {
        return ready && generation == currentGeneration && source == text
            && start == selectionStart && end == selectionEnd
            && tokenStart >= 0 && tokenLength > 0
            && start >= static_cast<uint32_t>(tokenStart)
            && end >= start
            && static_cast<uint64_t>(end) <= static_cast<uint64_t>(tokenStart) + tokenLength;
    }
};
}
