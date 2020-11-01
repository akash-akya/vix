#ifndef NIF_G_OBJECT_H
#define NIF_G_OBJECT_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

ErlNifResourceType *G_OBJECT_RT;

typedef struct GObjectResource {
  GObject *g_object;
} GObjectResource;

ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *g_object);

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                          GObject **g_object);

int nif_g_object_init(ErlNifEnv *env);

#endif
