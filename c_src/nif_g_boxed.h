#ifndef NIF_G_BOXED_H
#define NIF_G_BOXED_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

ErlNifResourceType *G_BOXED_RT;

typedef struct GBoxedResource {
  GType boxed_type;
  gpointer g_boxed;
} GBoxedResource;

bool erl_term_to_g_boxed(ErlNifEnv *env, ERL_NIF_TERM term, gpointer *ptr);

int nif_g_boxed_init(ErlNifEnv *env);

#endif
