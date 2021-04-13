#ifndef VIX_G_PARAM_SPEC_H
#define VIX_G_PARAM_SPEC_H

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

extern ErlNifResourceType *G_PARAM_SPEC_RT;

typedef struct _GParamSpecResource {
  GParamSpec *pspec;
} GParamSpecResource;

ERL_NIF_TERM g_param_spec_to_erl_term(ErlNifEnv *env, GParamSpec *pspec);

bool erl_term_to_g_param_spec(ErlNifEnv *env, ERL_NIF_TERM term,
                              GParamSpec **pspec);

ERL_NIF_TERM g_param_spec_details(ErlNifEnv *env, GParamSpec *pspec);

int nif_g_param_spec_init(ErlNifEnv *env);

#endif
