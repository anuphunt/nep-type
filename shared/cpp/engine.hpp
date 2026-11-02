#pragma once
#include "../include/neptype_engine.h"
#include <filesystem>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace neptype {
struct Document {
    std::string output, token;
    int32_t start = -1, length = 0;
    std::vector<std::string> candidates;
};
/* Owns the library and a single shared-engine handle. UTF-8 in, UTF-8 out.
   The adapter owns host editing and stale-request rejection, never ranking. */
class Engine {
#ifdef _WIN32
    HMODULE library_ = nullptr;
#else
    void* library_ = nullptr;
#endif
    void* handle_ = nullptr;
    static void validate(const std::string& value) {
        if (value.find('\0') != std::string::npos)
            throw std::runtime_error("Embedded NUL is not supported by ABI 2");
    }
#define NEPTYPE_FUNCTION(name) decltype(&neptype_##name) name##_ = nullptr;
    NEPTYPE_FUNCTION(dictionary_id)
    NEPTYPE_FUNCTION(engine_abi_version)
    NEPTYPE_FUNCTION(engine_create)
    NEPTYPE_FUNCTION(engine_destroy)
    NEPTYPE_FUNCTION(engine_candidates)
    NEPTYPE_FUNCTION(engine_document)
    NEPTYPE_FUNCTION(result_output)
    NEPTYPE_FUNCTION(result_token)
    NEPTYPE_FUNCTION(result_token_start)
    NEPTYPE_FUNCTION(result_token_length)
    NEPTYPE_FUNCTION(result_candidate_count)
    NEPTYPE_FUNCTION(result_candidate)
    NEPTYPE_FUNCTION(result_destroy)
#undef NEPTYPE_FUNCTION
    template<class T> T symbol(const char* name) {
#ifdef _WIN32
        auto value = GetProcAddress(library_, name);
#else
        auto value = dlsym(library_, name);
#endif
        if (!value) throw std::runtime_error("Shared engine symbol unavailable");
        return reinterpret_cast<T>(value);
    }
    void unload() noexcept {
        if (handle_ && engine_destroy_) engine_destroy_(handle_);
        handle_ = nullptr;
#ifdef _WIN32
        if (library_) FreeLibrary(library_);
#else
        if (library_) dlclose(library_);
#endif
        library_ = nullptr;
    }
    Document read(void* result) {
        if (!result) throw std::runtime_error("Shared engine rejected request");
        try {
            Document value;
            value.output = result_output_(result);
            value.token = result_token_(result);
            value.start = result_token_start_(result);
            value.length = result_token_length_(result);
            for (int32_t i = 0; i < result_candidate_count_(result); ++i)
                value.candidates.emplace_back(result_candidate_(result, i));
            result_destroy_(result);
            return value;
        } catch (...) { result_destroy_(result); throw; }
    }
public:
    Engine(const std::string& library, const std::string& dictionaries) {
        validate(library); validate(dictionaries);
        if (!std::filesystem::u8path(library).is_absolute())
            throw std::runtime_error("Shared engine path must be absolute");
#ifdef _WIN32
        library_ = LoadLibraryExW(std::filesystem::u8path(library).c_str(), nullptr,
                                  LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
#else
        library_ = dlopen(library.c_str(), RTLD_NOW | RTLD_LOCAL);
#endif
        if (!library_) throw std::runtime_error("Shared engine could not be loaded");
        try {
#define NEPTYPE_BIND(name) name##_ = symbol<decltype(name##_)>("neptype_" #name);
            NEPTYPE_BIND(dictionary_id)
            NEPTYPE_BIND(engine_abi_version)
            NEPTYPE_BIND(engine_create)
            NEPTYPE_BIND(engine_destroy)
            NEPTYPE_BIND(engine_candidates)
            NEPTYPE_BIND(engine_document)
            NEPTYPE_BIND(result_output)
            NEPTYPE_BIND(result_token)
            NEPTYPE_BIND(result_token_start)
            NEPTYPE_BIND(result_token_length)
            NEPTYPE_BIND(result_candidate_count)
            NEPTYPE_BIND(result_candidate)
            NEPTYPE_BIND(result_destroy)
#undef NEPTYPE_BIND
            if (engine_abi_version_() != 2) throw std::runtime_error("Unsupported shared engine ABI");
            handle_ = engine_create_(dictionaries.c_str());
            if (!handle_) throw std::runtime_error("Shared dictionaries unavailable");
        } catch (...) { unload(); throw; }
    }
    std::string dictionary_id() const { return dictionary_id_(); }
    ~Engine() { unload(); }
    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;
    std::vector<std::string> candidates(const std::string& roman, int32_t mode=0) {
        validate(roman);
        return read(engine_candidates_(handle_, roman.c_str(), mode)).candidates;
    }
    Document document(const std::string& source, int32_t mode, int32_t caret, const char* choice=nullptr) {
        validate(source);
        return read(engine_document_(handle_, source.c_str(), mode, caret, choice));
    }
};
}
