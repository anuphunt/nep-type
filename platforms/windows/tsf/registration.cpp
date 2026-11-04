#include "windows_support.h"
#include <iterator>

namespace {
using namespace neptype::tsf;
constexpr wchar_t clsid_path[] = L"SOFTWARE\\Classes\\CLSID\\{B6A68F96-5819-4B7F-8569-A11590D12001}";
HRESULT set_value(HKEY key, const wchar_t* name, const std::wstring& value) {
    const auto error = RegSetValueExW(key, name, 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()),
                                     static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    return HRESULT_FROM_WIN32(error);
}
HRESULT remove_registration() {
    ComPtr<ITfCategoryMgr> categories;
    HRESULT result = S_OK;
    if (SUCCEEDED(CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
        IID_ITfCategoryMgr, reinterpret_cast<void**>(categories.put())))) {
        result = categories->UnregisterCategory(service_id, GUID_TFCAT_TIP_KEYBOARD, service_id);
    }
    ComPtr<ITfInputProcessorProfiles> profiles;
    auto hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
        IID_ITfInputProcessorProfiles, reinterpret_cast<void**>(profiles.put()));
    if (SUCCEEDED(hr)) {
        profiles->RemoveLanguageProfile(service_id, language, profile_id);
        hr = profiles->Unregister(service_id);
    }
    if (FAILED(hr)) result = hr;
    const auto error = RegDeleteTreeW(HKEY_LOCAL_MACHINE, clsid_path);
    if (error != ERROR_SUCCESS && error != ERROR_FILE_NOT_FOUND) result = HRESULT_FROM_WIN32(error);
    return result;
}
}
extern "C" HRESULT __stdcall DllRegisterServer() {
    using namespace neptype::tsf;
    const auto initialized = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(initialized) && initialized != RPC_E_CHANGED_MODE) return initialized;
    HRESULT result = E_FAIL;
    try {
        const auto path = module_path();
        HKEY key = nullptr;
        auto error = RegCreateKeyExW(HKEY_LOCAL_MACHINE, clsid_path, 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr);
        result = HRESULT_FROM_WIN32(error);
        if (SUCCEEDED(result)) {
            result = set_value(key, nullptr, L"NepType Nepali Keyboard"); RegCloseKey(key);
        }
        if (SUCCEEDED(result)) {
            std::wstring server = std::wstring(clsid_path) + L"\\InprocServer32";
            error = RegCreateKeyExW(HKEY_LOCAL_MACHINE, server.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr);
            result = HRESULT_FROM_WIN32(error);
            if (SUCCEEDED(result)) {
                result = set_value(key, nullptr, path);
                if (SUCCEEDED(result)) result = set_value(key, L"ThreadingModel", L"Apartment");
                RegCloseKey(key);
            }
        }
        ComPtr<ITfInputProcessorProfiles> profiles;
        if (SUCCEEDED(result)) result = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
            IID_ITfInputProcessorProfiles, reinterpret_cast<void**>(profiles.put()));
        if (SUCCEEDED(result)) result = profiles->Register(service_id);
        constexpr wchar_t name[] = L"NepType Nepali Keyboard";
        if (SUCCEEDED(result)) result = profiles->AddLanguageProfile(service_id, language, profile_id,
            name, static_cast<ULONG>(std::size(name) - 1), path.c_str(), static_cast<ULONG>(path.size()), 0);
        // Deliberately do not change the user's default language or input method.
        ComPtr<ITfCategoryMgr> categories;
        if (SUCCEEDED(result)) result = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
            IID_ITfCategoryMgr, reinterpret_cast<void**>(categories.put()));
        if (SUCCEEDED(result)) result = categories->RegisterCategory(service_id, GUID_TFCAT_TIP_KEYBOARD, service_id);
        if (FAILED(result)) remove_registration();
    } catch (...) { result = E_FAIL; remove_registration(); }
    if (SUCCEEDED(initialized)) CoUninitialize();
    return result;
}
extern "C" HRESULT __stdcall DllUnregisterServer() {
    const auto initialized = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(initialized) && initialized != RPC_E_CHANGED_MODE) return initialized;
    const auto hr = remove_registration();
    if (SUCCEEDED(initialized)) CoUninitialize();
    return hr;
}
