// Native Windows test: real Rich Edit controls, MSG dispatch and shared Rust DLL.
// The production event loop and actions are compiled here, not reimplemented.
#define NEPTYPE_PAD_SHORTCUT_TEST
#include "../main.cpp"
#include <cassert>
#include <chrono>
#include <functional>
#include <iostream>
#include <thread>

namespace {
HWND testWindow{};
void pump() {
    MSG message{};
    while(PeekMessageW(&message,nullptr,0,0,PM_REMOVE)) {
        if(message.message!=WM_QUIT) dispatchPadMessage(testWindow,message);
    }
}
void waitFor(const std::function<bool()>& predicate) {
    const auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(10);
    while(!predicate() && std::chrono::steady_clock::now()<deadline) {
        pump(); std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    assert(predicate());
}
void prepare(const wchar_t* value) {
    SetFocus(source);
    if(local) local->spellings.clear(); // independent cases; persistence has separate assertions
    // Let the shared composer observe Clear so a previous choice for the same
    // spelling cannot leak into the next independent key-event case.
    SetWindowTextW(source,L""); SendMessageW(source,EM_SETSEL,0,0); updateDocument();
    waitFor([] { return candidateView.ready && candidateView.generation==generation && editorText(result).empty(); });
    SetWindowTextW(source,value);
    const auto length=GetWindowTextLengthW(source);
    SendMessageW(source,EM_SETSEL,length,length);
    updateDocument();
    waitFor([] { return candidateView.ready && candidateView.generation==generation; });
}
void key(HWND editor, UINT value, bool ctrl=false, bool shift=false, bool alt=false, bool repeat=false) {
    BYTE previous[256]{}, state[256]{};
    assert(GetKeyboardState(previous));
    if(ctrl) state[VK_CONTROL]=state[VK_LCONTROL]=0x80;
    if(shift) state[VK_SHIFT]=state[VK_LSHIFT]=0x80;
    if(alt) state[VK_MENU]=state[VK_LMENU]=0x80;
    assert(SetKeyboardState(state));
    MSG event{}; event.hwnd=editor; event.message=WM_KEYDOWN; event.wParam=value;
    event.lParam=1 | (repeat ? (1LL<<30) : 0);
    dispatchPadMessage(testWindow,event);
    pump();
    assert(SetKeyboardState(previous));
}
}
int main() {
    const auto stateRoot=std::filesystem::temp_directory_path()/(L"NepType-shortcuts-"+std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(GetTickCount64()));
    assert(std::filesystem::create_directory(stateRoot));
    struct Cleanup { std::filesystem::path root; ~Cleanup() { std::error_code ec; std::filesystem::remove_all(root,ec); } } cleanup{stateRoot};
    assert(SetEnvironmentVariableW(L"LOCALAPPDATA",stateRoot.c_str()));
    std::filesystem::create_directory(stateRoot/L"NepType");
    { std::ofstream guide(stateRoot/L"NepType"/L"guide"); guide << "1"; }
    const auto richEdit=LoadLibraryW(L"Msftedit.dll"); assert(richEdit);
    INITCOMMONCONTROLSEX common{sizeof(common),ICC_WIN95_CLASSES}; InitCommonControlsEx(&common);
    backgroundBrush=CreateSolidBrush(background); surfaceBrush=CreateSolidBrush(surface);
    bodyFont=inputFont=outputFont=smallFont=brandFont=reinterpret_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
    WNDCLASSW type{}; type.lpfnWndProc=WindowProc; type.hInstance=GetModuleHandleW(nullptr);
    type.lpszClassName=L"NepTypeShortcutTest";
    assert(RegisterClassW(&type));
    testWindow=CreateWindowExW(0,type.lpszClassName,L"NepType shortcut test",WS_OVERLAPPEDWINDOW,
        0,0,720,540,nullptr,nullptr,type.hInstance,nullptr);
    assert(testWindow); ShowWindow(testWindow,SW_SHOWNOACTIVATE); SetActiveWindow(testWindow);

    prepare(L"pani");
    assert(editorText(result)==L"पनि");
    assert(editorText(suggestions[1])==L"पानी  Ctrl+2");
    key(source,'2',true);
    waitFor([] { return candidateView.ready && editorText(result)==L"पानी"; });
    assert(editorText(source)==L"pani");
    assert(local && local->spellings.at("pani")=="पानी");
    assert(local->save());
    const neptype::LocalExperience restored(stateRoot/L"NepType");
    assert(restored.spellings.at("pani")=="पानी");

    prepare(L"pani");
    SendMessageW(source,EM_SETSEL,0,4);
    waitFor([] { return candidateView.ready && candidateView.selectionStart==0; });
    key(source,'2',true);
    waitFor([] { return candidateView.ready && editorText(result)==L"पानी"; });
    assert(editorText(source)==L"pani");
    assert(shownCandidates[0]=="पानी"); // the remembered alternative moves to slot 1
    key(source,'1',true);
    waitFor([] { return candidateView.ready && editorText(result)==L"पानी"; });
    key(source,'2',true);
    waitFor([] { return candidateView.ready && editorText(result)==L"पनि"; });
    key(source,'3',true);
    waitFor([] { return candidateView.ready && editorText(result)==L"pani"; });

    prepare(L"pani");
    SetFocus(result); key(result,'2',true);
    waitFor([] { return candidateView.ready && editorText(result)==L"पानी"; });
    assert(editorText(source)==L"pani");

    prepare(L"pani");
    const auto beforeRepeat=generation;
    key(source,'2',true,false,false,true);
    assert(generation==beforeRepeat && editorText(result)==L"पनि");
    updateDocument(); const auto pending=generation;
    key(source,'2',true);
    assert(generation==pending); // key cannot submit a stale choice during lookup
    waitFor([] { return candidateView.ready; });

    prepare(L"pani");
    const auto oldGeneration=generation;
    SendMessageW(source,EM_SETEVENTMASK,0,0);
    SendMessageW(source,EM_SETSEL,0,0); // notification deliberately delayed
    key(source,'2',true);
    assert(generation==oldGeneration && editorText(result)==L"पनि");
    SetWindowTextW(source,L"mero");
    key(source,'2',true);
    assert(generation==oldGeneration && editorText(source)==L"mero");
    SendMessageW(source,EM_SETEVENTMASK,0,ENM_CHANGE|ENM_SELCHANGE);

    prepare(L"pani");
    SendMessageW(source,WM_IME_STARTCOMPOSITION,0,0);
    const auto composingGeneration=generation;
    key(source,'2',true);
    assert(sourceComposing && generation==composingGeneration && editorText(source)==L"pani");
    SendMessageW(source,WM_IME_ENDCOMPOSITION,0,0);
    assert(!sourceComposing);

    prepare(L"");
    PARAFORMAT2 before{},after{}; before.cbSize=sizeof(before); after.cbSize=sizeof(after);
    SendMessageW(source,EM_GETPARAFORMAT,0,reinterpret_cast<LPARAM>(&before));
    key(source,'2',true);
    SendMessageW(source,EM_GETPARAFORMAT,0,reinterpret_cast<LPARAM>(&after));
    assert(editorText(source).empty() && before.dyLineSpacing==after.dyLineSpacing
        && before.bLineSpacingRule==after.bLineSpacingRule);

    prepare(L"pani");
    key(source,'A',true);
    DWORD start=0,end=0; SendMessageW(source,EM_GETSEL,reinterpret_cast<WPARAM>(&start),reinterpret_cast<LPARAM>(&end));
    assert(start==0 && end==4); // normal Rich Edit editing command still works
    key(source,'7');
    waitFor([] { return editorText(source)==L"7"; });
    key(source,VK_BACK);
    waitFor([] { return editorText(source).empty(); });

    DestroyWindow(testWindow); pump();
    DeleteObject(backgroundBrush); DeleteObject(surfaceBrush); FreeLibrary(richEdit);
    std::cout << "Native Rich Edit shortcut, staleness, composition and editing checks passed\n";
}
