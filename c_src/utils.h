#ifndef VIX_UTILS_H
#define VIX_UTILS_H

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

/* #define DEBUG */

#define vix_log(...)                                                           \
  do {                                                                         \
    enif_fprintf(stderr, "%s:%d\t(fn \"%s\")  - ", __FILE__, __LINE__,         \
                 __func__);                                                    \
    enif_fprintf(stderr, __VA_ARGS__);                                         \
    enif_fprintf(stderr, "\n");                                                \
  } while (0)

#ifdef DEBUG
#define debug(...) vix_log(__VA_ARGS__)
#define start_timing() ErlNifTime __start = enif_monotonic_time(ERL_NIF_USEC)
#define elapsed_microseconds() (enif_monotonic_time(ERL_NIF_USEC) - __start)
#else
#define debug(...)
#define start_timing()
#define elapsed_microseconds() 0
#endif

extern const guint VIX_LOG_LEVEL_ERROR;
extern guint VIX_LOG_LEVEL;

#define error(...)                                                             \
  do {                                                                         \
    if (VIX_LOG_LEVEL == VIX_LOG_LEVEL_ERROR) {                                \
      vix_log(__VA_ARGS__);                                                    \
    }                                                                          \
  } while (0)

#define ASSERT_ARGC(argc, count)                                               \
  if (argc != count) {                                                         \
    error("number of arguments must be %d", count);                            \
    return enif_make_badarg(env);                                              \
  }

// Using macro to preserve file and line number metadata in the error log
#define SET_ERROR_RESULT(env, reason, res)                                     \
  do {                                                                         \
    res.is_success = false;                                                    \
    res.result = make_binary(env, reason);                                     \
    error(reason);                                                             \
  } while (0)

#define SET_RESULT_FROM_VIPS_ERROR(env, label, res)                            \
  do {                                                                         \
    res.is_success = false;                                                    \
    res.result = enif_make_tuple2(env, make_binary(env, label),                \
                                  make_binary(env, vips_error_buffer()));      \
    error("%s: %s", label, vips_error_buffer());                               \
    vips_error_clear();                                                        \
  } while (0)

#define SET_VIX_RESULT(res, term)                                              \
  do {                                                                         \
    res.is_success = true;                                                     \
    res.result = term;                                                         \
  } while (0)

typedef struct _VixResult {
  bool is_success;
  ERL_NIF_TERM result;
} VixResult;

/* size of the data is not really needed. but can be useful for debugging */
typedef struct _VixBinaryResource {
  void *data;
  size_t size;
} VixBinaryResource;

extern ErlNifResourceType *VIX_BINARY_RT;

extern int MAX_G_TYPE_NAME_LENGTH;

extern ERL_NIF_TERM ATOM_OK;

extern ERL_NIF_TERM ATOM_ERROR;

extern ERL_NIF_TERM ATOM_NIL;

extern ERL_NIF_TERM ATOM_TRUE;

extern ERL_NIF_TERM ATOM_FALSE;

extern ERL_NIF_TERM ATOM_NULL_VALUE;

extern ERL_NIF_TERM ATOM_UNDEFINED;

extern ERL_NIF_TERM ATOM_EAGAIN;

extern const int VIX_FD_CLOSED;

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg);

ERL_NIF_TERM raise_badarg(ErlNifEnv *env, const char *reason);

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term);

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason);

ERL_NIF_TERM make_error_term(ErlNifEnv *env, ERL_NIF_TERM term);

ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *name);

ERL_NIF_TERM make_binary(ErlNifEnv *env, const char *str);

bool get_binary(ErlNifEnv *env, ERL_NIF_TERM bin_term, char *str, size_t size);

VixResult vix_result(ERL_NIF_TERM term);

int utils_init(ErlNifEnv *env, const char *log_level);

int close_fd(int *fd);

void notify_consumed_timeslice(ErlNifEnv *env, ErlNifTime start,
                               ErlNifTime stop);

ERL_NIF_TERM to_binary_term(ErlNifEnv *env, void *data, size_t size);

void send_to_janitor(ErlNifEnv *env, ERL_NIF_TERM label,
                     ERL_NIF_TERM resource_term);

#endif
