#include "owned_range.h"
#include <algorithm>
#include <limits>
#include <vector>

namespace neptype {
namespace {
template<class T> struct ComPtr {
    T* value = nullptr;
    ~ComPtr() { if (value) value->Release(); }
    T** out() { return &value; }
};
bool selection(ITfContext* context, TfEditCookie cookie, TF_SELECTION& selected) {
    ULONG fetched = 0;
    if (FAILED(context->GetSelection(cookie, TF_DEFAULT_SELECTION, 1, &selected, &fetched)) || fetched != 1 || !selected.range) return false;
    BOOL empty = FALSE;
    return !FAILED(selected.range->IsEmpty(cookie, &empty)) && empty;
}
bool valid_utf16(const std::u16string& text) {
    for (std::size_t i=0; i<text.size(); ++i) {
        auto value = text[i];
        if (value >= 0xd800 && value <= 0xdbff) {
            if (++i >= text.size() || text[i] < 0xdc00 || text[i] > 0xdfff) return false;
        } else if (value >= 0xdc00 && value <= 0xdfff) return false;
    }
    return true;
}
}
OwnedRange::OwnedRange(ITfContext* context) : context_(context) { if (context_) context_->AddRef(); else usable_ = false; }
OwnedRange::~OwnedRange() { if (composition_) composition_->Release(); if (context_) context_->Release(); }

bool OwnedRange::apply(TfEditCookie cookie, const Intent& intent) {
    static_assert(sizeof(WCHAR) == sizeof(char16_t), "TSF requires UTF-16");
    if (!usable_ || !context_ || (intent.kind != Kind::Mark && intent.kind != Kind::Commit) ||
        intent.text.size() > 4096 || intent.text.size() > static_cast<std::size_t>(std::numeric_limits<LONG>::max()) || !valid_utf16(intent.text)) return false;
    // Once any operation fails, its side effects may be unknown. Never retry.
    usable_ = false;
    TF_SELECTION selected{};
    bool has_selection = selection(context_, cookie, selected);
    ComPtr<ITfRange> selected_range; selected_range.value = selected.range;
    if (!has_selection) return false;
    if (!composition_) {
        // Never replace an existing user selection, and never commit without
        // first creating a composition whose range belongs to this service.
        if (intent.kind != Kind::Mark) return false;
        ComPtr<ITfContextComposition> manager;
        if (FAILED(context_->QueryInterface(IID_ITfContextComposition, reinterpret_cast<void**>(manager.out()))) || !manager.value) return false;
        if (FAILED(manager.value->StartComposition(cookie, selected_range.value, nullptr, &composition_)) || !composition_) return false;
    }
    ComPtr<ITfRange> range;
    if (FAILED(composition_->GetRange(range.out())) || !range.value) return false;
    LONG relation = 1;
    if (FAILED(selected_range.value->CompareStart(cookie, range.value, TF_ANCHOR_END, &relation)) || relation != 0) return false;
    // Ensure the owned span has not been externally altered before replacing it.
    ComPtr<ITfRange> read_range;
    if (FAILED(range.value->Clone(read_range.out())) || !read_range.value) return false;
    std::vector<WCHAR> actual(last_text_.size() + 1);
    ULONG read = 0;
    if (FAILED(read_range.value->GetText(cookie, 0, actual.data(), static_cast<ULONG>(actual.size()), &read)) ||
        read != last_text_.size() || !std::equal(last_text_.begin(), last_text_.end(), actual.begin())) return false;
    if (FAILED(range.value->SetText(cookie, 0, reinterpret_cast<const WCHAR*>(intent.text.data()), static_cast<LONG>(intent.text.size())))) return false;
    // Re-fetch the live composition range before moving the caret to its end.
    ComPtr<ITfRange> caret;
    if (FAILED(composition_->GetRange(caret.out())) || !caret.value || FAILED(caret.value->Collapse(cookie, TF_ANCHOR_END))) return false;
    selected.range = caret.value;
    selected.style.ase = TFAE_NONE;
    selected.style.fInterimChar = FALSE;
    if (FAILED(context_->SetSelection(cookie, 1, &selected))) return false;
    if (intent.kind == Kind::Commit) {
        if (FAILED(composition_->EndComposition(cookie))) return false;
        composition_->Release(); composition_ = nullptr;
        last_text_.clear();
    } else last_text_ = intent.text;
    usable_ = true;
    return true;
}
}
