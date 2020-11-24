#ifndef UTILS_H
#define UTILS_H

#include "erl_nif.h"
#include <stdbool.h>

/* #define DEBUG */

#ifdef DEBUG
#define debug(...)                                                             \
  do {                                                                         \
    enif_fprintf(stderr, "%s:%d\t(fn \"%s\")  - ", __FILE__, __LINE__,         \
                 __func__);                                                    \
    enif_fprintf(stderr, __VA_ARGS__);                                         \
    enif_fprintf(stderr, "\n");                                                \
  } while (0)
#define start_timing() ErlNifTime __start = enif_monotonic_time(ERL_NIF_USEC)
#define elapsed_microseconds() (enif_monotonic_time(ERL_NIF_USEC) - __start)
#else
#define debug(...)
#define start_timing()
#define elapsed_microseconds() 0
#endif

#define error(...)                                                             \
  do {                                                                         \
    enif_fprintf(stderr, "%s:%d\t(fn: \"%s\")  - ", __FILE__, __LINE__,        \
                 __func__);                                                    \
    enif_fprintf(stderr, __VA_ARGS__);                                         \
    enif_fprintf(stderr, "\n");                                                \
  } while (0)

#define assert_argc(argc, count)                                               \
  if (argc != count) {                                                         \
    error("number of arguments must be %d", count);                            \
    return enif_make_badarg(env);                                              \
  }

#define return_if_exception(env, exception)                                    \
  if (enif_is_exception(env, exception)) {                                     \
    return exception;                                                          \
  }

extern ERL_NIF_TERM ATOM_OK;

extern ERL_NIF_TERM ATOM_ERROR;

extern ERL_NIF_TERM ATOM_NIL;

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg);

ERL_NIF_TERM raise_badarg(ErlNifEnv *env, const char *reason);

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term);

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason);

ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *name);

int utils_init(ErlNifEnv *env);

#endif
