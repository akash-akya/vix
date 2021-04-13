#ifndef VIX_G_TYPE_H
#define VIX_G_TYPE_H

#include "erl_nif.h"
#include <glib-object.h>

extern ErlNifResourceType *G_TYPE_RT;

/* Not really need, since GType is mostly an int */
typedef struct _GTypeResource {
  GType type;
} GTypeResource;

ERL_NIF_TERM nif_g_type_from_instance(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_type_name(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]);

int nif_g_type_init(ErlNifEnv *env);

#endif
