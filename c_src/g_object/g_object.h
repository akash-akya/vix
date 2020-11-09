#ifndef VIX_G_OBJECT_H
#define VIX_G_OBJECT_H

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

ERL_NIF_TERM nif_g_object_init(ErlNifEnv *env);

#endif
