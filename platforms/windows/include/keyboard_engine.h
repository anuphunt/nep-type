#pragma once
#include "../../../shared/cpp/engine.hpp"
#include <algorithm>

namespace neptype {
inline std::u16string keyboard_utf16(const std::string& input) {
    std::u16string out;
    for (std::size_t i = 0; i < input.size();) {
        auto byte = static_cast<unsigned char>(input[i++]);
        char32_t point = byte; unsigned extra = 0; char32_t minimum = 0;
        if (byte >= 0xc2 && byte <= 0xdf) { point = byte & 0x1f; extra = 1; minimum = 0x80; }
        else if (byte >= 0xe0 && byte <= 0xef) { point = byte & 0x0f; extra = 2; minimum = 0x800; }
        else if (byte >= 0xf0 && byte <= 0xf4) { point = byte & 7; extra = 3; minimum = 0x10000; }
        else if (byte >= 0x80) throw std::runtime_error("Invalid UTF-8");
        while (extra--) {
            if (i == input.size()) throw std::runtime_error("Truncated UTF-8");
            auto next = static_cast<unsigned char>(input[i++]);
            if ((next & 0xc0) != 0x80) throw std::runtime_error("Invalid UTF-8 continuation");
            point = (point << 6) | (next & 0x3f);
        }
        if (point < minimum || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff)) throw std::runtime_error("Invalid Unicode scalar");
        if (point <= 0xffff) out.push_back(static_cast<char16_t>(point));
        else { point -= 0x10000; out.push_back(static_cast<char16_t>(0xd800 + (point >> 10))); out.push_back(static_cast<char16_t>(0xdc00 + (point & 0x3ff))); }
    }
    return out;
}
inline std::vector<std::u16string> keyboard_candidates(Engine& engine, const std::u16string& token, int mode) {
    if (token.size() > 128 || std::any_of(token.begin(), token.end(), [](char16_t ch) { return ch < 33 || ch > 126; })) throw std::runtime_error("Invalid keyboard token");
    std::string source;
    source.reserve(token.size());
    for (auto ch : token) source.push_back(static_cast<char>(ch)); // validated ASCII above
    // The ABI's document handle intentionally remembers pad choices. Keyboard
    // candidate enumeration must not make the last enumerated choice become
    // the next word's default, even for identical consecutive words.
    engine.document("", mode, 0);
    const auto document = engine.document(source, mode, static_cast<int32_t>(token.size()));
    std::vector<std::u16string> values;
    if (!document.output.empty()) values.push_back(keyboard_utf16(document.output));
    for (const auto& candidate : document.candidates) {
        if (values.size() >= 3) break;
        const auto chosen = engine.document(source, mode, static_cast<int32_t>(token.size()), candidate.c_str());
        auto text = keyboard_utf16(chosen.output);
        if (!text.empty() && std::find(values.begin(), values.end(), text) == values.end()) values.push_back(std::move(text));
    }
    engine.document("", mode, 0);
    return values;
}
}
