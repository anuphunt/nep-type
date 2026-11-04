#pragma once
#include "windows_support.h"
#include <inputscope.h>
#include <oleauto.h>

namespace neptype::tsf {
inline bool prose_scope(InputScope scope) {
    switch (scope) {
    case IS_DEFAULT: case IS_TEXT: case IS_CHAT: case IS_SEARCH:
    case IS_PERSONALNAME_FULLNAME: case IS_PERSONALNAME_GIVENNAME:
    case IS_PERSONALNAME_MIDDLENAME: case IS_PERSONALNAME_SURNAME: return true;
    default: return false;
    }
}
inline bool disabled_compartment(ITfContext* context, REFGUID id) {
    ComPtr<ITfCompartmentMgr> manager;
    if (FAILED(context->QueryInterface(IID_ITfCompartmentMgr, reinterpret_cast<void**>(manager.put())))) return true;
    ComPtr<ITfCompartment> compartment;
    if (FAILED(manager->GetCompartment(id, compartment.put()))) return true;
    VARIANT value; VariantInit(&value);
    const auto hr = compartment->GetValue(&value);
    const bool disabled = FAILED(hr) || (value.vt == VT_I4 && value.lVal != 0);
    VariantClear(&value); return disabled;
}
// Called only inside the host edit session. No secure text is read or ranked.
inline bool allows_conversion(ITfContext* context, TfEditCookie cookie) {
    TF_STATUS status{};
    if (FAILED(context->GetStatus(&status)) || (status.dwDynamicFlags & TF_SD_READONLY) ||
        disabled_compartment(context, GUID_COMPARTMENT_KEYBOARD_DISABLED) ||
        disabled_compartment(context, GUID_COMPARTMENT_EMPTYCONTEXT)) return false;
    GUITHREADINFO gui{}; gui.cbSize = sizeof(gui);
    if (GetGUIThreadInfo(GetCurrentThreadId(), &gui) && gui.hwndFocus) {
        const auto style = GetWindowLongPtrW(gui.hwndFocus, GWL_STYLE);
        wchar_t name[64]{}; GetClassNameW(gui.hwndFocus, name, 64);
        if ((_wcsicmp(name,L"Edit") == 0 || wcsstr(name,L"RichEdit") || wcsstr(name,L"RICHEDIT")) && (style & ES_PASSWORD)) return false;
        // Console input has no dependable TSF text-store/undo contract.
        if (wcsstr(name,L"Console") || wcsstr(name,L"CASCADIA")) return false;
    }
    TF_SELECTION selected{}; ULONG count = 0;
    if (FAILED(context->GetSelection(cookie, TF_DEFAULT_SELECTION, 1, &selected, &count)) || count != 1 || !selected.range) return false;
    ComPtr<ITfRange> range(selected.range); selected.range->Release();
    ComPtr<ITfProperty> property;
    if (FAILED(context->GetProperty(GUID_PROP_INPUTSCOPE, property.put())) || !property) return false;
    VARIANT value; VariantInit(&value);
    const auto hr = property->GetValue(cookie, range.get(), &value);
    bool allowed = !FAILED(hr);
    if (allowed && value.vt == VT_UNKNOWN && value.punkVal) {
        ComPtr<ITfInputScope> scope;
        if (FAILED(value.punkVal->QueryInterface(IID_ITfInputScope, reinterpret_cast<void**>(scope.put())))) allowed = false;
        else {
            InputScope* scopes = nullptr; UINT n = 0;
            if (FAILED(scope->GetInputScopes(&scopes, &n))) allowed = false;
            else for (UINT i = 0; i < n; ++i) {
                // Only prose/name scopes are allowed. Password, URL, email,
                // numbers, telephone, PIN and private scopes pass through.
                if (!prose_scope(scopes[i])) allowed = false;
            }
            CoTaskMemFree(scopes);
        }
    } else if (allowed && value.vt != VT_EMPTY) allowed = false;
    VariantClear(&value); return allowed;
}
}
