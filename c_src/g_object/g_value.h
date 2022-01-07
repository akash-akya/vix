#ifndef VIX_G_VALUE_H
#define VIX_G_VALUE_H

#include "../utils.h"
#include "erl_nif.h"

#include <glib-object.h>

VixResult set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                    ERL_NIF_TERM term, GValue *gvalue);

VixResult get_erl_term_from_g_object_property(ErlNifEnv *env, GObject *obj,
                                              const char *name,
                                              GParamSpec *pspec);

VixResult g_value_to_erl_term(ErlNifEnv *env, GValue gvalue);

VixResult erl_term_to_g_value(ErlNifEnv *env, GType type, ERL_NIF_TERM term,
                              GValue *gvalue);

#endif
