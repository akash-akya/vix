#ifndef VIX_G_BOXED_H
#define VIX_G_BOXED_H

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

extern ErlNifResourceType *G_BOXED_RT;

typedef struct _GBoxedResource {
  GType boxed_type;
  gpointer boxed_ptr;
} GBoxedResource;

bool erl_term_to_g_boxed(ErlNifEnv *env, ERL_NIF_TERM term, gpointer *ptr);

bool erl_term_boxed_type(ErlNifEnv *env, ERL_NIF_TERM term, GType *type);

ERL_NIF_TERM nif_g_boxed_unref(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]);

ERL_NIF_TERM boxed_to_erl_term(ErlNifEnv *env, gpointer ptr, GType type);

int nif_g_boxed_init(ErlNifEnv *env);

#endif
