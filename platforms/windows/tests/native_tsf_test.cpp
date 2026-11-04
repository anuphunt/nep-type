// Windows SDK + real Microsoft TSF context and text store. This exercises the
// production DLL/engine, not fake_tsf.h. It does not claim testing in Office or
// browsers, installation, OS profile routing, or app-specific undo behavior.
#include "windows_support.h"
#include "field_policy.h"
#include <textstor.h>
#include <cassert>
#include <algorithm>
#include <iostream>

using namespace neptype::tsf;
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
};
static void pump() { MSG message; while (PeekMessageW(&message,nullptr,0,0,PM_REMOVE)) { TranslateMessage(&message); DispatchMessageW(&message); } }
int main(int argc, char** argv) {
    assert(argc == 2);
    assert(SUCCEEDED(CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED)));
    Store store;
    store.window = CreateWindowExW(0,L"STATIC",L"NepType native TSF integration",WS_OVERLAPPEDWINDOW,0,0,800,600,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
    assert(store.window);
    ComPtr<ITfThreadMgr> thread;
    assert(SUCCEEDED(CoCreateInstance(CLSID_TF_ThreadMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfThreadMgr,reinterpret_cast<void**>(thread.put()))));
    TfClientId client=TF_CLIENTID_NULL; assert(SUCCEEDED(thread->Activate(&client)));
    ComPtr<ITfDocumentMgr> document; assert(SUCCEEDED(thread->CreateDocumentMgr(document.put())));
    ComPtr<ITfContext> context; TfEditCookie cookie=0;
    assert(SUCCEEDED(document->CreateContext(client,0,&store,context.put(),&cookie)));
    assert(SUCCEEDED(document->Push(context.get()))); assert(SUCCEEDED(thread->SetFocus(document.get())));
    auto library=LoadLibraryA(argv[1]); assert(library);
    auto get=reinterpret_cast<HRESULT (__stdcall*)(REFCLSID,REFIID,void**)>(GetProcAddress(library,"DllGetClassObject")); assert(get);
    ComPtr<IClassFactory> factory; assert(SUCCEEDED(get(service_id,IID_IClassFactory,reinterpret_cast<void**>(factory.put()))));
    ComPtr<ITfTextInputProcessor> service;
    assert(SUCCEEDED(factory->CreateInstance(nullptr,IID_ITfTextInputProcessor,reinterpret_cast<void**>(service.put()))));
    assert(SUCCEEDED(service->Activate(thread.get(),client)));
    ComPtr<ITfKeyEventSink> keys;
    assert(SUCCEEDED(service->QueryInterface(IID_ITfKeyEventSink,reinterpret_cast<void**>(keys.put()))));
    assert(prose_scope(IS_DEFAULT) && prose_scope(IS_TEXT));
    for (const auto scope : {IS_PASSWORD,IS_URL,IS_EMAIL_SMTPEMAILADDRESS,IS_NUMBER,IS_TELEPHONE_FULLTELEPHONENUMBER,IS_PRIVATE}) assert(!prose_scope(scope));
    auto key=[&](UINT vk, bool control=false, bool shift=false) {
        BYTE saved[256]{}, state[256]{}; GetKeyboardState(saved);
        state[VK_CONTROL] = control ? 0x80 : 0; state[VK_SHIFT] = shift ? 0x80 : 0;
        SetKeyboardState(state);
        LPARAM flags=static_cast<LPARAM>(MapVirtualKeyW(vk,MAPVK_VK_TO_VSC))<<16;
        BOOL eaten=FALSE, tested=FALSE;
        auto before=store.text;
        assert(SUCCEEDED(keys->OnTestKeyDown(context.get(),vk,flags,&tested)));
        assert(store.text==before); // test callbacks are read-only
        assert(SUCCEEDED(keys->OnKeyDown(context.get(),vk,flags,&eaten)));
        BOOL up=FALSE; assert(SUCCEEDED(keys->OnKeyUp(context.get(),vk,flags,&up))); assert(up==eaten);
        SetKeyboardState(saved);
        return eaten != FALSE;
    };
    for (auto vk : {'N','A','M','A','S','T','E'}) assert(key(vk));
    assert(store.text==L"namaste"); assert(key(VK_SPACE));
    assert(store.text==L"नमस्ते ");
    for (auto vk : {'M','A'}) assert(key(vk)); assert(key(VK_BACK)); assert(store.text==L"नमस्ते m");
    assert(key(VK_ESCAPE)); assert(store.text==L"नमस्ते m");
    // Selection replacement follows the real TSF range/composition semantics.
    store.select(0,6); assert(key('N')); assert(store.text==L"n m"); assert(key(VK_ESCAPE));
    // Mouse/caret relocation cannot redirect an old token's conversion.
    store.select(static_cast<LONG>(store.text.size()),static_cast<LONG>(store.text.size()));
    assert(key('M')); store.select(0,0); assert(key('A')); assert(key(VK_ESCAPE));
    assert(store.text==L"an mm");
    assert(key('M')); const auto unchanged=store.text;
    assert(!key(VK_LEFT)); assert(store.text==unchanged);
    store.readonly=true; assert(!key('X')); assert(store.text==unchanged); store.readonly=false;
    store.deny=true; assert(!key('X')); assert(store.text==unchanged); store.deny=false;
    assert(key(VK_SPACE,true,true)); // Mixed -> Nepali
    assert(key(VK_SPACE,true,true)); // Nepali -> English
    assert(!key('X') && store.text==unchanged);
    assert(key(VK_SPACE,true,true)); // English -> Mixed
    assert(SUCCEEDED(service->Deactivate())); pump();
    keys.reset(); service.reset(); factory.reset();
    document->Pop(TF_POPF_ALL); context.reset(); document.reset(); thread->Deactivate(); thread.reset();
    pump(); DestroyWindow(store.window);
    auto unload=reinterpret_cast<HRESULT (__stdcall*)()>(GetProcAddress(library,"DllCanUnloadNow"));
    assert(unload && unload()==S_OK); FreeLibrary(library); CoUninitialize();
    std::cout << "PASS: production DLL/shared engine in native TSF store: typing, commit, escape, backspace, selected text, moved caret, read-only, denied locks, teardown\n";
}
