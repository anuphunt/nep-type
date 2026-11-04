// Windows SDK + real Microsoft TSF context and text store. This exercises the
// production DLL/engine, not fake_tsf.h. On a disposable CI VM (or explicit
// clean-desktop opt-in), it registers a process-scoped profile, routes keys
// through TSF, restores the previous profile and unregisters. It does not claim
// testing the product installer, Office, browsers or app-specific undo.
#include "windows_support.h"
#include "field_policy.h"
#include <textstor.h>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <algorithm>
#include <iostream>

using namespace neptype::tsf;
static void require(bool value,const char* expression,int line) {
    if (!value) throw std::runtime_error(std::string("Native TSF check at line ")+std::to_string(line)+": "+expression);
}
#define CHECK(expression) require(!!(expression),#expression,__LINE__)
static void require_hr(const char* name,HRESULT value) {
    if (FAILED(value)) { std::ostringstream message; message<<name<<": HRESULT 0x"<<std::hex<<static_cast<unsigned long>(value); throw std::runtime_error(message.str()); }
}
struct ComRuntime {
    bool initialized=false;
    ComRuntime() { require_hr("CoInitializeEx",CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED)); initialized=true; }
    void close() { if(initialized) CoUninitialize(); initialized=false; }
    ~ComRuntime() { close(); }
};
struct Library {
    HMODULE value=nullptr;
    explicit Library(const char* path):value(LoadLibraryA(path)) { CHECK(value); }
    ~Library() { if(value) FreeLibrary(value); }
};
#ifndef TF_IPPMF_FORPROCESS
#define TF_IPPMF_FORPROCESS 0x10000000
#define TF_IPPMF_ENABLEPROFILE 0x00000001
#endif
struct RegisteredProfile {
    using Entry=HRESULT (__stdcall*)();
    inline static constexpr GUID test_profile{0xb6a68f96,0x5819,0x4b7f,{0x85,0x69,0xa1,0x15,0x90,0xd1,0x20,0x03}};
    Entry unregister=nullptr;
    ComPtr<ITfInputProcessorProfiles> profiles;
    ComPtr<ITfInputProcessorProfileMgr> manager;
    TF_INPUTPROCESSORPROFILE previous{};
    LANGID test_language=0;
    bool registered=false,active=false,restore=false;
    void begin(HMODULE library) {
        // Refuse to overwrite a real user installation, even with explicit opt-in.
        HKEY existing=nullptr;
        auto error=RegOpenKeyExW(HKEY_LOCAL_MACHINE,L"SOFTWARE\\Classes\\CLSID\\{B6A68F96-5819-4B7F-8569-A11590D12001}",0,KEY_READ,&existing);
        if(error==ERROR_SUCCESS) { RegCloseKey(existing); throw std::runtime_error("A NepType keyboard is already registered; use a clean test machine."); }
        CHECK(error==ERROR_FILE_NOT_FOUND);
        auto registration=reinterpret_cast<Entry>(GetProcAddress(library,"DllRegisterServer"));
        unregister=reinterpret_cast<Entry>(GetProcAddress(library,"DllUnregisterServer")); CHECK(registration && unregister);
        require_hr("DllRegisterServer",registration()); registered=true;
        require_hr("Create profiles",CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(profiles.put())));
        require_hr("Query profile manager",profiles->QueryInterface(IID_ITfInputProcessorProfileMgr,reinterpret_cast<void**>(manager.put())));
        restore=manager->GetActiveProfile(GUID_TFCAT_TIP_KEYBOARD,&previous)==S_OK;
        require_hr("Get current language",profiles->GetCurrentLanguage(&test_language));
        // Exercise real profile activation in the current input language. The
        // production Nepali profile is also registered, without installing a
        // language pack or changing the runner's default input language.
        constexpr wchar_t name[]=L"NepType CI native input test";
        wchar_t path[32768]{}; const auto length=GetModuleFileNameW(library,path,32768); CHECK(length && length<32768);
        require_hr("Add test profile",profiles->AddLanguageProfile(service_id,test_language,test_profile,name,static_cast<ULONG>(std::size(name)-1),path,length,0));
        require_hr("Enable test profile",profiles->EnableLanguageProfile(service_id,test_language,test_profile,TRUE));
        const auto result=manager->ActivateProfile(TF_PROFILETYPE_INPUTPROCESSOR,test_language,service_id,test_profile,nullptr,TF_IPPMF_FORPROCESS|TF_IPPMF_ENABLEPROFILE);
        require_hr("Activate test profile",result); CHECK(result==S_OK); active=true;
    }
    HRESULT finish() {
        HRESULT result=S_OK;
        if(active && manager) {
            result=manager->DeactivateProfile(TF_PROFILETYPE_INPUTPROCESSOR,test_language,service_id,test_profile,nullptr,TF_IPPMF_FORPROCESS);
            active=false;
        }
        if(restore && manager) {
            const auto hr=manager->ActivateProfile(previous.dwProfileType,previous.langid,previous.clsid,previous.guidProfile,
                previous.dwProfileType==TF_PROFILETYPE_KEYBOARDLAYOUT ? previous.hkl : nullptr,TF_IPPMF_FORPROCESS);
            if(FAILED(hr)) result=hr;
            restore=false;
        }
        manager.reset(); profiles.reset();
        if(registered && unregister) { const auto hr=unregister(); if(FAILED(hr)) result=hr; registered=false; }
        return result;
    }
    ~RegisteredProfile() { if(FAILED(finish())) std::cerr<<"Native TSF profile cleanup failed"<<std::endl; }
};
struct Store final : ITextStoreACP {
    ULONG refs = 1;
    ComPtr<ITextStoreACPSink> sink;
    std::wstring text;
    LONG start = 0, end = 0;
    bool locked = false, deny = false, readonly = false;
    HWND window = nullptr;
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid != IID_IUnknown && iid != IID_ITextStoreACP) return E_NOINTERFACE;
        *out = static_cast<ITextStoreACP*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { return --refs; }
    HRESULT STDMETHODCALLTYPE AdviseSink(REFIID iid, IUnknown* value, DWORD) override {
        if (iid != IID_ITextStoreACPSink) return E_NOINTERFACE;
        return value->QueryInterface(iid,reinterpret_cast<void**>(sink.put()));
    }
    HRESULT STDMETHODCALLTYPE UnadviseSink(IUnknown*) override { sink.reset(); return S_OK; }
    HRESULT STDMETHODCALLTYPE RequestLock(DWORD flags, HRESULT* result) override {
        if (deny || locked || !sink) { *result = TS_E_SYNCHRONOUS; return S_OK; }
        locked = true; *result = sink->OnLockGranted(flags); locked = false; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetStatus(TS_STATUS* status) override {
        status->dwDynamicFlags = readonly ? TS_SD_READONLY : 0;
        status->dwStaticFlags = TS_SS_NOHIDDENTEXT; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE QueryInsert(LONG a, LONG b, ULONG n, LONG* first, LONG* last) override {
        if (a < 0 || b < a || b > static_cast<LONG>(text.size())) return TS_E_INVALIDPOS;
        *first = a; *last = a + static_cast<LONG>(n); return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetSelection(ULONG index, ULONG capacity, TS_SELECTION_ACP* selection, ULONG* count) override {
        *count = 0; if (!capacity || (index != 0 && index != TS_DEFAULT_SELECTION)) return E_INVALIDARG;
        selection->acpStart = start; selection->acpEnd = end; selection->style = {TS_AE_END,FALSE}; *count = 1; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE SetSelection(ULONG count, const TS_SELECTION_ACP* selection) override {
        if (count != 1) return E_INVALIDARG;
        start = selection->acpStart; end = selection->acpEnd; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetText(LONG a, LONG b, WCHAR* out, ULONG capacity, ULONG* read,
        TS_RUNINFO* runs, ULONG run_capacity, ULONG* run_count, LONG* next) override {
        if (b == -1) b = static_cast<LONG>(text.size());
        if (a < 0 || b < a || b > static_cast<LONG>(text.size())) return TS_E_INVALIDPOS;
        *read = std::min<ULONG>(capacity, static_cast<ULONG>(b-a));
        if (*read) std::copy_n(text.data()+a,*read,out);
        *next = a + static_cast<LONG>(*read); *run_count = 0;
        if (run_capacity && *read) { runs[0] = {*read,TS_RT_PLAIN}; *run_count = 1; }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE SetText(DWORD, LONG a, LONG b, const WCHAR* value, ULONG size, TS_TEXTCHANGE* change) override {
        if (readonly) return TS_E_READONLY;
        if (a < 0 || b < a || b > static_cast<LONG>(text.size())) return TS_E_INVALIDPOS;
        *change = {a,b,a+static_cast<LONG>(size)};
        text.replace(static_cast<std::size_t>(a),static_cast<std::size_t>(b-a),value,size);
        start = end = a+static_cast<LONG>(size); return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetFormattedText(LONG,LONG,IDataObject**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetEmbedded(LONG,REFGUID,REFIID,IUnknown**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE QueryInsertEmbedded(const GUID*,const FORMATETC*,BOOL* allowed) override { *allowed=FALSE; return S_OK; }
    HRESULT STDMETHODCALLTYPE InsertEmbedded(DWORD,LONG,LONG,IDataObject*,TS_TEXTCHANGE*) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE InsertTextAtSelection(DWORD flags,const WCHAR* value,ULONG size,LONG* a,LONG* b,TS_TEXTCHANGE* change) override {
        if (a) *a=start; if (b) *b=start+static_cast<LONG>(size);
        if (flags & TS_IAS_QUERYONLY) return S_OK;
        return SetText(0,start,end,value,size,change);
    }
    HRESULT STDMETHODCALLTYPE InsertEmbeddedAtSelection(DWORD,IDataObject*,LONG*,LONG*,TS_TEXTCHANGE*) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE RequestSupportedAttrs(DWORD,ULONG,const TS_ATTRID*) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE RequestAttrsAtPosition(LONG,ULONG,const TS_ATTRID*,DWORD) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE RequestAttrsTransitioningAtPosition(LONG,ULONG,const TS_ATTRID*,DWORD) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE FindNextAttrTransition(LONG,LONG halt,ULONG,const TS_ATTRID*,DWORD,LONG* next,BOOL* found,LONG* offset) override { *next=halt; *found=FALSE; *offset=0; return S_OK; }
    HRESULT STDMETHODCALLTYPE RetrieveRequestedAttrs(ULONG,TS_ATTRVAL*,ULONG* count) override { *count=0; return S_OK; }
    HRESULT STDMETHODCALLTYPE GetEndACP(LONG* length) override { *length=static_cast<LONG>(text.size()); return S_OK; }
    HRESULT STDMETHODCALLTYPE GetActiveView(TsViewCookie* view) override { *view=1; return S_OK; }
    HRESULT STDMETHODCALLTYPE GetACPFromPoint(TsViewCookie,const POINT*,DWORD,LONG*) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetTextExt(TsViewCookie,LONG,LONG,RECT* rect,BOOL* clipped) override { *rect={10,10,20,30}; *clipped=FALSE; return S_OK; }
    HRESULT STDMETHODCALLTYPE GetScreenExt(TsViewCookie,RECT* rect) override { *rect={0,0,800,600}; return S_OK; }
    HRESULT STDMETHODCALLTYPE GetWnd(TsViewCookie,HWND* out) override { *out=window; return S_OK; }
    void select(LONG a, LONG b) { start=a; end=b; if(sink) sink->OnSelectionChange(); }
    void set_readonly(bool value) { readonly=value; if(sink) sink->OnStatusChange(TS_SD_READONLY); }
};
static void pump() { MSG message; while (PeekMessageW(&message,nullptr,0,0,PM_REMOVE)) { TranslateMessage(&message); DispatchMessageW(&message); } }
struct Probe final : ITfEditSession {
    ITfContext* context; ULONG refs=1;
    explicit Probe(ITfContext* value):context(value) {}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void** out) override {
        if (!out) return E_POINTER; *out=nullptr;
        if (iid!=IID_IUnknown && iid!=IID_ITfEditSession) return E_NOINTERFACE;
        *out=static_cast<ITfEditSession*>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { return --refs; }
    HRESULT STDMETHODCALLTYPE DoEditSession(TfEditCookie cookie) override {
        TF_STATUS status{}; const auto hr=context->GetStatus(&status);
        std::cerr << "TSF probe: status=" << std::hex << static_cast<unsigned long>(hr)
            << " dynamic=" << status.dwDynamicFlags << std::dec
            << " disabled=" << disabled_compartment(context,GUID_COMPARTMENT_KEYBOARD_DISABLED)
            << " empty=" << disabled_compartment(context,GUID_COMPARTMENT_EMPTYCONTEXT)
            << " prose-allowed=" << allows_conversion(context,cookie) << std::endl;
        TF_SELECTION selected{}; ULONG count=0;
        const auto selection=context->GetSelection(cookie,TF_DEFAULT_SELECTION,1,&selected,&count);
        std::cerr<<"Scope probe selection="<<std::hex<<static_cast<unsigned long>(selection)<<std::dec<<" count="<<count;
        if(selected.range) {
            ComPtr<ITfReadOnlyProperty> property;
            const auto get=context->GetAppProperty(GUID_PROP_INPUTSCOPE,property.put());
            std::cerr<<" property="<<std::hex<<static_cast<unsigned long>(get)<<std::dec;
            if(property) { VARIANT value; VariantInit(&value); const auto read=property->GetValue(cookie,selected.range,&value);
                std::cerr<<" value-result="<<std::hex<<static_cast<unsigned long>(read)<<std::dec<<" type="<<value.vt; VariantClear(&value); }
            selected.range->Release();
        }
        std::cerr<<std::endl;
        return S_OK;
    }
};
static int run(int argc,char** argv) {
    CHECK(argc==2 || argc==3);
    const auto actions=std::getenv("GITHUB_ACTIONS"), environment=std::getenv("RUNNER_ENVIRONMENT");
    const bool hosted=actions && std::strcmp(actions,"true")==0 && environment && std::strcmp(environment,"github-hosted")==0;
    const bool opted_in=argc==3 && std::strcmp(argv[2],"--register-profile")==0;
    if(!hosted && !opted_in) {
        std::cerr<<"Native profile test requires a clean elevated test desktop and explicit --register-profile, or an ephemeral GitHub-hosted runner."<<std::endl;
        return actions ? 1 : 77;
    }
    ComRuntime runtime;
    Store store;
    store.window = CreateWindowExW(0,L"STATIC",L"NepType native TSF integration",WS_OVERLAPPEDWINDOW,0,0,800,600,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
    CHECK(store.window);
    ComPtr<ITfThreadMgr> thread;
    CHECK(SUCCEEDED(CoCreateInstance(CLSID_TF_ThreadMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfThreadMgr,reinterpret_cast<void**>(thread.put()))));
    TfClientId client=TF_CLIENTID_NULL; CHECK(SUCCEEDED(thread->Activate(&client)));
    ComPtr<ITfDocumentMgr> document; CHECK(SUCCEEDED(thread->CreateDocumentMgr(document.put())));
    ComPtr<ITfContext> context; TfEditCookie cookie=0;
    CHECK(SUCCEEDED(document->CreateContext(client,0,&store,context.put(),&cookie)));
    CHECK(SUCCEEDED(document->Push(context.get()))); CHECK(SUCCEEDED(thread->SetFocus(document.get())));
    ComPtr<ITfDocumentMgr> previous_document;
    require_hr("Associate host window",thread->AssociateFocus(store.window,document.get(),previous_document.put()));
    ShowWindow(store.window,SW_SHOW); SetForegroundWindow(store.window); SetFocus(store.window); pump();
    Library library(argv[1]);
    RegisteredProfile profile;
    profile.begin(library.value); pump();
    require_hr("Focus test document",thread->SetFocus(document.get()));
    ComPtr<ITfKeystrokeMgr> keys;
    CHECK(SUCCEEDED(thread->QueryInterface(IID_ITfKeystrokeMgr,reinterpret_cast<void**>(keys.put()))));
    CLSID foreground{};
    const auto deadline=GetTickCount64()+5000;
    do { pump(); keys->GetForeground(&foreground); if(foreground==service_id) break; Sleep(10); } while(GetTickCount64()<deadline);
    CHECK(foreground==service_id);
    ComPtr<ITfClientId> client_ids;
    CHECK(SUCCEEDED(thread->QueryInterface(IID_ITfClientId,reinterpret_cast<void**>(client_ids.put()))));
    TfClientId service_client=TF_CLIENTID_NULL;
    CHECK(SUCCEEDED(client_ids->GetClientId(service_id,&service_client))); CHECK(service_client!=TF_CLIENTID_NULL);
    CHECK(prose_scope(IS_DEFAULT) && prose_scope(IS_TEXT));
    for (const auto scope : {IS_PASSWORD,IS_URL,IS_EMAIL_SMTPEMAILADDRESS,IS_NUMBER,IS_TELEPHONE_FULLTELEPHONENUMBER,IS_PRIVATE}) CHECK(!prose_scope(scope));
    auto key=[&](UINT vk, bool control=false, bool shift=false) {
        BYTE saved[256]{}, state[256]{}; GetKeyboardState(saved);
        state[VK_CONTROL] = control ? 0x80 : 0; state[VK_SHIFT] = shift ? 0x80 : 0;
        SetKeyboardState(state);
        LPARAM flags=static_cast<LPARAM>(MapVirtualKeyW(vk,MAPVK_VK_TO_VSC))<<16;
        BOOL eaten=FALSE, tested=FALSE;
        auto before=store.text;
        CHECK(SUCCEEDED(keys->TestKeyDown(vk,flags,&tested)));
        CHECK(store.text==before); // test callbacks are read-only
        if(tested) CHECK(SUCCEEDED(keys->KeyDown(vk,flags,&eaten)));
        if (!eaten && tested) {
            std::cerr << "Synthetic key passed through: vk=" << vk << " text-length=" << store.text.size() << std::endl;
            Probe probe(context.get()); HRESULT result=E_FAIL;
            const auto request=context->RequestEditSession(service_client,&probe,TF_ES_SYNC|TF_ES_READ,&result);
            std::cerr << "Probe request=" << std::hex << static_cast<unsigned long>(request)
                << " result=" << static_cast<unsigned long>(result) << std::dec << std::endl;
        }
        BOOL up=FALSE,up_tested=FALSE; CHECK(SUCCEEDED(keys->TestKeyUp(vk,flags,&up_tested))); if(up_tested) CHECK(SUCCEEDED(keys->KeyUp(vk,flags,&up))); CHECK(up==eaten);
        SetKeyboardState(saved);
        return eaten != FALSE;
    };
    for (auto vk : {'N','A','M','A','S','T','E'}) CHECK(key(vk));
    CHECK(store.text==L"namaste"); CHECK(key(VK_SPACE));
    CHECK(store.text==L"नमस्ते ");
    for (auto vk : {'M','A'}) CHECK(key(vk)); CHECK(key(VK_BACK)); CHECK(store.text==L"नमस्ते m");
    CHECK(key(VK_ESCAPE)); CHECK(store.text==L"नमस्ते m");
    // Selection replacement follows the real TSF range/composition semantics.
    store.select(0,6); CHECK(key('N')); CHECK(store.text==L"n m"); CHECK(key(VK_ESCAPE));
    // Mouse/caret relocation cannot redirect an old token's conversion.
    store.select(static_cast<LONG>(store.text.size()),static_cast<LONG>(store.text.size()));
    CHECK(key('M')); store.select(0,0); CHECK(key('A')); CHECK(key(VK_ESCAPE));
    CHECK(store.text==L"an mm");
    CHECK(key('M')); const auto unchanged=store.text;
    CHECK(!key(VK_LEFT)); CHECK(store.text==unchanged);
    store.set_readonly(true); CHECK(!key('X')); CHECK(store.text==unchanged); store.set_readonly(false);
    store.deny=true; CHECK(!key('X')); CHECK(store.text==unchanged); store.deny=false;
    CHECK(key(VK_SPACE,true,true)); // Mixed -> Nepali
    CHECK(key(VK_SPACE,true,true)); // Nepali -> English
    CHECK(!key('X') && store.text==unchanged);
    CHECK(key(VK_SPACE,true,true)); // English -> Mixed
    keys.reset(); client_ids.reset();
    require_hr("Deactivate/unregister test profile",profile.finish()); pump();
    ComPtr<ITfDocumentMgr> detached;
    require_hr("Restore host association",thread->AssociateFocus(store.window,previous_document.get(),detached.put()));
    detached.reset(); previous_document.reset();
    document->Pop(TF_POPF_ALL); context.reset(); document.reset(); thread->Deactivate(); thread.reset();
    pump(); DestroyWindow(store.window); store.window=nullptr; store.sink.reset();
    CoFreeUnusedLibraries(); runtime.close();
    auto unload=reinterpret_cast<HRESULT (__stdcall*)()>(GetProcAddress(library.value,"DllCanUnloadNow"));
    CHECK(unload && unload()==S_OK);
    std::cout << "PASS: registered production DLL/shared engine through native TSF key routing: typing, commit, escape, backspace, selected text, moved caret, read-only, denied locks, profile cleanup and teardown\n";
    return 0;
}
int main(int argc,char** argv) {
    try { return run(argc,argv); }
    catch(const std::exception& error) { std::cerr<<error.what()<<std::endl; return 1; }
}
