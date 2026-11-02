#pragma once
#include <atomic>

namespace neptype {
// COM edit sessions can outlive the text service if a host retains a reference.
// The DLL cannot be unloaded while such an object can still receive a call.
inline std::atomic<long> live_edit_sessions{0};
}
