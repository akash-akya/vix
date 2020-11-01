#ifndef VIX_UTILS_H
#define VIX_UTILS_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <stdbool.h>

#ifdef ERTS_DIRTY_SCHEDULERS
#define USE_DIRTY_IO ERL_NIF_DIRTY_JOB_IO_BOUND
#else
#define USE_DIRTY_IO 0
#endif

#define DEBUG

#ifdef DEBUG
#define debug(...)                                                             \
  do {                                                                         \
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
    enif_fprintf(stderr, __VA_ARGS__);                                         \
    enif_fprintf(stderr, "\n");                                                \
  } while (0)

extern ERL_NIF_TERM ATOM_OK;

typedef struct VixResult {
  bool success;
  ERL_NIF_TERM term; // error term if success == false
} VixResult;

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg);

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term);

void vix_utils_init(ErlNifEnv *env);

#endif
