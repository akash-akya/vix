#ifndef VIX_G_VALUE_H
#define VIX_G_VALUE_H

#include "erl_nif.h"
#include <glib-object.h>

ERL_NIF_TERM set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                       ERL_NIF_TERM term, GValue *gvalue);

#endif
