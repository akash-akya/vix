#ifndef NIF_G_VALUE_H
#define NIF_G_VALUE_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

ERL_NIF_TERM set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                       ERL_NIF_TERM term, GValue *gvalue);

#endif
