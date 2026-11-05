#include "windows_support.h"
#include "keyboard_payload.h"
#include "setup_transaction.h"
#include <shlobj.h>
#include <bcrypt.h>
#include <aclapi.h>
#include <sddl.h>
#include <algorithm>
#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <cwctype>
#include <vector>

extern "C" HRESULT __stdcall DllUnregisterServer();
namespace fs=std::filesystem;
using namespace neptype::tsf;
using namespace neptype::setup;
namespace {
constexpr wchar_t registration_key[]=L"SOFTWARE\\Classes\\CLSID\\{B6A68F96-5819-4B7F-8569-A11590D12001}\\InprocServer32";
void require(bool value,const char* message) { if(!value) throw std::runtime_error(message); }
void check(HRESULT value,const char* message) {
    if(FAILED(value)) { std::ostringstream text; text<<message<<" (HRESULT 0x"<<std::hex<<static_cast<unsigned long>(value)<<")"; throw std::runtime_error(text.str()); }
}
struct Handle {
    HANDLE value=INVALID_HANDLE_VALUE;
    explicit Handle(HANDLE handle):value(handle) {}
    ~Handle() { if(value!=INVALID_HANDLE_VALUE && value) CloseHandle(value); }
};
struct Runtime {
    Runtime() { check(CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED),"COM initialization failed"); }
    ~Runtime() { CoUninitialize(); }
};
struct Mutex {
    Handle handle{CreateMutexW(nullptr,FALSE,L"Global\\NepType.Keyboard.Setup")};
    Mutex() { require(handle.value && handle.value!=INVALID_HANDLE_VALUE,"Keyboard setup is unavailable"); const auto result=WaitForSingleObject(handle.value,0); require(result==WAIT_OBJECT_0 || result==WAIT_ABANDONED,"Another keyboard setup is running"); }
    ~Mutex() { ReleaseMutex(handle.value); }
};
std::wstring lower(std::wstring value) { std::transform(value.begin(),value.end(),value.begin(),[](wchar_t ch){return static_cast<wchar_t>(std::towlower(ch));}); return value; }
std::wstring setup_path(const fs::path& path) { return lower(fs::weakly_canonical(fs::absolute(path)).wstring()); }
bool below(const std::wstring& child,const std::wstring& parent) { return child.size()>parent.size() && child.compare(0,parent.size(),parent)==0 && child[parent.size()]==L'\\'; }
fs::path program_files() {
    PWSTR path=nullptr; check(SHGetKnownFolderPath(FOLDERID_ProgramFiles,KF_FLAG_DEFAULT,nullptr,&path),"Program Files is unavailable");
    fs::path result(path); CoTaskMemFree(path); return result;
}
void architecture() { SYSTEM_INFO info{}; GetNativeSystemInfo(&info); require(info.wProcessorArchitecture==PROCESSOR_ARCHITECTURE_AMD64 && sizeof(void*)==8,"This installer requires native Windows x64; ARM64 needs a separate keyboard build"); }
void administrator() {
    SID_IDENTIFIER_AUTHORITY authority=SECURITY_NT_AUTHORITY; PSID group=nullptr;
    require(AllocateAndInitializeSid(&authority,2,SECURITY_BUILTIN_DOMAIN_RID,DOMAIN_ALIAS_RID_ADMINS,0,0,0,0,0,0,&group)!=FALSE,"Administrator check failed");
    BOOL member=FALSE; const bool ok=CheckTokenMembership(nullptr,group,&member)!=FALSE; FreeSid(group);
    require(ok && member,"Run the installer or keyboard setup as Administrator");
}
bool trusted_system_sid(PSID sid) {
    if(IsWellKnownSid(sid,WinLocalSystemSid) || IsWellKnownSid(sid,WinBuiltinAdministratorsSid)) return true;
    PSID installer=nullptr;
    require(ConvertStringSidToSidW(L"S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464",&installer)!=FALSE,"Installer identity check failed");
    const bool trusted=EqualSid(sid,installer)!=FALSE; LocalFree(installer); return trusted;
}
void protected_acl(const fs::path& path) {
    PACL acl=nullptr; PSID owner=nullptr; PSECURITY_DESCRIPTOR descriptor=nullptr;
    require(GetNamedSecurityInfoW(path.c_str(),SE_FILE_OBJECT,DACL_SECURITY_INFORMATION|OWNER_SECURITY_INFORMATION,&owner,nullptr,&acl,nullptr,&descriptor)==ERROR_SUCCESS,"Keyboard folder permissions could not be checked");
    bool safe=acl && owner && trusted_system_sid(owner);
    for(DWORD i=0;safe && i<acl->AceCount;++i) {
        void* raw=nullptr; if(!GetAce(acl,i,&raw)) { safe=false; break; }
        const auto* header=static_cast<ACE_HEADER*>(raw);
        if(header->AceType==ACCESS_DENIED_ACE_TYPE || header->AceType==ACCESS_DENIED_OBJECT_ACE_TYPE || header->AceType==ACCESS_DENIED_CALLBACK_ACE_TYPE || header->AceType==ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE) continue;
        // Unrecognized granting ACEs cannot establish a protected executable path.
        if(header->AceType!=ACCESS_ALLOWED_ACE_TYPE) { safe=false; break; }
        const auto* ace=static_cast<ACCESS_ALLOWED_ACE*>(raw); const auto sid=reinterpret_cast<PSID>(const_cast<DWORD*>(&ace->SidStart));
        const DWORD writes=GENERIC_ALL|GENERIC_WRITE|FILE_WRITE_DATA|FILE_APPEND_DATA|FILE_WRITE_EA|FILE_WRITE_ATTRIBUTES|DELETE|WRITE_DAC|WRITE_OWNER;
        const bool creator_template=IsWellKnownSid(sid,WinCreatorOwnerSid) && (header->AceFlags&INHERIT_ONLY_ACE);
        if((ace->Mask&writes) && !trusted_system_sid(sid) && !creator_template) safe=false;
    }
    LocalFree(descriptor); require(safe,"Keyboard folder allows non-administrative modification of executable files");
}
void protected_directory(const fs::path& path) {
    const auto base=setup_path(program_files());
    const auto resolved=setup_path(path);
    require(below(resolved,base),"Keyboard files must be in a protected Program Files folder");
    auto inspect=fs::path(resolved);
    while(!fs::exists(inspect) && inspect.has_parent_path() && inspect!=inspect.parent_path()) inspect=inspect.parent_path();
    // A writable parent could rename/replace even a protected child directory.
    for(;;) {
        protected_acl(inspect);
        if(setup_path(inspect)==base) break;
        require(inspect.has_parent_path() && below(setup_path(inspect),base),"Keyboard folder ancestry is invalid");
        inspect=inspect.parent_path();
    }
}

std::wstring digest(const fs::path& path) {
    BCRYPT_ALG_HANDLE algorithm=nullptr; BCRYPT_HASH_HANDLE hash=nullptr;
    require(BCryptOpenAlgorithmProvider(&algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0)>=0,"SHA-256 provider unavailable");
    try {
        require(BCryptCreateHash(algorithm,&hash,nullptr,0,nullptr,0,0)>=0,"SHA-256 initialization failed");
        std::ifstream file(path,std::ios::binary); require(file.good(),"Keyboard payload file is missing");
        std::array<char,65536> buffer{};
        while(file) { file.read(buffer.data(),static_cast<std::streamsize>(buffer.size())); const auto size=file.gcount(); if(size) require(BCryptHashData(hash,reinterpret_cast<PUCHAR>(buffer.data()),static_cast<ULONG>(size),0)>=0,"SHA-256 read failed"); }
        require(file.eof(),"Keyboard payload could not be read");
        std::array<UCHAR,32> value{}; require(BCryptFinishHash(hash,value.data(),static_cast<ULONG>(value.size()),0)>=0,"SHA-256 completion failed");
        BCryptDestroyHash(hash); BCryptCloseAlgorithmProvider(algorithm,0);
        constexpr wchar_t hex[]=L"0123456789abcdef"; std::wstring result;
        for(auto byte:value) { result.push_back(hex[byte>>4]); result.push_back(hex[byte&15]); } return result;
    } catch(...) { if(hash) BCryptDestroyHash(hash); BCryptCloseAlgorithmProvider(algorithm,0); throw; }
}
bool safe_name(const std::wstring& value) {
    return !value.empty() && value.size()<=96 && std::all_of(value.begin(),value.end(),[](wchar_t ch){return (ch>=L'a'&&ch<=L'z')||(ch>=L'A'&&ch<=L'Z')||(ch>=L'0'&&ch<=L'9')||ch==L'.'||ch==L'-';}) && value!=L"." && value!=L"..";
}
std::wstring guid() { GUID id{}; check(CoCreateGuid(&id),"Setup ID creation failed"); wchar_t text[40]{}; StringFromGUID2(id,text,40); std::wstring value; for(auto ch:std::wstring(text)) if(std::iswxdigit(ch)) value.push_back(static_cast<wchar_t>(std::towlower(ch))); return value; }
std::wstring ini(const fs::path& file,const wchar_t* section,const wchar_t* key) { wchar_t value[32768]{}; const auto length=GetPrivateProfileStringW(section,key,L"",value,32768,file.c_str()); require(length<32767,"Keyboard setup state is too long"); return {value,length}; }
void set_ini(const fs::path& file,const wchar_t* section,const wchar_t* key,const std::wstring& value) {
    if(!fs::exists(file)) {
        Handle handle(CreateFileW(file.c_str(),GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr));
        require(handle.value!=INVALID_HANDLE_VALUE,"Keyboard setup state could not be created");
        const BYTE bom[]={0xff,0xfe}; DWORD written=0;
        require(WriteFile(handle.value,bom,2,&written,nullptr)!=FALSE && written==2,"Keyboard setup state could not be initialized");
    }
    require(WritePrivateProfileStringW(section,key,value.c_str(),file.c_str())!=FALSE,"Keyboard setup state could not be saved");
}
void flush_file(const fs::path& path) {
    Handle handle(CreateFileW(path.c_str(),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr));
    require(handle.value!=INVALID_HANDLE_VALUE && FlushFileBuffers(handle.value)!=FALSE,"Keyboard setup data could not be flushed");
}
void atomic_ini(const fs::path& file,const std::vector<std::pair<std::wstring,std::wstring>>& values) {
    const fs::path temporary=file.wstring()+L"."+guid()+L".tmp";
    try {
        for(const auto& value:values) set_ini(temporary,L"setup",value.first.c_str(),value.second);
        // Windows returns zero after flushing this cache, including success.
        // Individual writes and FlushFileBuffers below are checked separately.
        WritePrivateProfileStringW(nullptr,nullptr,nullptr,temporary.c_str());
        flush_file(temporary);
        require(MoveFileExW(temporary.c_str(),file.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)!=FALSE,"Keyboard setup state could not be committed");
    } catch(...) { DeleteFileW(temporary.c_str()); throw; }
}
std::wstring registered_path() {
    HKEY key=nullptr; const auto opened=RegOpenKeyExW(HKEY_LOCAL_MACHINE,registration_key,0,KEY_READ|KEY_WOW64_64KEY,&key);
    if(opened==ERROR_FILE_NOT_FOUND) return {};
    require(opened==ERROR_SUCCESS,"Keyboard registration could not be read");
    wchar_t path[32768]{}; DWORD type=0,size=sizeof(path);
    const auto result=RegQueryValueExW(key,nullptr,nullptr,&type,reinterpret_cast<BYTE*>(path),&size); RegCloseKey(key);
    if(result==ERROR_FILE_NOT_FOUND) return {};
    require(result==ERROR_SUCCESS && type==REG_SZ && size>=sizeof(wchar_t) && size<=sizeof(path) && path[std::size(path)-1]==0,"Keyboard registration is invalid");
    return path[0]?setup_path(path):std::wstring{};
}
bool profile_present() {
    ComPtr<ITfInputProcessorProfiles> profiles; check(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())),"TSF profile manager unavailable");
    ComPtr<IEnumGUID> values; check(profiles->EnumInputProcessorInfo(values.put()),"TSF profiles could not be read");
    GUID id{}; ULONG count=0; while(values->Next(1,&id,&count)==S_OK && count==1) if(id==service_id) return true; return false;
}
bool complete_registration() {
    if(registered_path().empty()) return false;
    ComPtr<ITfInputProcessorProfiles> profiles; check(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())),"TSF profiles unavailable");
    BSTR description=nullptr; const auto found=profiles->GetLanguageProfileDescription(service_id,language,profile_id,&description);
    const bool present=found==S_OK && description; SysFreeString(description); if(!present) return false;
    ComPtr<ITfCategoryMgr> categories; check(CoCreateInstance(CLSID_TF_CategoryMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfCategoryMgr,reinterpret_cast<void**>(categories.put())),"TSF categories unavailable");
    ComPtr<IEnumGUID> values; check(categories->EnumItemsInCategory(GUID_TFCAT_TIP_KEYBOARD,values.put()),"TSF keyboard category unavailable");
    GUID id{}; ULONG count=0; while(values->Next(1,&id,&count)==S_OK && count==1) if(id==service_id) return true; return false;
}
struct Module {
    HMODULE value=nullptr;
    explicit Module(const std::wstring& path) {
        value=LoadLibraryExW(path.c_str(),nullptr,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
        require(value!=nullptr,"The keyboard DLL could not be loaded");
    }
    ~Module() { if(value) FreeLibrary(value); }
    using Entry=HRESULT (__stdcall*)();
    Entry entry(const char* name) { auto value=GetProcAddress(this->value,name); require(value!=nullptr,"The keyboard DLL has no registration entry point"); return reinterpret_cast<Entry>(value); }
};
class WindowsHost final:public Host {
public:
    const fs::path root=program_files()/L"NepType Keyboard";
    const fs::path versions=root/L"versions", state_file=root/L"setup.ini";
    State read() override {
        State state;
        if(!fs::exists(state_file)) return state;
        protected_directory(root);
        protected_directory(state_file);
        require(ini(state_file,L"setup",L"Product")==L"NepTypeKeyboard","Unknown keyboard setup state");
        state.active=ini(state_file,L"setup",L"Active"); state.transaction=ini(state_file,L"setup",L"Transaction");
        state.previous_active=ini(state_file,L"setup",L"PreviousActive"); state.previous_registration=ini(state_file,L"setup",L"PreviousRegistration"); state.target=ini(state_file,L"setup",L"Target");
        require(owned(state.active)&&owned(state.previous_active)&&owned(state.previous_registration)&&owned(state.target),"Keyboard setup state references an unknown location");
        return state;
    }
    void write(const State& state) override {
        if(state.active.empty() && state.transaction.empty()) { if(fs::exists(state_file)) require(DeleteFileW(state_file.c_str())!=FALSE,"Keyboard state could not be removed"); return; }
        protected_directory(root); fs::create_directories(root); protected_directory(root);
        atomic_ini(state_file,{{L"Product",L"NepTypeKeyboard"},{L"Active",state.active},{L"Transaction",state.transaction},{L"PreviousActive",state.previous_active},{L"PreviousRegistration",state.previous_registration},{L"Target",state.target}});
    }
    std::wstring registration() override { return registered_path(); }
    bool owned(const std::wstring& path) override {
        if(path.empty()) return true;
        const auto value=setup_path(path);
        if(value==setup_path(root/L"NepTypeTsf.dll")) return true; // prior manual installation
        if(!below(value,setup_path(versions)) || lower(fs::path(value).filename().wstring())!=L"neptypetsf.dll") return false;
        const auto folder=fs::path(value).parent_path();
        const auto marker=folder/L"payload.ini";
        if(fs::exists(marker)) protected_directory(marker);
        return folder.parent_path()==fs::path(setup_path(versions)) && ini(marker,L"payload",L"Product")==L"NepTypeKeyboard";
    }
    void validate(const fs::path& folder,bool bound) {
        protected_directory(folder);
        for(const auto* name:{L"NepTypeTsf.dll",L"NepTypeEngine.dll",L"NepTypeKeyboardSetup.exe",L"payload.ini"}) protected_directory(folder/name);
        require(owned(setup_path(folder/L"NepTypeTsf.dll")),"Keyboard payload ownership is missing");
        const auto tsf=ini(folder/L"payload.ini",L"payload",L"TsfSHA256"), engine=ini(folder/L"payload.ini",L"payload",L"EngineSHA256");
        require(tsf.size()==64 && engine.size()==64 && digest(folder/L"NepTypeTsf.dll")==tsf && digest(folder/L"NepTypeEngine.dll")==engine,"Installed keyboard payload is damaged");
        if(bound) require(tsf==expected_tsf && engine==expected_engine,"Keyboard payload does not match this installer");
    }
    std::wstring stage(const std::wstring& source,const std::wstring& version,const State& state) override {
        require(safe_name(version),"Invalid keyboard version");
        const fs::path input=fs::absolute(source);
        // The helper is bound at build time to these exact two DLL hashes. It
        // cannot be used as an elevated arbitrary-DLL registration launcher.
        require(digest(input/L"NepTypeTsf.dll")==expected_tsf && digest(input/L"NepTypeEngine.dll")==expected_engine,"Keyboard payload does not match the installer");
        protected_directory(root); fs::create_directories(versions); protected_directory(root); protected_directory(versions);
        if(!state.active.empty() && below(state.active,setup_path(versions))) {
            const auto active=fs::path(state.active).parent_path();
            if(ini(active/L"payload.ini",L"payload",L"Version")==version && ini(active/L"payload.ini",L"payload",L"TsfSHA256")==expected_tsf && ini(active/L"payload.ini",L"payload",L"EngineSHA256")==expected_engine) { validate(active,true); return setup_path(active/L"NepTypeTsf.dll"); }
        }
        // A new generation is never reused after uninstall. Delayed Windows
        // delete requests therefore cannot remove a later reinstallation.
        const auto folder=versions/(version+L"-"+guid()); fs::create_directory(folder); protected_directory(folder);
        try {
            fs::copy_file(input/L"NepTypeTsf.dll",folder/L"NepTypeTsf.dll");
            fs::copy_file(input/L"NepTypeEngine.dll",folder/L"NepTypeEngine.dll");
            wchar_t executable[32768]{}; require(GetModuleFileNameW(nullptr,executable,32768)>0,"Setup helper path is unavailable");
            fs::copy_file(executable,folder/L"NepTypeKeyboardSetup.exe");
            const auto manifest=folder/L"payload.ini";
            set_ini(manifest,L"payload",L"Product",L"NepTypeKeyboard"); set_ini(manifest,L"payload",L"Version",version);
            set_ini(manifest,L"payload",L"TsfSHA256",expected_tsf); set_ini(manifest,L"payload",L"EngineSHA256",expected_engine);
            set_ini(manifest,L"payload",L"HelperSHA256",digest(folder/L"NepTypeKeyboardSetup.exe"));
            WritePrivateProfileStringW(nullptr,nullptr,nullptr,manifest.c_str()); // successful cache flush also returns zero
            for(const auto* name:{L"NepTypeTsf.dll",L"NepTypeEngine.dll",L"NepTypeKeyboardSetup.exe",L"payload.ini"}) flush_file(folder/name);
            validate(folder,true); return setup_path(folder/L"NepTypeTsf.dll");
        } catch(...) {
            for(const auto* name:{L"NepTypeTsf.dll",L"NepTypeEngine.dll",L"NepTypeKeyboardSetup.exe",L"payload.ini"}) DeleteFileW((folder/name).c_str());
            RemoveDirectoryW(folder.c_str()); throw;
        }
    }
    void register_at(const std::wstring& path) override {
        require(owned(path),"Unknown keyboard registration target");
        const auto folder=fs::path(path).parent_path();
        if(below(path,setup_path(versions))) validate(folder,false); else protected_directory(folder);
        Module library(path);
        using Factory=HRESULT (__stdcall*)(REFCLSID,REFIID,void**);
        const auto factory=reinterpret_cast<Factory>(GetProcAddress(library.value,"DllGetClassObject"));
        require(factory!=nullptr,"The keyboard DLL is not a text service");
        ComPtr<IClassFactory> created; check(factory(service_id,IID_IClassFactory,reinterpret_cast<void**>(created.put())),"Keyboard class identity does not match");
        created.reset();
        if(complete_registration()) {
            // A version upgrade only changes the COM DLL path. Do not recreate
            // language profiles or change any account's enabled/default state.
            HKEY key=nullptr; require(RegOpenKeyExW(HKEY_LOCAL_MACHINE,registration_key,0,KEY_SET_VALUE|KEY_WOW64_64KEY,&key)==ERROR_SUCCESS,"Keyboard registration is not writable");
            const auto error=RegSetValueExW(key,nullptr,0,REG_SZ,reinterpret_cast<const BYTE*>(path.c_str()),static_cast<DWORD>((path.size()+1)*sizeof(wchar_t)));
            RegCloseKey(key); require(error==ERROR_SUCCESS,"Keyboard registration switch failed");
        } else check(library.entry("DllRegisterServer")(),"Keyboard registration failed");
    }
    void unregister_at(const std::wstring& path) override {
        require(owned(path),"Unknown keyboard removal target");
        if(!path.empty() && fs::exists(path)) { Module library(path); check(library.entry("DllUnregisterServer")(),"Keyboard unregistration failed"); }
        else check(DllUnregisterServer(),"Keyboard metadata could not be removed");
    }
    bool profile_present() override { return ::profile_present(); }
    bool cleanup() override {
        require(registration().empty() && !profile_present() && read().transaction.empty() && read().active.empty(),"A registered keyboard must not be deleted");
        if(!fs::exists(versions)) return false;
        protected_directory(root); protected_directory(versions); bool restart=false;
        for(const auto& item:fs::directory_iterator(versions)) {
            if(!item.is_directory() || fs::is_symlink(item.symlink_status())) continue;
            const auto folder=item.path(); protected_directory(folder);
            if(ini(folder/L"payload.ini",L"payload",L"Product")!=L"NepTypeKeyboard") continue;
            bool delayed=false;
            for(const auto* name:{L"NepTypeTsf.dll",L"NepTypeEngine.dll",L"NepTypeKeyboardSetup.exe"}) {
                const auto file=folder/name;
                if(!fs::exists(file)) continue;
                if(!DeleteFileW(file.c_str())) { const auto error=GetLastError(); require(error==ERROR_SHARING_VIOLATION || error==ERROR_ACCESS_DENIED,"Keyboard file could not be removed"); require(MoveFileExW(file.c_str(),nullptr,MOVEFILE_DELAY_UNTIL_REBOOT)!=FALSE,"Locked keyboard file could not be scheduled for removal"); delayed=true; }
            }
            const auto marker=folder/L"payload.ini";
            if(delayed) { require(MoveFileExW(marker.c_str(),nullptr,MOVEFILE_DELAY_UNTIL_REBOOT)!=FALSE,"Keyboard cleanup metadata could not be scheduled"); require(MoveFileExW(folder.c_str(),nullptr,MOVEFILE_DELAY_UNTIL_REBOOT)!=FALSE,"Keyboard folder cleanup could not be scheduled"); restart=true; }
            else { DeleteFileW(marker.c_str()); RemoveDirectoryW(folder.c_str()); }
        }
        if(restart) { MoveFileExW(versions.c_str(),nullptr,MOVEFILE_DELAY_UNTIL_REBOOT); MoveFileExW(root.c_str(),nullptr,MOVEFILE_DELAY_UNTIL_REBOOT); }
        else { RemoveDirectoryW(versions.c_str()); RemoveDirectoryW(root.c_str()); }
        return restart;
    }
};
void enable_user(WindowsHost& host) {
    const auto state=host.read(); const auto current=host.registration();
    require(!state.active.empty() && state.transaction.empty() && current==state.active,"A completed keyboard installation is required");
    host.validate(fs::path(current).parent_path(),false);
    ComPtr<ITfInputProcessorProfiles> profiles; check(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())),"TSF profile manager unavailable");
    check(profiles->EnableLanguageProfile(service_id,language,profile_id,TRUE),"The keyboard could not be enabled for this account");
}
int run(int argc,wchar_t** argv) {
    require(argc>=2,"Keyboard setup requires a command"); architecture(); Runtime runtime; WindowsHost host;
    const std::wstring command=argv[1];
    if(command==L"enable-user") { enable_user(host); std::wcout<<L"NepType is enabled for this account. Choose it using Windows keyboard settings; the default keyboard was not changed.\n"; return 0; }
    if(command==L"status" || command==L"probe") {
        if(command==L"probe" && argc==3) protected_directory(argv[2]);
        protected_directory(host.root); const auto state=host.read(); const auto current=host.registration();
        require(host.owned(current),"A different keyboard registration is present");
        std::wcout<<L"Registered DLL: "<<current<<L"\nActive DLL: "<<state.active<<L"\nTransaction: "<<state.transaction<<L"\n";
        if(command==L"status" && !current.empty()) {
            ComPtr<ITfInputProcessorProfiles> profiles; check(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())),"TSF profiles unavailable");
            BOOL enabled=FALSE; check(profiles->IsEnabledLanguageProfile(service_id,language,profile_id,&enabled),"Keyboard account state is unavailable");
            std::wcout<<L"User enabled: "<<(enabled?L"1":L"0")<<L"\n";
        }
        return 0;
    }
    administrator(); Mutex mutex; Transaction transaction(host);
    if(command==L"begin") { require(argc==5,"begin requires payload, version and transaction ID"); require(safe_name(argv[4]),"Invalid setup transaction ID"); transaction.begin(argv[2],argv[3],argv[4]); std::wcout<<L"Staged DLL: "<<host.read().target<<L"\n"; }
    else if(command==L"commit") { require(argc==3,"commit requires a transaction ID"); transaction.commit(argv[2]); }
    else if(command==L"rollback") { require(argc==3,"rollback requires a transaction ID"); transaction.rollback(argv[2]); }
    else if(command==L"recover") transaction.recover();
    else if(command==L"uninstall") return transaction.uninstall()?ERROR_SUCCESS_REBOOT_REQUIRED:0;
    else if(command==L"cleanup") return host.cleanup()?ERROR_SUCCESS_REBOOT_REQUIRED:0;
    else throw std::runtime_error("Unknown keyboard setup command");
    return 0;
}
}
int wmain(int argc,wchar_t** argv) {
    try { return run(argc,argv); }
    catch(const std::exception& error) { std::cerr<<"NepType keyboard setup: "<<error.what()<<"\n"; return 1; }
}
