#include "nif_g_value.h"
#include "eips_common.h"
#include "nif_g_object.h"
#include "nif_g_type.h"
#include <glib-object.h>

static GValueResult set_enum(ErlNifEnv *env, ERL_NIF_TERM term,
                             GValue *gvalue) {
  int enum_value;
  GValueResult res = {true, 0};

  if (!enif_get_int(env, term, &enum_value)) {
    error("failed to get Enum argument");
    res.is_success = false;
    return res;
  }

  g_value_set_enum(gvalue, enum_value);
  return res;
}

static GValueResult set_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                                 GValue *gvalue) {
  GObject *g_object;
  GValueResult res = {true, 0};

  if (!erl_term_to_g_object(env, term, &g_object)) {
    error("failed to get GObject argument");
    res.is_success = false;
    return res;
  }

  g_value_set_object(gvalue, g_object);
  return res;
}

GValueResult set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                       ERL_NIF_TERM term, GValue *gvalue) {
  g_value_init(gvalue, G_PARAM_SPEC_VALUE_TYPE(pspec));
  GValueResult res;

  if (G_IS_PARAM_SPEC_ENUM(pspec)) {
    res = set_enum(env, term, gvalue);
  } else {
    res = set_g_object(env, term, gvalue);
  }

  return res;
}
