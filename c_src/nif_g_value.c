#include "nif_g_value.h"
#include "eips_common.h"
#include "nif_g_object.h"
#include "nif_g_type.h"
#include "nif_g_boxed.h"
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

static GValueResult set_boolean(ErlNifEnv *env, ERL_NIF_TERM term,
                                GValue *gvalue) {
  char atom[10] = {0};
  GValueResult res = {true, 0};
  bool boolean_value;

  if (enif_get_atom(env, term, atom, 9, ERL_NIF_LATIN1) < 1) {
    error("failed to get atom");
    res.is_success = false;
    return res;
  }

  if (strcmp(atom, "true") == 0) {
    boolean_value = true;
  } else if (strcmp(atom, "false") == 0) {
    boolean_value = false;
  } else {
    error("invalid atom value, value must be :true or :false");
    res.is_success = false;
    return res;
  }

  g_value_set_boolean(gvalue, boolean_value);
  return res;
}

static GValueResult set_int(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  int int_value;
  GValueResult res = {true, 0};

  if (!enif_get_int(env, term, &int_value)) {
    error("failed to get int from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_int(gvalue, int_value);
  return res;
}

static GValueResult set_uint64(ErlNifEnv *env, ERL_NIF_TERM term,
                               GValue *gvalue) {
  unsigned long uint64_value;
  GValueResult res = {true, 0};

  if (!enif_get_uint64(env, term, &uint64_value)) {
    error("failed to get uint64 from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_uint64(gvalue, uint64_value);
  return res;
}

static GValueResult set_double(ErlNifEnv *env, ERL_NIF_TERM term,
                               GValue *gvalue) {
  double double_value;
  GValueResult res = {true, 0};

  if (!enif_get_double(env, term, &double_value)) {
    error("failed to get double from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_double(gvalue, double_value);
  return res;
}

static GValueResult set_boxed(ErlNifEnv *env, ERL_NIF_TERM term,
                              GValue *gvalue) {
  GValueResult res = {true, 0};
  gpointer ptr = NULL;

  if (!erl_term_to_g_boxed(env, term, &ptr)) {
    error("failed to get boxed pointer from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_boxed(gvalue, ptr);
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
  } else if (G_IS_PARAM_SPEC_BOOLEAN(pspec)) {
    res = set_boolean(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_UINT64(pspec)) {
    res = set_uint64(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_DOUBLE(pspec)) {
    res = set_double(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_INT(pspec)) {
    res = set_int(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_BOXED(pspec)) {
    res = set_boxed(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_OBJECT(pspec)) {
    res = set_g_object(env, term, gvalue);
  } else {
    error("Invalid pspec");
    res.is_success = false;
  }

  return res;
}
