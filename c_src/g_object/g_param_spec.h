#ifndef VIX_G_PARAM_SPEC_H
#define VIX_G_PARAM_SPEC_H

#include "erl_nif.h"
#include <glib-object.h>
#include <stdbool.h>

extern ErlNifResourceType *G_PARAM_SPEC_RT;

typedef struct _GParamSpecResource {
  GParamSpec *pspec;
} GParamSpecResource;

static inline bool vix_param_spec_is_enum(GParamSpec *pspec) {
  return g_type_is_a(G_PARAM_SPEC_VALUE_TYPE(pspec), G_TYPE_ENUM);
}

static inline bool vix_param_spec_is_boolean(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_BOOLEAN;
}

static inline bool vix_param_spec_is_uint64(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_UINT64;
}

static inline bool vix_param_spec_is_double(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_DOUBLE;
}

static inline bool vix_param_spec_is_int(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_INT;
}

static inline bool vix_param_spec_is_uint(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_UINT;
}

static inline bool vix_param_spec_is_int64(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_INT64;
}

static inline bool vix_param_spec_is_string(GParamSpec *pspec) {
  return G_PARAM_SPEC_VALUE_TYPE(pspec) == G_TYPE_STRING;
}

static inline bool vix_param_spec_is_flags(GParamSpec *pspec) {
  return g_type_is_a(G_PARAM_SPEC_VALUE_TYPE(pspec), G_TYPE_FLAGS);
}

static inline bool vix_param_spec_is_boxed(GParamSpec *pspec) {
  return g_type_is_a(G_PARAM_SPEC_VALUE_TYPE(pspec), G_TYPE_BOXED);
}

static inline bool vix_param_spec_is_object(GParamSpec *pspec) {
  return g_type_is_a(G_PARAM_SPEC_VALUE_TYPE(pspec), G_TYPE_OBJECT);
}

ERL_NIF_TERM g_param_spec_to_erl_term(ErlNifEnv *env, GParamSpec *pspec);

bool erl_term_to_g_param_spec(ErlNifEnv *env, ERL_NIF_TERM term,
                              GParamSpec **pspec);

ERL_NIF_TERM g_param_spec_details(ErlNifEnv *env, GParamSpec *pspec);

int nif_g_param_spec_init(ErlNifEnv *env);

#endif
