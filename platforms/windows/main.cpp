#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <commctrl.h>
#include <richedit.h>
#include <commdlg.h>
#include <shellapi.h>
#include "../../shared/cpp/local_experience.hpp"
#include <algorithm>
#include <cstring>
#include <initializer_list>
#include <string>
#include <atomic>
#include <memory>
#include "../../shared/cpp/pad_worker.hpp"
#include "include/pad_candidate_view.hpp"

// Standalone typing pad. This preview does not install the experimental TSF keyboard.
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
HWND tools[6]{};
HWND keyboardSetupLink{}, keyboardSetupInfo{};
std::unique_ptr<neptype::LocalExperience> local;
std::string shownToken;
std::vector<std::string> shownCandidates;
neptype::PadCandidateView candidateView;
std::wstring requestedSource;
DWORD requestedStart = 0, requestedEnd = 0;
bool sourceComposing = false, resultComposing = false;
constexpr const wchar_t* suggestionHints[]={L"Choose visible suggestion · Ctrl+1",
    L"Choose visible suggestion · Ctrl+2",L"Choose visible suggestion · Ctrl+3"};
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
        candidateView.ready=false; shownCandidates.clear();
        requestedSource=text; requestedStart=start; requestedEnd=end;
        for(auto button:suggestions) EnableWindow(button,FALSE);
        EnableWindow(copyButton,FALSE);
        worker->submit(generation,utf8(text),outputMode,static_cast<int32_t>(end),choice,local?local->preferences():"{}");
        SetTimer(GetParent(source),2,400,nullptr);
    } catch(...) { SetWindowTextW(statusLabel,L"Shared engine rejected text"); }
}
void chooseCandidate(size_t index) {
    DWORD start=0, end=0;
    SendMessageW(source,EM_GETSEL,reinterpret_cast<WPARAM>(&start),reinterpret_cast<LPARAM>(&end));
    if(sourceComposing || resultComposing || index>=3 || index>=shownCandidates.size()
        || !IsWindowEnabled(suggestions[index])
        || !candidateView.matches(generation,editorText(source),start,end)) return;
    const auto choice=shownCandidates[index]; // updateDocument invalidates the displayed row.
    if(local) local->save_word(shownToken,choice,shownCandidates);
    updateDocument(choice.c_str());
}
LRESULT CALLBACK EditorProc(HWND editor, UINT message, WPARAM wParam, LPARAM lParam,
                            UINT_PTR, DWORD_PTR) {
    bool& composing=editor==source ? sourceComposing : resultComposing;
    if(message==WM_IME_STARTCOMPOSITION) composing=true;
    if(message==WM_IME_ENDCOMPOSITION) composing=false;
    return DefSubclassProc(editor,message,wParam,lParam);
}
bool consumeCandidateShortcut(const MSG& message) {
    if(message.message!=WM_KEYDOWN || (message.hwnd!=source && message.hwnd!=result)
        || GetFocus()!=message.hwnd || !(GetKeyState(VK_CONTROL)&0x8000)
        || (GetKeyState(VK_MENU)&0x8000) || (GetKeyState(VK_SHIFT)&0x8000)
        || (GetKeyState(VK_LWIN)&0x8000) || (GetKeyState(VK_RWIN)&0x8000)) return false;
    const auto key=message.wParam;
    const int index=key>='1' && key<='3' ? static_cast<int>(key-'1')
        : key>=VK_NUMPAD1 && key<=VK_NUMPAD3 ? static_cast<int>(key-VK_NUMPAD1) : -1;
    if(index<0) return false;
    // Reserve these pad commands even when unavailable. Do not let Rich Edit
    // interpret Ctrl+1/2 as paragraph formatting, or repeat a held selection.
    if(!(message.lParam&(1LL<<30))) chooseCandidate(static_cast<size_t>(index));
    return true;
}
void dispatchPadMessage(HWND window, MSG& message) {
    if(!consumeCandidateShortcut(message) && !IsDialogMessageW(window,&message)) {
        TranslateMessage(&message); DispatchMessageW(&message);
    }
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
    sourceRect = {px(16),px(136),px(width-16),px(244)};
    resultRect = {px(16),px(302),px(width-16),px(height-46)};
    place(sourceLabel,28,136,width-110,36);
    place(resultLabel,28,302,width-110,36);
    place(statusLabel,18,height-34,width-34,22);
    place(source,28,178,width-56,54);
    place(result,28,344,width-56,std::max(52,height-402));
    place(clearButton,width-70,138,44,32);
    place(copyButton,width-66,304,36,32);
    place(mixedButton,width-253,16,86,28);
    place(nepaliButton,width-167,16,76,28);
    place(tools[2],width-84,12,30,36);
    place(helpButton,width-46,12,30,36);
    const int suggestionWidth=(width-44)/3;
    for(int i=0;i<3;++i) place(suggestions[i],16+i*(suggestionWidth+6),256,suggestionWidth,34);
    const int actionWidth=(width-32)/3;
    place(tools[0],16,54,actionWidth-3,28);
    place(tools[1],16+actionWidth,54,actionWidth-3,28);
    place(tools[3],16+2*actionWidth,54,actionWidth-3,28);
    place(keyboardSetupLink,16,88,width-76,30);
    place(keyboardSetupInfo,width-50,88,34,30);
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
        if(!SetWindowSubclass(source,EditorProc,1,0) || !SetWindowSubclass(result,EditorProc,1,0)) return -1;
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
            addTip(window,suggestions[i],suggestionHints[i]);
        }
        const wchar_t* titles[]={L"Keyboard setup",L"Try typing",L"↗",L"More",L"",L""};
        for(int i=0;i<4;++i){tools[i]=control(window,L"BUTTON",titles[i],WS_TABSTOP|BS_PUSHBUTTON,301+i);SendMessageW(tools[i],WM_SETFONT,reinterpret_cast<WPARAM>(smallFont),TRUE);}
        keyboardSetupLink=control(window,L"BUTTON",L"NepType for your Windows keyboard - setup",WS_TABSTOP|BS_PUSHBUTTON,307);
        keyboardSetupInfo=control(window,L"BUTTON",L"ⓘ",WS_TABSTOP|BS_PUSHBUTTON,308);
        SendMessageW(keyboardSetupLink,WM_SETFONT,reinterpret_cast<WPARAM>(smallFont),TRUE);
        addTip(window,keyboardSetupInfo,L"How to add a keyboard on Windows");
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
        addTip(window,copyButton,L"Copy text"); addTip(window,helpButton,L"About this typing pad"); addTip(window,tools[2],L"Save output to share");
        wchar_t appData[32768]{};
        DWORD length=GetEnvironmentVariableW(L"LOCALAPPDATA",appData,32768);
        local=std::make_unique<neptype::LocalExperience>(length>0&&length<32768?std::filesystem::path(appData)/L"NepType":std::filesystem::path{});
        outputMode=local->mode;try{SetWindowTextW(source,wide(local->source).c_str());}catch(...){local->source.clear();SetWindowTextW(source,L"");}
        SendMessageW(source,EM_SETSEL,static_cast<WPARAM>(-1),static_cast<LPARAM>(-1));

        layout(window); SetFocus(source); updateDocument();
        if(!local->guide_seen)PostMessageW(window,WM_COMMAND,301,0);
        return 0;
    }
    case WM_SIZE: layout(window); return 0;
    case WM_GETMINMAXINFO: {
        auto info=reinterpret_cast<MINMAXINFO*>(lParam);
        RECT minimum{0,0,px(560),px(490)};
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
        shownToken=reply->document.token;
        candidateView={reply->generation,requestedSource,requestedStart,requestedEnd,
            reply->document.start,reply->document.length,reply->success};
        shownCandidates=neptype::visible_pad_candidates(reply->document.candidates, reply->document.token);
        for(int i=0;i<3;++i) {
            bool present=reply->success && i<static_cast<int>(shownCandidates.size());
            const auto title=present ? wide(shownCandidates[i])+L"  Ctrl+"+std::to_wstring(i+1) : L"";
            SetWindowTextW(suggestions[i],title.c_str());
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
        if(LOWORD(wParam)>=201 && LOWORD(wParam)<=203) chooseCandidate(LOWORD(wParam)-201);
        if(LOWORD(wParam)==clearID) { SetWindowTextW(source,L""); SetWindowTextW(result,L""); copied=false; EnableWindow(copyButton,FALSE); SetFocus(source); }
        if(LOWORD(wParam)==copyID) copyOutput(window);
        if(LOWORD(wParam)==301 || LOWORD(wParam)==307 || LOWORD(wParam)==308 || LOWORD(wParam)==helpID) {
            if(local){local->guide_seen=true;local->save();}
            const int answer=MessageBoxW(window,L"NepType’s Windows system keyboard is still in development. This version can type and copy Nepali in the pad, but cannot yet install NepType for typing in other apps.\n\nIn this pad, Ctrl+1–3 chooses a visible suggestion.\n\nFor installed keyboards:\n1. Open Settings > Time & language > Language & region.\n2. Open Language options for the language, then Keyboards > Add a keyboard.\n3. Press Windows+Space to choose an installed keyboard.\n\nNepType will appear only after a working NepType keyboard installer is released. Adding a built-in Nepali layout does not add NepType’s Roman-to-Nepali conversion.\n\nOpen Windows language settings now?",L"NepType keyboard setup",MB_YESNO|MB_ICONINFORMATION|MB_DEFBUTTON2);
            if(answer==IDYES) {
                const auto opened=reinterpret_cast<INT_PTR>(ShellExecuteW(window,L"open",L"ms-settings:regionlanguage",nullptr,nullptr,SW_SHOWNORMAL));
                if(opened<=32)MessageBoxW(window,L"Open Windows Settings manually, then Time & language > Language & region.",L"Open keyboard settings",MB_OK|MB_ICONINFORMATION);
            }
        }
        if(LOWORD(wParam)==302){SetWindowTextW(statusLabel,L"Try: ma office janchu - Your draft stays here");SetFocus(source);}
        if(LOWORD(wParam)==304){
            HMENU menu=CreatePopupMenu();AppendMenuW(menu,MF_STRING,305,L"Report a typing problem");
            RECT rect{};GetWindowRect(tools[3],&rect);
            const UINT choice=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_RIGHTALIGN,rect.right,rect.bottom,0,window,nullptr);
            DestroyMenu(menu);if(choice==305)PostMessageW(window,WM_COMMAND,305,0);
        }
        if(LOWORD(wParam)==305)ShellExecuteW(window,L"open",L"https://github.com/anuphunt/nep-type/issues/new?template=typing-problem.yml",nullptr,nullptr,SW_SHOWNORMAL);
        if(LOWORD(wParam)==303){
            wchar_t path[32768]=L"NepType.txt";
            OPENFILENAMEW file{};file.lStructSize=sizeof(file);file.hwndOwner=window;file.lpstrFile=path;file.nMaxFile=32768;file.lpstrFilter=L"Text files\0*.txt\0\0";file.lpstrDefExt=L"txt";file.Flags=OFN_OVERWRITEPROMPT|OFN_PATHMUSTEXIST;
            if(GetSaveFileNameW(&file)){std::ofstream out(std::filesystem::path(path),std::ios::binary);auto value=utf8(editorText(result));out.write(value.data(),value.size());SetWindowTextW(statusLabel,out?L"Output saved - Share the file from Explorer":L"Output could not be saved");}
        }
        return 0;
    case WM_TIMER:
        if(wParam==2){KillTimer(window,2);if(local){local->source=utf8(editorText(source));local->mode=outputMode;if(!local->save())SetWindowTextW(statusLabel,L"Draft could not be saved - Copy text you need");}return 0;}
        copied=false; KillTimer(window,1); InvalidateRect(copyButton,nullptr,TRUE); return 0;
    case WM_DESTROY: {
        if(local){local->source=utf8(editorText(source));local->mode=outputMode;local->save();}
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
#ifndef NEPTYPE_PAD_SHORTCUT_TEST
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
    RECT size{0,0,px(680),px(500)}; AdjustWindowRectEx(&size,WS_OVERLAPPEDWINDOW,FALSE,0);
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
    while((code=GetMessageW(&message,nullptr,0,0))>0) dispatchPadMessage(window,message);
    for(auto handle:{bodyFont,inputFont,outputFont,smallFont,brandFont}) DeleteObject(handle);
    DeleteObject(backgroundBrush); DeleteObject(surfaceBrush); FreeLibrary(richEdit);
    return code<0?1:static_cast<int>(message.wParam);
}
#endif
