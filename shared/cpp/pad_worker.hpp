#pragma once
#include "engine.hpp"
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>

namespace neptype {
/* Serial, coalescing document worker; callbacks must dispatch onto the native UI. */
class PadWorker {
    struct Request { uint64_t generation; std::string source, choice; int32_t mode, caret; bool selecting; };
    std::mutex mutex_;
    std::condition_variable ready_;
    std::optional<Request> pending_;
    bool stopping_ = false;
    std::thread thread_;
public:
    using Deliver = std::function<void(uint64_t, Document, bool)>;
    PadWorker(std::string library, std::string dictionaries, Deliver deliver) {
        thread_ = std::thread([this, library=std::move(library), dictionaries=std::move(dictionaries), deliver=std::move(deliver)] {
            std::unique_ptr<Engine> engine;
            try { engine = std::make_unique<Engine>(library, dictionaries); } catch (...) {}
            for (;;) {
                Request request;
                {
                    std::unique_lock<std::mutex> lock(mutex_);
                    ready_.wait(lock, [this] { return stopping_ || pending_.has_value(); });
                    if (stopping_) return;
                    request = std::move(*pending_);
                    pending_.reset();
                }
                Document result; bool success = false;
                try {
                    if (engine) {
                        result = engine->document(request.source, request.mode, request.caret,
                                                  request.selecting ? request.choice.c_str() : nullptr);
                        success = true;
                    }
                } catch (...) {}
                deliver(request.generation, std::move(result), success);
            }
        });
    }
    ~PadWorker() {
        { std::lock_guard<std::mutex> lock(mutex_); stopping_ = true; pending_.reset(); }
        ready_.notify_one();
        if (thread_.joinable()) thread_.join();
    }
    void submit(uint64_t generation, std::string source, int32_t mode, int32_t caret, const char* choice=nullptr) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stopping_) return;
            pending_ = Request{generation, std::move(source), choice ? choice : "", mode, caret, choice != nullptr};
        }
        ready_.notify_one();
    }
};
}
