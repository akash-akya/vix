#ifndef NIF_G_OBJECT_H
#define NIF_G_OBJECT_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

ErlNifResourceType *G_OBJECT_RT;

typedef struct NifGObjectClass NifGObjectClass;
typedef struct GObjectResource GObjectResource;

struct GObjectResource {
  GObject *g_object;
  NifGObjectClass *class;
};

struct NifGObjectClass {
  void (*dtor)(ErlNifEnv *env, GObjectResource *g_object_r);
  NifGObjectClass *parent;
};

NifGObjectClass NIF_G_OBJECT_CLASS;

ERL_NIF_TERM g_object_to_erl_term_with_type(ErlNifEnv *env, GObject *g_object,
                                            NifGObjectClass *nif_g_class);

bool erl_term_to_g_object_with_type(ErlNifEnv *env, ERL_NIF_TERM term,
                                    GObject **g_object,
                                    NifGObjectClass *nif_g_class);

ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *g_object);

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                          GObject **g_object);

ERL_NIF_TERM nif_g_object_type(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_g_object_type_name(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]);

void super_g_object_dtor(ErlNifEnv *env, GObjectResource *g_object_r);

int nif_g_object_init(ErlNifEnv *env);

#endif
