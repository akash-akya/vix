#ifndef VIX_G_OBJECT_H
#define VIX_G_OBJECT_H

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

extern ErlNifResourceType *G_OBJECT_RT;

typedef struct _GObjectResource {
  GObject *obj;
} GObjectResource;

ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *obj);

ERL_NIF_TERM nif_g_object_type_name(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_object_unref(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]);

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term, GObject **obj);

int nif_g_object_init(ErlNifEnv *env);

#endif
