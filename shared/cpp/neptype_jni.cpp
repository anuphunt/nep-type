#include <jni.h>
#include "../include/neptype_engine.h"
#include <cstdint>
#include <cstring>
#include <vector>
static bool bytes(JNIEnv* env, jbyteArray value, std::vector<char>& out, size_t limit) {
    if (!value) return false;
    const jsize size = env->GetArrayLength(value);
    if (size < 0 || static_cast<size_t>(size) > limit) return false;
    out.resize(static_cast<size_t>(size) + 1, 0);
    env->GetByteArrayRegion(value, 0, size, reinterpret_cast<jbyte*>(out.data()));
    return !env->ExceptionCheck() && std::memchr(out.data(), 0, size) == nullptr;
}
extern "C" JNIEXPORT jlong JNICALL Java_app_neptype_keyboard_core_SharedEngine_create(JNIEnv* env, jclass, jbyteArray directory) {
    std::vector<char> path;
    if (neptype_engine_abi_version() != 2 || !bytes(env, directory, path, 32768)) return 0;
    return static_cast<jlong>(reinterpret_cast<intptr_t>(neptype_engine_create(path.data())));
}
extern "C" JNIEXPORT jobjectArray JNICALL Java_app_neptype_keyboard_core_SharedEngine_candidates(JNIEnv* env, jclass, jlong engine, jbyteArray roman, jint mode) {
    std::vector<char> text;
    if (!engine || !bytes(env, roman, text, 256)) return nullptr;
    void* result = neptype_engine_candidates(reinterpret_cast<void*>(static_cast<intptr_t>(engine)), text.data(), mode);
    if (!result) return nullptr;
    const int32_t count = neptype_result_candidate_count(result);
    jclass byteArray = env->FindClass("[B");
    jobjectArray values = byteArray ? env->NewObjectArray(count, byteArray, nullptr) : nullptr;
    for (int32_t i = 0; values && i < count && !env->ExceptionCheck(); ++i) {
        const char* value = neptype_result_candidate(result, i);
        const jsize length = static_cast<jsize>(std::strlen(value));
        jbyteArray item = env->NewByteArray(length);
        if (!item) break;
        env->SetByteArrayRegion(item, 0, length, reinterpret_cast<const jbyte*>(value));
        env->SetObjectArrayElement(values, i, item);
        env->DeleteLocalRef(item);
    }
    neptype_result_destroy(result);
    return env->ExceptionCheck() ? nullptr : values;
}
extern "C" JNIEXPORT void JNICALL Java_app_neptype_keyboard_core_SharedEngine_destroy(JNIEnv*, jclass, jlong engine) {
    neptype_engine_destroy(reinterpret_cast<void*>(static_cast<intptr_t>(engine)));
}

extern "C" JNIEXPORT jstring JNICALL Java_app_neptype_keyboard_core_SharedEngine_dictionaryId(JNIEnv* env, jclass) {
    // The fingerprint is lowercase ASCII hex, safe for JNI modified UTF-8.
    return env->NewStringUTF(neptype_dictionary_id());
}
