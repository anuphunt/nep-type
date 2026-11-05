#include "windows_support.h"
#include <oleauto.h>
#include <iterator>
#include <vector>

namespace {
using namespace neptype::tsf;
constexpr wchar_t clsid_path[]=L"SOFTWARE\\Classes\\CLSID\\{B6A68F96-5819-4B7F-8569-A11590D12001}";
struct Failure { HRESULT value; };
void check(HRESULT value) { if(FAILED(value)) throw Failure{value}; }
bool contains(IEnumGUID* values,REFGUID wanted) {
    GUID value{}; ULONG count=0;
    while(values->Next(1,&value,&count)==S_OK && count==1) if(value==wanted) return true;
    return false;
}
bool service_exists(ITfInputProcessorProfiles* profiles) {
    ComPtr<IEnumGUID> values; check(profiles->EnumInputProcessorInfo(values.put()));
    return contains(values.get(),service_id);
}
bool category_exists(ITfCategoryMgr* manager) {
    ComPtr<IEnumGUID> values; check(manager->EnumItemsInCategory(GUID_TFCAT_TIP_KEYBOARD,values.put()));
    return contains(values.get(),service_id);
}
struct Value { bool exists=false; DWORD type=0; std::vector<BYTE> bytes; };
Value read_value(const wchar_t* path,const wchar_t* name) {
    HKEY key=nullptr;
    auto error=RegOpenKeyExW(HKEY_LOCAL_MACHINE,path,0,KEY_READ|KEY_WOW64_64KEY,&key);
    if(error==ERROR_FILE_NOT_FOUND) return {};
    check(HRESULT_FROM_WIN32(error));
    Value value; DWORD size=0;
    error=RegQueryValueExW(key,name,nullptr,&value.type,nullptr,&size);
    if(error==ERROR_FILE_NOT_FOUND) { RegCloseKey(key); return value; }
    if(error!=ERROR_SUCCESS || size>131072) { RegCloseKey(key); throw Failure{E_FAIL}; }
    value.bytes.resize(size); value.exists=true;
    error=RegQueryValueExW(key,name,nullptr,&value.type,value.bytes.data(),&size);
    RegCloseKey(key); check(HRESULT_FROM_WIN32(error)); return value;
}
void restore_value(const std::wstring& path,const wchar_t* name,const Value& value) {
    HKEY key=nullptr;
    if(RegCreateKeyExW(HKEY_LOCAL_MACHINE,path.c_str(),0,nullptr,0,KEY_WRITE|KEY_WOW64_64KEY,nullptr,&key,nullptr)!=ERROR_SUCCESS) return;
    if(value.exists) RegSetValueExW(key,name,0,value.type,value.bytes.data(),static_cast<DWORD>(value.bytes.size()));
    else RegDeleteValueW(key,name);
    RegCloseKey(key);
}
struct RegistryChange {
    std::wstring server=std::wstring(clsid_path)+L"\\InprocServer32";
    Value title=read_value(clsid_path,nullptr), path=read_value(server.c_str(),nullptr), threading=read_value(server.c_str(),L"ThreadingModel");
    bool existed=false,changed=false,committed=false;
    RegistryChange() {
        HKEY key=nullptr;
        const auto error=RegOpenKeyExW(HKEY_LOCAL_MACHINE,clsid_path,0,KEY_READ|KEY_WOW64_64KEY,&key);
        if(error==ERROR_SUCCESS) { existed=true; RegCloseKey(key); }
        else if(error!=ERROR_FILE_NOT_FOUND) check(HRESULT_FROM_WIN32(error));
    }
    void set(const std::wstring& target,const wchar_t* name,const std::wstring& value) {
        changed=true; HKEY key=nullptr;
        check(HRESULT_FROM_WIN32(RegCreateKeyExW(HKEY_LOCAL_MACHINE,target.c_str(),0,nullptr,0,KEY_WRITE|KEY_WOW64_64KEY,nullptr,&key,nullptr)));
        const auto error=RegSetValueExW(key,name,0,REG_SZ,reinterpret_cast<const BYTE*>(value.c_str()),static_cast<DWORD>((value.size()+1)*sizeof(wchar_t)));
        RegCloseKey(key); check(HRESULT_FROM_WIN32(error));
    }
    ~RegistryChange() {
        if(!changed || committed) return;
        if(!existed) RegDeleteTreeW(HKEY_LOCAL_MACHINE,clsid_path);
        else { restore_value(clsid_path,nullptr,title); restore_value(server,nullptr,path); restore_value(server,L"ThreadingModel",threading); }
    }
};
HRESULT remove_registration() {
    try {
        ComPtr<ITfInputProcessorProfiles> profiles; ComPtr<ITfCategoryMgr> categories;
        check(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())));
        check(CoCreateInstance(CLSID_TF_CategoryMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfCategoryMgr,reinterpret_cast<void**>(categories.put())));
        if(category_exists(categories.get())) check(categories->UnregisterCategory(service_id,GUID_TFCAT_TIP_KEYBOARD,service_id));
        if(service_exists(profiles.get())) check(profiles->Unregister(service_id));
        const auto error=RegDeleteTreeW(HKEY_LOCAL_MACHINE,clsid_path);
        if(error!=ERROR_SUCCESS && error!=ERROR_FILE_NOT_FOUND) check(HRESULT_FROM_WIN32(error));
        return S_OK;
    } catch(const Failure& error) { return error.value; } catch(...) { return E_FAIL; }
}
}
extern "C" HRESULT __stdcall DllRegisterServer() {
    using namespace neptype::tsf;
    const auto initialized=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
    if(FAILED(initialized) && initialized!=RPC_E_CHANGED_MODE) return initialized;
    HRESULT result=E_FAIL;
    ComPtr<ITfInputProcessorProfiles> profiles; ComPtr<ITfCategoryMgr> categories;
    bool added_service=false,added_profile=false,added_category=false;
    try {
        RegistryChange registry; const auto path=module_path();
        registry.set(clsid_path,nullptr,L"NepType Nepali Keyboard");
        registry.set(registry.server,L"ThreadingModel",L"Apartment");
        if(!registry.path.exists) registry.set(registry.server,nullptr,path);
        check(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())));
        check(CoCreateInstance(CLSID_TF_CategoryMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfCategoryMgr,reinterpret_cast<void**>(categories.put())));
        if(!service_exists(profiles.get())) { check(profiles->Register(service_id)); added_service=true; }
        BSTR description=nullptr;
        const auto found=profiles->GetLanguageProfileDescription(service_id,language,profile_id,&description);
        const bool present=found==S_OK && description; SysFreeString(description);
        if(!present) {
            if(FAILED(found) && found!=E_FAIL && found!=E_INVALIDARG) check(found);
            constexpr wchar_t name[]=L"NepType Nepali Keyboard";
            check(profiles->AddLanguageProfile(service_id,language,profile_id,name,static_cast<ULONG>(std::size(name)-1),path.c_str(),static_cast<ULONG>(path.size()),0));
            added_profile=true;
        }
        if(!category_exists(categories.get())) { check(categories->RegisterCategory(service_id,GUID_TFCAT_TIP_KEYBOARD,service_id)); added_category=true; }
        // Keep existing profiles and every user's enabled state. During an
        // upgrade the old COM path remains until all metadata is ready. Old
        // version folders are retained for loaded modules and icon metadata.
        registry.set(registry.server,nullptr,path);
        registry.committed=true; result=S_OK;
    } catch(const Failure& error) { result=error.value; } catch(...) { result=E_FAIL; }
    if(FAILED(result)) {
        if(added_category && categories) categories->UnregisterCategory(service_id,GUID_TFCAT_TIP_KEYBOARD,service_id);
        if(added_profile && profiles) profiles->RemoveLanguageProfile(service_id,language,profile_id);
        if(added_service && profiles) profiles->Unregister(service_id);
    }
    categories.reset(); profiles.reset();
    if(SUCCEEDED(initialized)) CoUninitialize();
    return result;
}
extern "C" HRESULT __stdcall DllUnregisterServer() {
    const auto initialized=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
    if(FAILED(initialized) && initialized!=RPC_E_CHANGED_MODE) return initialized;
    const auto result=remove_registration();
    if(SUCCEEDED(initialized)) CoUninitialize();
    return result;
}
