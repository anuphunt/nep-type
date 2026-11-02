#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>
#include <richedit.h>
#include <algorithm>
#include <cstring>
#include <initializer_list>
#include <string>
#include <atomic>
#include <memory>
#include "../../shared/cpp/pad_worker.hpp"

// Standalone Graphite UI. The dormant TSF service is deliberately not activated.
namespace {
constexpr COLORREF background = RGB(30,30,30), surface = RGB(39,39,39);
constexpr COLORREF ink = RGB(232,232,232), muted = RGB(170,170,170);
constexpr COLORREF line = RGB(61,61,61), silver = RGB(215,215,215);
constexpr int inputID = 101, outputID = 102, clearID = 103, copyID = 104;
constexpr int mixedID = 105, nepaliID = 106, helpID = 107;
HWND source{}, result{}, sourceLabel{}, resultLabel{}, statusLabel{};
HWND clearButton{}, copyButton{}, mixedButton{}, nepaliButton{}, helpButton{};
HFONT bodyFont{}, inputFont{}, outputFont{}, smallFont{}, brandFont{};
HBRUSH backgroundBrush{}, surfaceBrush{};
int dpi = 96;
bool copied = false;
constexpr UINT engineMessage = WM_APP + 18;
struct PadMessage { uint64_t generation; neptype::Document document; bool success; };
std::unique_ptr<neptype::PadWorker> worker;
std::shared_ptr<std::atomic<bool>> windowAlive;
uint64_t generation = 0;
int32_t outputMode = 0;
HWND suggestions[3]{};
std::vector<std::string> shownCandidates;
std::wstring shownSource;
std::string utf8(const std::wstring& value) {
    if(value.empty()) return {};
    int n=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,value.data(),static_cast<int>(value.size()),nullptr,0,nullptr,nullptr);
    if(n<=0) throw std::runtime_error("Invalid UTF-16");
    std::string out(n,'\0');
    WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,value.data(),static_cast<int>(value.size()),out.data(),n,nullptr,nullptr);
    return out;
}
std::wstring wide(const std::string& value) {
    if(value.empty()) return {};
    int n=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,value.data(),static_cast<int>(value.size()),nullptr,0);
    if(n<=0) throw std::runtime_error("Invalid UTF-8");
    std::wstring out(n,L'\0');
    MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,value.data(),static_cast<int>(value.size()),out.data(),n);
    return out;
}
std::wstring editorText(HWND editor) {
    int size=GetWindowTextLengthW(editor);
    std::wstring text(size+1,L'\0'); GetWindowTextW(editor,text.data(),size+1); text.resize(size); return text;
}
std::string setting(const wchar_t* name, const std::filesystem::path& fallback) {
    wchar_t buffer[32768]{};
    DWORD n=GetEnvironmentVariableW(name,buffer,32768);
    return utf8(n>0 && n<32768 ? std::wstring(buffer,n) : fallback.wstring());
}
void updateDocument(const char* choice=nullptr) {
    if(!worker) return;
    try {
        auto text=editorText(source);
        DWORD start=0, end=0; SendMessageW(source,EM_GETSEL,reinterpret_cast<WPARAM>(&start),reinterpret_cast<LPARAM>(&end));
        ++generation; copied=false;
        for(auto button:suggestions) EnableWindow(button,FALSE);
        EnableWindow(copyButton,FALSE);
        worker->submit(generation,utf8(text),outputMode,static_cast<int32_t>(end),choice);
    } catch(...) { SetWindowTextW(statusLabel,L"Shared engine rejected text"); }
}
int px(int value) { return MulDiv(value, dpi, 96); }
HFONT font(int size, const wchar_t* family) {
    return CreateFontW(-px(size),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,
                       OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,family);
}
RECT sourceRect{}, resultRect{};
void place(HWND control, int x, int y, int width, int height) {
    MoveWindow(control,px(x),px(y),px(width),px(height),TRUE);
}
void layout(HWND window) {
    RECT client{}; GetClientRect(window,&client);
    const int width = MulDiv(client.right,96,dpi), height = MulDiv(client.bottom,96,dpi);
    sourceRect = {px(16),px(60),px(width-16),px(168)};
    resultRect = {px(16),px(226),px(width-16),px(height-46)};
    place(sourceLabel,28,60,width-110,36);
    place(resultLabel,28,226,width-110,36);
    place(statusLabel,18,height-34,width-34,22);
    place(source,28,102,width-56,54);
    place(result,28,268,width-56,std::max(52,height-326));
    place(clearButton,width-70,62,44,32);
    place(copyButton,width-66,228,36,32);
    place(mixedButton,width-215,16,86,28);
    place(nepaliButton,width-129,16,76,28);
    place(helpButton,width-46,12,30,36);
    const int suggestionWidth=(width-44)/3;
    for(int i=0;i<3;++i) place(suggestions[i],16+i*(suggestionWidth+6),180,suggestionWidth,34);
    InvalidateRect(window,nullptr,FALSE);
}
void text(HDC dc, const wchar_t* value, RECT rect, HFONT type, COLORREF color, UINT align=DT_LEFT) {
    const auto previous = SelectObject(dc,type);
    SetTextColor(dc,color); SetBkMode(dc,TRANSPARENT);
    DrawTextW(dc,value,-1,&rect,align|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS);
    SelectObject(dc,previous);
}
void panel(HDC dc, RECT rect) {
    const auto pen = CreatePen(PS_SOLID,1,line);
    const auto oldPen = SelectObject(dc,pen), oldBrush = SelectObject(dc,surfaceBrush);
    RoundRect(dc,rect.left,rect.top,rect.right,rect.bottom,px(18),px(18));
    MoveToEx(dc,rect.left+1,rect.top+px(36),nullptr);
    LineTo(dc,rect.right-1,rect.top+px(36));
    SelectObject(dc,oldBrush); SelectObject(dc,oldPen); DeleteObject(pen);
}
HWND control(HWND parent, const wchar_t* kind, const wchar_t* title, DWORD style, int id) {
    return CreateWindowExW(0,kind,title,WS_CHILD|WS_VISIBLE|style,0,0,0,0,parent,
                          reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);
}
void configureEditor(HWND editor, HFONT type) {
    SendMessageW(editor,WM_SETFONT,reinterpret_cast<WPARAM>(type),TRUE);
    SendMessageW(editor,EM_SETTEXTMODE,TM_PLAINTEXT,0);
    SendMessageW(editor,EM_SETBKGNDCOLOR,0,surface);
    CHARFORMAT2W format{}; format.cbSize=sizeof(format); format.dwMask=CFM_COLOR; format.crTextColor=ink;
    SendMessageW(editor,EM_SETCHARFORMAT,SCF_ALL,reinterpret_cast<LPARAM>(&format));
    SendMessageW(editor,EM_SETLIMITTEXT,1024*1024,0);
}
void addTip(HWND parent, HWND target, const wchar_t* label) {
    HWND tooltip = CreateWindowExW(WS_EX_TOPMOST,TOOLTIPS_CLASSW,nullptr,WS_POPUP|TTS_ALWAYSTIP,
                                  CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,parent,nullptr,nullptr,nullptr);
    TOOLINFOW info{}; info.cbSize=sizeof(info); info.hwnd=parent;
    info.uFlags=TTF_IDISHWND|TTF_SUBCLASS; info.uId=reinterpret_cast<UINT_PTR>(target);
    info.lpszText=const_cast<wchar_t*>(label);
    SendMessageW(tooltip,TTM_ADDTOOLW,0,reinterpret_cast<LPARAM>(&info));
}
void copyOutput(HWND window) {
    const int length=GetWindowTextLengthW(result);
    if(length==0) return;
    std::wstring value(static_cast<size_t>(length)+1,L'\0');
    GetWindowTextW(result,value.data(),length+1);
    const SIZE_T bytes=(static_cast<SIZE_T>(length)+1)*sizeof(wchar_t);
    HGLOBAL memory=GlobalAlloc(GMEM_MOVEABLE,bytes);
    if(!memory) return;
    void* buffer=GlobalLock(memory);
    if(!buffer) { GlobalFree(memory); return; }
    std::memcpy(buffer,value.c_str(),bytes); GlobalUnlock(memory);
    if(!OpenClipboard(window)) { GlobalFree(memory); return; }
    bool success=false;
    if(EmptyClipboard()) success=SetClipboardData(CF_UNICODETEXT,memory)!=nullptr;
    CloseClipboard();
    if(!success) { GlobalFree(memory); return; }
    copied=true; InvalidateRect(copyButton,nullptr,TRUE); SetTimer(window,1,1800,nullptr);
}
LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch(message) {
    case WM_CREATE: {
        sourceLabel=control(window,L"STATIC",L"Roman input",SS_CENTERIMAGE,108);
        source=control(window,MSFTEDIT_CLASS,L"",WS_TABSTOP|ES_MULTILINE|ES_AUTOVSCROLL|ES_WANTRETURN|WS_VSCROLL,inputID);
        resultLabel=control(window,L"STATIC",L"नेपाली",SS_CENTERIMAGE,109);
        result=control(window,MSFTEDIT_CLASS,L"",WS_TABSTOP|ES_MULTILINE|ES_READONLY|ES_AUTOVSCROLL|WS_VSCROLL,outputID);
        if(!source || !result) return -1;
        configureEditor(source,inputFont); configureEditor(result,outputFont);
        statusLabel=control(window,L"STATIC",L"Loading shared offline engine…",SS_CENTERIMAGE,110);
        for(auto label:{sourceLabel,resultLabel,statusLabel}) SendMessageW(label,WM_SETFONT,reinterpret_cast<WPARAM>(smallFont),TRUE);
        clearButton=control(window,L"BUTTON",L"Clear",WS_TABSTOP|BS_OWNERDRAW,clearID);
        copyButton=control(window,L"BUTTON",L"Copy text",WS_TABSTOP|BS_OWNERDRAW,copyID);
        mixedButton=control(window,L"BUTTON",L"Nepali + EN",BS_OWNERDRAW,mixedID);
        nepaliButton=control(window,L"BUTTON",L"All Nepali",BS_OWNERDRAW,nepaliID);
        helpButton=control(window,L"BUTTON",L"?",WS_TABSTOP|BS_OWNERDRAW,helpID);
        EnableWindow(copyButton,FALSE);
        for(int i=0;i<3;++i) {
            suggestions[i]=control(window,L"BUTTON",L"",WS_TABSTOP|BS_OWNERDRAW,201+i);
            EnableWindow(suggestions[i],FALSE);
        }
        SendMessageW(source,EM_SETEVENTMASK,0,ENM_CHANGE|ENM_SELCHANGE);
        wchar_t executable[32768]{}; GetModuleFileNameW(nullptr,executable,32768);
        auto directory=std::filesystem::path(executable).parent_path();
        windowAlive=std::make_shared<std::atomic<bool>>(true);
        worker=std::make_unique<neptype::PadWorker>(
            setting(L"NEPTYPE_ENGINE_LIBRARY",directory/L"NepTypeEngine.dll"),
            setting(L"NEPTYPE_DICTIONARY_DIR",directory/L"dictionaries"),
            [window,alive=windowAlive](uint64_t id, neptype::Document doc, bool success) {
                if(!alive->load()) return;
                auto message=new PadMessage{id,std::move(doc),success};
                if(!PostMessageW(window,engineMessage,0,reinterpret_cast<LPARAM>(message))) delete message;
            });
        addTip(window,copyButton,L"Copy text"); addTip(window,helpButton,L"About this typing pad");
        layout(window); SetFocus(source); updateDocument(); return 0;
    }
    case WM_SIZE: layout(window); return 0;
    case WM_GETMINMAXINFO: {
        auto info=reinterpret_cast<MINMAXINFO*>(lParam);
        RECT minimum{0,0,px(520),px(398)};
        AdjustWindowRectEx(&minimum,WS_OVERLAPPEDWINDOW,FALSE,0);
        info->ptMinTrackSize={minimum.right-minimum.left,minimum.bottom-minimum.top}; return 0;
    }
    case WM_ERASEBKGND: return 1;
    case WM_PAINT: {
        PAINTSTRUCT paint{}; HDC dc=BeginPaint(window,&paint);
        RECT client{}; GetClientRect(window,&client); FillRect(dc,&client,backgroundBrush);
        panel(dc,sourceRect); panel(dc,resultRect);
        DrawIconEx(dc,px(16),px(14),LoadIconW(GetModuleHandleW(nullptr),MAKEINTRESOURCEW(101)),
                   px(32),px(32),0,nullptr,DI_NORMAL);
        text(dc,L"NepType",{px(72),px(12),px(132),px(48)},bodyFont,ink);
        EndPaint(window,&paint); return 0;
    }
    case WM_CTLCOLORSTATIC: {
        HDC dc=reinterpret_cast<HDC>(wParam);
        const bool inPanel=reinterpret_cast<HWND>(lParam)!=statusLabel;
        SetTextColor(dc,muted); SetBkColor(dc,inPanel?surface:background);
        return reinterpret_cast<LRESULT>(inPanel?surfaceBrush:backgroundBrush);
    }
    case WM_DRAWITEM: {
        const auto item=reinterpret_cast<DRAWITEMSTRUCT*>(lParam);
        HDC dc=item->hDC;
        const bool inPanel=item->CtlID==clearID || item->CtlID==copyID;
        FillRect(dc,&item->rcItem,inPanel?surfaceBrush:backgroundBrush);
        if(item->CtlID==copyID) {
            HPEN pen=CreatePen(PS_SOLID,px(1),(item->itemState&ODS_DISABLED)?RGB(105,105,105):muted);
            auto oldPen=SelectObject(dc,pen), oldBrush=SelectObject(dc,GetStockObject(HOLLOW_BRUSH));
            const int x=(item->rcItem.right-px(13))/2, y=(item->rcItem.bottom-px(15))/2;
            if(copied) { MoveToEx(dc,x,y+px(8),nullptr); LineTo(dc,x+px(4),y+px(12)); LineTo(dc,x+px(13),y+px(2)); }
            else { Rectangle(dc,x+px(4),y,x+px(13),y+px(11)); Rectangle(dc,x,y+px(4),x+px(9),y+px(15)); }
            SelectObject(dc,oldPen); SelectObject(dc,oldBrush); DeleteObject(pen);
        } else {
            std::wstring title(static_cast<size_t>(GetWindowTextLengthW(item->hwndItem))+1,L'\0');
            GetWindowTextW(item->hwndItem,title.data(),static_cast<int>(title.size()));
            if((item->CtlID==mixedID && outputMode==0) || (item->CtlID==nepaliID && outputMode==2)) FillRect(dc,&item->rcItem,surfaceBrush);
            text(dc,title.c_str(),item->rcItem,smallFont,muted,DT_CENTER);
        }
        if(item->itemState&ODS_FOCUS) { RECT focus=item->rcItem; InflateRect(&focus,-2,-2); DrawFocusRect(dc,&focus); }
        return TRUE;
    }
    case engineMessage: {
        std::unique_ptr<PadMessage> reply(reinterpret_cast<PadMessage*>(lParam));
        if(!reply || reply->generation!=generation) return 0;
        SetWindowTextW(result,reply->success ? wide(reply->document.output).c_str() : L"");
        SetWindowTextW(statusLabel,reply->success ? L"Local · Shared offline engine" : L"Shared engine unavailable · Check library and dictionaries");
        shownSource=editorText(source);
        shownCandidates=reply->document.candidates;
        for(int i=0;i<3;++i) {
            bool present=reply->success && i<static_cast<int>(shownCandidates.size());
            SetWindowTextW(suggestions[i],present ? wide(shownCandidates[i]).c_str() : L"");
            EnableWindow(suggestions[i],present);
        }
        EnableWindow(copyButton,reply->success && !reply->document.output.empty());
        return 0;
    }
    case WM_NOTIFY:
        if(reinterpret_cast<NMHDR*>(lParam)->hwndFrom==source && reinterpret_cast<NMHDR*>(lParam)->code==EN_SELCHANGE) updateDocument();
        return 0;
    case WM_COMMAND:
        if(LOWORD(wParam)==inputID && HIWORD(wParam)==EN_CHANGE) updateDocument();
        if(LOWORD(wParam)==mixedID) { outputMode=0; InvalidateRect(mixedButton,nullptr,TRUE); InvalidateRect(nepaliButton,nullptr,TRUE); updateDocument(); }
        if(LOWORD(wParam)==nepaliID) { outputMode=2; InvalidateRect(mixedButton,nullptr,TRUE); InvalidateRect(nepaliButton,nullptr,TRUE); updateDocument(); }
        if(LOWORD(wParam)>=201 && LOWORD(wParam)<=203 && shownSource==editorText(source)) {
            size_t i=LOWORD(wParam)-201;
            if(i<shownCandidates.size()) updateDocument(shownCandidates[i].c_str());
        }
        if(LOWORD(wParam)==clearID) { SetWindowTextW(source,L""); SetWindowTextW(result,L""); copied=false; EnableWindow(copyButton,FALSE); SetFocus(source); }
        if(LOWORD(wParam)==copyID) copyOutput(window);
        if(LOWORD(wParam)==helpID) MessageBoxW(window,L"This standalone typing-pad preview uses the Graphite layout.\n\nUses the shared offline Swift engine and canonical dictionaries. The keyboard service is not installed or enabled.",L"NepType",MB_OK|MB_ICONINFORMATION);
        return 0;
    case WM_TIMER: copied=false; KillTimer(window,1); InvalidateRect(copyButton,nullptr,TRUE); return 0;
    case WM_DESTROY: {
        if(windowAlive) windowAlive->store(false);
        worker.reset();
        MSG pending{};
        while(PeekMessageW(&pending,window,engineMessage,engineMessage,PM_REMOVE))
            delete reinterpret_cast<PadMessage*>(pending.lParam);
        PostQuitMessage(0); return 0;
    }
    default: return DefWindowProcW(window,message,wParam,lParam);
    }
}
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int show) {
    SetProcessDPIAware();
    const auto dc=GetDC(nullptr); dpi=GetDeviceCaps(dc,LOGPIXELSX); ReleaseDC(nullptr,dc);
    HMODULE richEdit=LoadLibraryW(L"Msftedit.dll"); if(!richEdit) return 1;
    INITCOMMONCONTROLSEX common{sizeof(common),ICC_WIN95_CLASSES}; InitCommonControlsEx(&common);
    backgroundBrush=CreateSolidBrush(background); surfaceBrush=CreateSolidBrush(surface);
    bodyFont=font(13,L"Segoe UI"); smallFont=font(11,L"Segoe UI");
    inputFont=font(18,L"Consolas"); outputFont=font(24,L"Nirmala UI"); brandFont=font(25,L"Nirmala UI");
    WNDCLASSW type{}; type.lpfnWndProc=WindowProc; type.hInstance=instance;
    type.lpszClassName=L"NepTypePrototypeWindow"; type.hCursor=LoadCursor(nullptr,IDC_ARROW);
    type.hbrBackground=backgroundBrush;
    type.hIcon=LoadIconW(instance,MAKEINTRESOURCEW(101));
    if(!RegisterClassW(&type)) return 1;
    RECT size{0,0,px(620),px(430)}; AdjustWindowRectEx(&size,WS_OVERLAPPEDWINDOW,FALSE,0);
    HWND window=CreateWindowExW(0,type.lpszClassName,L"NepType · Typing pad",WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,CW_USEDEFAULT,size.right-size.left,size.bottom-size.top,nullptr,nullptr,instance,nullptr);
    if(!window) return 1;
    HMODULE dwm=LoadLibraryW(L"dwmapi.dll");
    if(dwm) {
        using SetAttribute=HRESULT(WINAPI*)(HWND,DWORD,LPCVOID,DWORD);
        auto setAttribute=reinterpret_cast<SetAttribute>(GetProcAddress(dwm,"DwmSetWindowAttribute"));
        const BOOL dark=TRUE; if(setAttribute) setAttribute(window,20,&dark,sizeof(dark));
        FreeLibrary(dwm);
    }
    ShowWindow(window,show); UpdateWindow(window);
    MSG message{}; int code=0;
    while((code=GetMessageW(&message,nullptr,0,0))>0) { if(!IsDialogMessageW(window,&message)) { TranslateMessage(&message); DispatchMessageW(&message); } }
    for(auto handle:{bodyFont,inputFont,outputFont,smallFont,brandFont}) DeleteObject(handle);
    DeleteObject(backgroundBrush); DeleteObject(surfaceBrush); FreeLibrary(richEdit);
    return code<0?1:static_cast<int>(message.wParam);
}
