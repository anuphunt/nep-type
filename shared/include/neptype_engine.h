#ifndef NEPTYPE_ENGINE_H
#define NEPTYPE_ENGINE_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
/* ABI 2. All strings are NUL-terminated UTF-8. Inputs must stay valid for
 * the duration of the call. Results own their strings until result_destroy.
 * A handle serializes calls; never destroy a handle/result during another call.
 * Dictionaries are embedded in the Rust library. directory may be NULL or empty;
 * a supplied legacy path must exist. No adapter may substitute its own data.
 * NULL results indicate invalid input or unsupported mode.
 * Modes: 0 mixed Nepali/English, 1 literal English, 2 All Nepali.
 * No function reads/writes the host editor, clipboard, network, or preferences.
 */
uint32_t neptype_engine_abi_version(void);
bool neptype_engine_set_preferences(void *engine, const char *json);
void *neptype_engine_create(const char *dictionary_directory);
void neptype_engine_destroy(void *engine);
void *neptype_engine_candidates(void *engine, const char *roman, int32_t mode);
/* caret and token ranges use UTF-16, matching UIKit/Win32/Java string offsets.
 * choice may be NULL. UI adapters must reject stale source/generation actions.
 */
void *neptype_engine_document(void *engine, const char *source, int32_t mode,
                              int32_t caret, const char *choice);
const char *neptype_result_output(void *result);
const char *neptype_result_token(void *result);
int32_t neptype_result_token_start(void *result);
int32_t neptype_result_token_length(void *result);
int32_t neptype_result_candidate_count(void *result);
const char *neptype_result_candidate(void *result, int32_t index);
void neptype_result_destroy(void *result);
/* Stateless JSON transport for Swift value adapters and tooling. The caller
 * owns the returned UTF-8 string and must free it with neptype_string_destroy. */
char *neptype_engine_query(const char *request);
void neptype_string_destroy(char *value);
const char *neptype_dictionary_id(void);
/* A composer owns private undo history. Clone before mutating a shared value;
 * destroy with neptype_engine_destroy. Responses contain only the current view. */
void *neptype_composer_create(void);
void *neptype_composer_clone(void *composer);
char *neptype_composer_query(void *composer, const char *request);
#ifdef __cplusplus
}
#endif
#endif
