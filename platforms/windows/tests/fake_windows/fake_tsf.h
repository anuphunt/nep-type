#pragma once
#include <cstdint>
#include <cstring>
#define __declspec(x)
#define __stdcall
#define STDMETHODCALLTYPE
using HRESULT = std::int32_t;
using ULONG = std::uint32_t;
using BOOL = int;
using WPARAM = std::uintptr_t;
using LPARAM = std::intptr_t;
using TfClientId = std::uint32_t;
using TfEditCookie = std::uint32_t;
using DWORD = std::uint32_t;
using LONG = std::int32_t;
using WCHAR = char16_t;
enum TfAnchor { TF_ANCHOR_START, TF_ANCHOR_END };
enum TfActiveSelEnd { TFAE_NONE, TFAE_START, TFAE_END };
struct ITfRange;
struct TF_SELECTIONSTYLE { TfActiveSelEnd ase; BOOL fInterimChar; };
struct TF_SELECTION { ITfRange* range; TF_SELECTIONSTYLE style; };
constexpr ULONG TF_DEFAULT_SELECTION = 0xffffffffu;
constexpr DWORD TF_ES_SYNC = 1, TF_ES_READWRITE = 2;
constexpr TfClientId TF_CLIENTID_NULL = 0;
constexpr BOOL TRUE = 1, FALSE = 0;
constexpr HRESULT S_OK = 0, S_FALSE = 1;
constexpr HRESULT E_POINTER = static_cast<HRESULT>(0x80004003), E_NOINTERFACE = static_cast<HRESULT>(0x80004002), E_INVALIDARG = static_cast<HRESULT>(0x80070057), E_UNEXPECTED = static_cast<HRESULT>(0x8000ffff), E_OUTOFMEMORY = static_cast<HRESULT>(0x8007000e), E_FAIL = static_cast<HRESULT>(0x80004005), CLASS_E_NOAGGREGATION = static_cast<HRESULT>(0x80040110), CLASS_E_CLASSNOTAVAILABLE = static_cast<HRESULT>(0x80040111);
#define FAILED(hr) ((hr) < 0)
struct GUID { std::uint32_t Data1; std::uint16_t Data2, Data3; std::uint8_t Data4[8]; };
using REFGUID = const GUID&; using REFIID = const GUID&; using REFCLSID = const GUID&;
inline bool IsEqualIID(REFIID a, REFIID b) { return std::memcmp(&a,&b,sizeof(GUID)) == 0; }
inline bool IsEqualCLSID(REFCLSID a, REFCLSID b) { return IsEqualIID(a,b); }
inline constexpr GUID IID_IUnknown{1,0,0,{}}, IID_IClassFactory{2,0,0,{}}, IID_ITfTextInputProcessor{3,0,0,{}}, IID_ITfKeyEventSink{4,0,0,{}}, IID_ITfKeystrokeMgr{5,0,0,{}}, IID_ITfEditSession{6,0,0,{}}, IID_ITfContextComposition{7,0,0,{}};
struct IUnknown { virtual HRESULT QueryInterface(REFIID, void**) = 0; virtual ULONG AddRef() = 0; virtual ULONG Release() = 0; };
struct ITfEditSession : IUnknown { virtual HRESULT DoEditSession(TfEditCookie) = 0; };
struct ITfRange : IUnknown {
 virtual HRESULT IsEmpty(TfEditCookie, BOOL*) = 0;
 virtual HRESULT CompareStart(TfEditCookie, ITfRange*, TfAnchor, LONG*) = 0;
 virtual HRESULT GetText(TfEditCookie, DWORD, WCHAR*, ULONG, ULONG*) = 0;
 virtual HRESULT SetText(TfEditCookie, DWORD, const WCHAR*, LONG) = 0;
 virtual HRESULT Clone(ITfRange**) = 0;
 virtual HRESULT Collapse(TfEditCookie, TfAnchor) = 0;
};
struct ITfComposition : IUnknown { virtual HRESULT GetRange(ITfRange**) = 0; virtual HRESULT EndComposition(TfEditCookie) = 0; };
struct ITfContextComposition : IUnknown { virtual HRESULT StartComposition(TfEditCookie, ITfRange*, void*, ITfComposition**) = 0; };
struct ITfContext : IUnknown {
 virtual HRESULT RequestEditSession(TfClientId, ITfEditSession*, DWORD, HRESULT*) = 0;
 virtual HRESULT GetSelection(TfEditCookie, ULONG, ULONG, TF_SELECTION*, ULONG*) { return E_FAIL; }
 virtual HRESULT SetSelection(TfEditCookie, ULONG, const TF_SELECTION*) { return E_FAIL; }
};
struct ITfThreadMgr : IUnknown {};
struct ITfTextInputProcessor : IUnknown { virtual HRESULT Activate(ITfThreadMgr*, TfClientId) = 0; virtual HRESULT Deactivate() = 0; };
struct ITfKeyEventSink : IUnknown {
 virtual HRESULT OnSetFocus(BOOL) = 0;
 virtual HRESULT OnTestKeyDown(ITfContext*, WPARAM, LPARAM, BOOL*) = 0;
 virtual HRESULT OnTestKeyUp(ITfContext*, WPARAM, LPARAM, BOOL*) = 0;
 virtual HRESULT OnKeyDown(ITfContext*, WPARAM, LPARAM, BOOL*) = 0;
 virtual HRESULT OnKeyUp(ITfContext*, WPARAM, LPARAM, BOOL*) = 0;
 virtual HRESULT OnPreservedKey(ITfContext*, REFGUID, BOOL*) = 0;
};
struct ITfKeystrokeMgr : IUnknown { virtual HRESULT AdviseKeyEventSink(TfClientId, ITfKeyEventSink*, BOOL) = 0; virtual HRESULT UnadviseKeyEventSink(TfClientId) = 0; };
struct IClassFactory : IUnknown { virtual HRESULT CreateInstance(IUnknown*, REFIID, void**) = 0; virtual HRESULT LockServer(BOOL) = 0; };
