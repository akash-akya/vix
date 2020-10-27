#ifndef NIF_G_VALUE_H
#define NIF_G_VALUE_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

typedef struct GValueResult {
  bool is_success;
  ERL_NIF_TERM term;
} GValueResult;

GValueResult set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                       ERL_NIF_TERM term, GValue *gvalue);

#endif
