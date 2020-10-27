#ifndef NIF_G_TYPE_H
#define NIF_G_TYPE_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

ErlNifResourceType *G_TYPE_RT;

typedef struct GTypeResource {
  GType g_type;
} GTypeResource;

ERL_NIF_TERM g_type_to_erl_term(ErlNifEnv *env, GType g_type);

bool erl_term_to_g_type(ErlNifEnv *env, ERL_NIF_TERM term, GType *g_type);

ERL_NIF_TERM nif_g_type_name(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_type_from_name(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]);

int nif_g_type_init(ErlNifEnv *env);

#endif
