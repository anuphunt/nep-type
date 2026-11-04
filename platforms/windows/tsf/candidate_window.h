#pragma once
#include "windows_support.h"
#include <vector>
#include <algorithm>

namespace neptype::tsf {
// No activation, hooks, clipboard access or typed-text logging. Standard STATIC
// controls expose the visible choices to Windows accessibility clients.
class CandidateWindow {
public:
    ~CandidateWindow() { hide(); }
    void hide() { if (window_) DestroyWindow(window_); window_ = nullptr; }
    void show(ITfContext* context, TfEditCookie cookie,
              const std::vector<std::u16string>& choices, std::size_t selected, int mode) {
        if (choices.empty()) { hide(); return; }
        ComPtr<ITfContextView> view;
        TF_SELECTION selection{}; ULONG count = 0; RECT caret{}; BOOL clipped = FALSE;
        if (FAILED(context->GetActiveView(view.put())) || !view ||
            FAILED(context->GetSelection(cookie, TF_DEFAULT_SELECTION, 1, &selection, &count)) || !selection.range) { hide(); return; }
        const auto hr = view->GetTextExt(cookie, selection.range, &caret, &clipped);
        selection.range->Release();
        if (FAILED(hr) || clipped) { hide(); return; }
        hide();
        const auto monitor = MonitorFromRect(&caret, MONITOR_DEFAULTTONEAREST);
        MONITORINFO info{}; info.cbSize = sizeof(info); GetMonitorInfoW(monitor, &info);
        const int width = std::min<int>(480, info.rcWork.right - info.rcWork.left);
        const int height = 160;
        const int x = std::max(info.rcWork.left, std::min(caret.left, info.rcWork.right - width));
        const int y = caret.bottom + height < info.rcWork.bottom ? caret.bottom + 3 : std::max(info.rcWork.top, caret.top - height);
        window_ = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TOPMOST,
            L"STATIC", L"NepType keyboard choices", WS_POPUP | WS_BORDER,
            x, y, width, height, nullptr, nullptr, module, nullptr);
        if (!window_) return;
        auto label = [&](const std::wstring& caption, int y, int row_height) {
            auto text = CreateWindowExW(0, L"STATIC", caption.c_str(), WS_CHILD | WS_VISIBLE | SS_LEFT | SS_ENDELLIPSIS | SS_NOPREFIX,
                8, y, width - 16, row_height, window_, nullptr, module, nullptr);
            SendMessageW(text, WM_SETFONT, reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)), FALSE);
        };
        label(mode == 2 ? L"Nepali · Ctrl+Shift+Space: change mode" : L"Mixed · Ctrl+Shift+Space: change mode", 6, 22);
        for (std::size_t i = 0; i < std::min<std::size_t>(choices.size(), 4); ++i) {
            std::wstring caption = i == selected ? L"▶ " : L"   ";
            caption += L"Ctrl+" + std::to_wstring(i + 1) + L"  ";
            caption.append(reinterpret_cast<const wchar_t*>(choices[i].data()), choices[i].size());
            label(caption, 30 + static_cast<int>(i) * 24, 24);
        }
        label(L"Space: accept  ·  ↑/↓: choose  ·  Esc: keep Roman", 130, 22);
        ShowWindow(window_, SW_SHOWNOACTIVATE);
    }
private:
    HWND window_ = nullptr;
};
}
