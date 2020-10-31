#ifndef NIF_G_PARAM_SPEC_H
#define NIF_G_PARAM_SPEC_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

ErlNifResourceType *G_PARAM_SPEC_RT;

typedef struct GParamSpecResource {
  GParamSpec *pspec;
} GParamSpecResource;

ERL_NIF_TERM g_param_spec_to_erl_term(ErlNifEnv *env, GParamSpec *pspec);

bool erl_term_to_g_param_spec(ErlNifEnv *env, ERL_NIF_TERM term,
                              GParamSpec **pspec);

ERL_NIF_TERM nif_g_param_spec_type(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_param_spec_value_type(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_param_spec_get_name(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_param_spec_type_name(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_param_spec_value_type_name(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]);

int nif_g_param_spec_init(ErlNifEnv *env);

#endif
