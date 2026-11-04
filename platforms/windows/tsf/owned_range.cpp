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
bool selection(ITfContext* context, TfEditCookie cookie, TF_SELECTION& selected, bool empty_only = true) {
    ULONG fetched = 0;
    if (FAILED(context->GetSelection(cookie, TF_DEFAULT_SELECTION, 1, &selected, &fetched)) || fetched != 1 || !selected.range) return false;
    BOOL empty = FALSE;
    return !FAILED(selected.range->IsEmpty(cookie, &empty)) && (!empty_only || empty);
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

bool OwnedRange::can_edit(TfEditCookie cookie) const {
    if (!usable_ || !context_) return false;
    TF_SELECTION selected{};
    const bool ok = selection(context_, cookie, selected, composition_ != nullptr);
    ComPtr<ITfRange> caret; caret.value = selected.range;
    if (!ok) return false;
    if (!composition_) return true; // ordinary typing may replace a selection
    ComPtr<ITfRange> range;
    if (FAILED(composition_->GetRange(range.out())) || !range.value) return false;
    LONG relation = 1;
    if (FAILED(caret.value->CompareStart(cookie, range.value, TF_ANCHOR_END, &relation)) || relation != 0) return false;
    std::vector<WCHAR> text(last_text_.size() + 1);
    ULONG read = 0;
    return !FAILED(range.value->GetText(cookie, 0, text.data(), static_cast<ULONG>(text.size()), &read)) &&
        read == last_text_.size() && std::equal(last_text_.begin(), last_text_.end(), text.begin());
}
bool OwnedRange::finish(TfEditCookie cookie) {
    if (!composition_) return true;
    auto* old = composition_;
    old->AddRef(); // termination can synchronously call the composition sink
    const auto hr = old->EndComposition(cookie);
    if (!FAILED(hr) && composition_ == old) {
        composition_->Release(); composition_ = nullptr; last_text_.clear();
    }
    old->Release();
    if (FAILED(hr)) usable_ = false;
    return !FAILED(hr);
}
void OwnedRange::terminated(ITfComposition* composition) {
    if (composition_ == composition) {
        composition_->Release(); composition_ = nullptr; last_text_.clear();
    }
}

bool OwnedRange::apply(TfEditCookie cookie, const Intent& intent) {
    mutation_attempted_ = false;
    static_assert(sizeof(WCHAR) == sizeof(char16_t), "TSF requires UTF-16");
    if (!usable_ || !context_ || (intent.kind != Kind::Mark && intent.kind != Kind::Commit) ||
        intent.text.size() > 4096 || intent.text.size() > static_cast<std::size_t>(std::numeric_limits<LONG>::max()) || !valid_utf16(intent.text)) return false;
    // Once any operation fails, its side effects may be unknown. Never retry.
    if (!can_edit(cookie)) return false;
    usable_ = false;
    TF_SELECTION selected{};
    bool has_selection = selection(context_, cookie, selected, composition_ != nullptr);
    ComPtr<ITfRange> selected_range; selected_range.value = selected.range;
    if (!has_selection) return false;
    if (!composition_) {
        // A new token replaces the user's selection as normal text input does.
        if (intent.kind != Kind::Mark) return false;
        ComPtr<ITfContextComposition> manager;
        if (FAILED(context_->QueryInterface(IID_ITfContextComposition, reinterpret_cast<void**>(manager.out()))) || !manager.value) return false;
#ifdef NEPTYPE_TSF_TEST
        if (FAILED(manager.value->StartComposition(cookie, selected_range.value, nullptr, &composition_)) || !composition_) return false;
#else
        if (FAILED(manager.value->StartComposition(cookie, selected_range.value, sink_, &composition_)) || !composition_) return false;
#endif
        // The first range may cover selected text; subsequent ranges must match
        // exactly what we wrote. Snapshot it before the first replacement.
        ComPtr<ITfRange> initial;
        if (FAILED(composition_->GetRange(initial.out())) || !initial.value) return false;
        std::vector<WCHAR> text(4097); ULONG length = 0;
        if (FAILED(initial.value->GetText(cookie, 0, text.data(), static_cast<ULONG>(text.size()), &length)) || length > 4096) return false;
        last_text_.assign(text.begin(), text.begin() + length);
    }
    ComPtr<ITfRange> range;
    if (FAILED(composition_->GetRange(range.out())) || !range.value) return false;
    // can_edit already checked the existing caret. An initial selection may
    // span the complete new composition rather than sit at its end.
    // Ensure the owned span has not been externally altered before replacing it.
    ComPtr<ITfRange> read_range;
    if (FAILED(range.value->Clone(read_range.out())) || !read_range.value) return false;
    std::vector<WCHAR> actual(last_text_.size() + 1);
    ULONG read = 0;
    if (FAILED(read_range.value->GetText(cookie, 0, actual.data(), static_cast<ULONG>(actual.size()), &read)) ||
        read != last_text_.size() || !std::equal(last_text_.begin(), last_text_.end(), actual.begin())) return false;
    // Allocate all owned strings before the host mutation. A later allocation
    // exception must not make a successfully inserted key look unconsumed.
    std::u16string next_text = intent.text;
    mutation_attempted_ = true;
    if (FAILED(range.value->SetText(cookie, 0, reinterpret_cast<const WCHAR*>(intent.text.data()), static_cast<LONG>(intent.text.size())))) return false;
    // Re-fetch the live composition range before moving the caret to its end.
    ComPtr<ITfRange> caret;
    if (FAILED(composition_->GetRange(caret.out())) || !caret.value || FAILED(caret.value->Collapse(cookie, TF_ANCHOR_END))) return false;
    selected.range = caret.value;
    selected.style.ase = TF_AE_NONE;
    selected.style.fInterimChar = FALSE;
    if (FAILED(context_->SetSelection(cookie, 1, &selected))) return false;
    if (intent.kind == Kind::Commit) {
        if (!finish(cookie)) return false;
    } else last_text_.swap(next_text);
    usable_ = true;
    return true;
}
}
