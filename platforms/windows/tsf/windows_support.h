#pragma once
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <msctf.h>
#include <string>
#include <stdexcept>
#include "module_lifetime.h"

// Older MinGW headers omit this Windows SDK interface and the null client ID.
// Declaration matches Microsoft's msctf.h; the official SDK supplies its own.
#ifndef TF_CLIENTID_NULL
#define TF_CLIENTID_NULL ((TfClientId)0)
#endif
#if defined(__MINGW32__) && !defined(__ITfTextInputProcessorEx_INTERFACE_DEFINED__)
#define __ITfTextInputProcessorEx_INTERFACE_DEFINED__
inline constexpr IID IID_ITfTextInputProcessorEx{0x6e4e2102,0xf9cd,0x433d,{0xb4,0x96,0x30,0x3c,0xe0,0x3a,0x65,0x07}};
struct ITfTextInputProcessorEx : ITfTextInputProcessor {
    virtual HRESULT STDMETHODCALLTYPE ActivateEx(ITfThreadMgr*, TfClientId, DWORD) = 0;
};
#endif

namespace neptype::tsf {
inline constexpr GUID service_id{0xb6a68f96,0x5819,0x4b7f,{0x85,0x69,0xa1,0x15,0x90,0xd1,0x20,0x01}};
inline constexpr GUID profile_id{0xb6a68f96,0x5819,0x4b7f,{0x85,0x69,0xa1,0x15,0x90,0xd1,0x20,0x02}};
inline constexpr LANGID language = MAKELANGID(LANG_NEPALI, SUBLANG_DEFAULT);
inline HMODULE module = nullptr;
template<class T> class ComPtr {
    T* value_ = nullptr;
public:
    ComPtr() = default;
    explicit ComPtr(T* p) : value_(p) { if (p) p->AddRef(); }
    ComPtr(const ComPtr& p) : ComPtr(p.get()) {}
    ComPtr& operator=(const ComPtr& p) { if (this != &p) { reset(); value_ = p.get(); if (value_) value_->AddRef(); } return *this; }
    ~ComPtr() { reset(); }
    void reset() { if (value_) value_->Release(); value_ = nullptr; }
    T* get() const { return value_; }
    T* operator->() const { return value_; }
    explicit operator bool() const { return value_ != nullptr; }
    T** put() { reset(); return &value_; }
};
struct Lifetime {
    Lifetime() { ++live_edit_sessions; }
    ~Lifetime() { --live_edit_sessions; }
};
inline std::wstring module_path() {
    wchar_t path[32768]; const auto n = GetModuleFileNameW(module, path, 32768);
    if (!n || n >= 32768) throw std::runtime_error("Keyboard module path unavailable");
    return {path, n};
}
inline std::string utf8(const std::u16string& value) {
    if (value.empty()) return {};
    const auto n = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
        reinterpret_cast<const wchar_t*>(value.data()), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    if (n <= 0) throw std::runtime_error("Invalid UTF-16");
    std::string out(n, '\0');
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, reinterpret_cast<const wchar_t*>(value.data()),
        static_cast<int>(value.size()), out.data(), n, nullptr, nullptr);
    return out;
}
inline std::u16string utf16(const std::string& value) {
    if (value.empty()) return {};
    const auto n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), nullptr, 0);
    if (n <= 0) throw std::runtime_error("Invalid UTF-8");
    std::u16string out(n, u'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
        reinterpret_cast<wchar_t*>(out.data()), n);
    return out;
}
}
