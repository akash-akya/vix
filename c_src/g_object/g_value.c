#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"
#include "g_value.h"

static VixResult set_enum(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {

  int value;

  if (!enif_get_int(env, term, &value)) {
    error("failed to get enum int value from erl term");
    return vix_error(env, "failed to get enum int value from erl term");
  }

  g_value_set_enum(gvalue, value);
  return vix_result(ATOM_OK);
}

static VixResult set_flags(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {

  int value;

  if (!enif_get_int(env, term, &value)) {
    error("failed to get flag int value from erl term");
    return vix_error(env, "failed to get flag int value from erl term");
  }

  g_value_set_flags(gvalue, value);
  return vix_result(ATOM_OK);
}

static VixResult set_boolean(ErlNifEnv *env, ERL_NIF_TERM term,
                             GValue *gvalue) {
  char atom[10] = {0};
  bool boolean_value;

  if (enif_get_atom(env, term, atom, 9, ERL_NIF_LATIN1) < 1) {
    error("failed to get atom");
    return vix_error(env, "failed to get atom");
  }

  if (strcmp(atom, "true") == 0) {
    boolean_value = true;
  } else if (strcmp(atom, "false") == 0) {
    boolean_value = false;
  } else {
    error("invalid atom value, value must be :true or :false");
    return vix_error(env, "invalid atom value, value must be :true or :false");
  }

  g_value_set_boolean(gvalue, boolean_value);
  return vix_result(ATOM_OK);
}

static VixResult set_int(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  int int_value;

  if (!enif_get_int(env, term, &int_value)) {
    error("failed to get int from erl term");
    return vix_error(env, "failed to get int from erl term");
  }

  g_value_set_int(gvalue, int_value);
  return vix_result(ATOM_OK);
}

static VixResult set_uint(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  unsigned int uint_value;

  if (!enif_get_uint(env, term, &uint_value)) {
    error("failed to get uint from erl term");
    return vix_error(env, "failed to get uint from erl term");
  }

  g_value_set_uint(gvalue, uint_value);
  return vix_result(ATOM_OK);
}

static VixResult set_int64(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  long int64_value;

  if (!enif_get_int64(env, term, &int64_value)) {
    error("failed to get int64 from erl term");
    return vix_error(env, "failed to get int64 from erl term");
  }

  g_value_set_int64(gvalue, int64_value);
  return vix_result(ATOM_OK);
}

static VixResult set_string(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  char value[512];

  if (enif_get_string(env, term, (char *)&value, 511, ERL_NIF_LATIN1) < 0) {
    error("failed to get string from erl term");
    return vix_error(env, "failed to get string from erl term");
  }

  g_value_set_string(gvalue, value);
  return vix_result(ATOM_OK);
}

static VixResult set_uint64(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  unsigned long uint64_value;

  if (!enif_get_uint64(env, term, &uint64_value)) {
    error("failed to get uint64 from erl term");
    return vix_error(env, "failed to get uint64 from erl term");
  }

  g_value_set_uint64(gvalue, uint64_value);
  return vix_result(ATOM_OK);
}

static VixResult set_double(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  double double_value;

  if (!enif_get_double(env, term, &double_value)) {
    error("failed to get double from erl term");
    return vix_error(env, "failed to get double from erl term");
  }

  g_value_set_double(gvalue, double_value);
  return vix_result(ATOM_OK);
}

static VixResult set_boxed(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  gpointer ptr = NULL;

  if (!erl_term_to_g_boxed(env, term, &ptr)) {
    error("failed to get boxed pointer from erl term");
    return vix_error(env, "failed to get boxed pointer from erl term");
  }

  g_value_set_boxed(gvalue, ptr);
  return vix_result(ATOM_OK);
}

static VixResult set_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                              GValue *gvalue) {
  GObject *obj;

  if (!erl_term_to_g_object(env, term, &obj)) {
    error("failed to get GObject argument");
    return vix_error(env, "failed to get GObject argument");
  }

  g_value_set_object(gvalue, obj);
  return vix_result(ATOM_OK);
}

VixResult set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                    ERL_NIF_TERM term, GValue *gvalue) {
  g_value_init(gvalue, G_PARAM_SPEC_VALUE_TYPE(pspec));

  if (G_IS_PARAM_SPEC_ENUM(pspec))
    return set_enum(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_BOOLEAN(pspec))
    return set_boolean(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_UINT64(pspec))
    return set_uint64(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_DOUBLE(pspec))
    return set_double(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_INT(pspec))
    return set_int(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_UINT(pspec))
    return set_uint(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_INT64(pspec))
    return set_int64(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_STRING(pspec))
    return set_string(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_BOXED(pspec))
    return set_boxed(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_OBJECT(pspec))
    return set_g_object(env, term, gvalue);
  else if (G_IS_PARAM_SPEC_FLAGS(pspec))
    return set_flags(env, term, gvalue);
  else
    return vix_error(env, "Unknown pspec");
}

static VixResult get_enum(ErlNifEnv *env, GValue *gvalue) {
  gint enum_int;

  enum_int = g_value_get_enum(gvalue);
  return vix_result(enif_make_int(env, enum_int));
}

static VixResult get_flags(ErlNifEnv *env, GValue *gvalue) {
  gint flags_int;

  flags_int = g_value_get_flags(gvalue);
  return vix_result(enif_make_int(env, flags_int));
}

static VixResult get_boolean(ErlNifEnv *env, GValue *gvalue) {
  bool bool_value;

  bool_value = g_value_get_boolean(gvalue);
  if (bool_value)
    return vix_result(ATOM_TRUE);
  else
    return vix_result(ATOM_FALSE);
}

static VixResult get_int(ErlNifEnv *env, GValue *gvalue) {
  int int_value;

  int_value = g_value_get_int(gvalue);
  return vix_result(enif_make_int(env, int_value));
}

static VixResult get_uint(ErlNifEnv *env, GValue *gvalue) {
  unsigned int uint_value;

  uint_value = g_value_get_uint(gvalue);
  return vix_result(enif_make_int(env, uint_value));
}

static VixResult get_int64(ErlNifEnv *env, GValue *gvalue) {
  long int64_value;

  int64_value = g_value_get_int64(gvalue);
  return vix_result(enif_make_int(env, int64_value));
}

static VixResult get_string(ErlNifEnv *env, GValue *gvalue) {
  const gchar *str;

  str = g_value_get_string(gvalue);
  return vix_result(enif_make_string(env, str, ERL_NIF_LATIN1));
}

static VixResult get_uint64(ErlNifEnv *env, GValue *gvalue) {
  unsigned long uint64_value;

  uint64_value = g_value_get_uint64(gvalue);
  return vix_result(enif_make_int(env, uint64_value));
}

static VixResult get_double(ErlNifEnv *env, GValue *gvalue) {
  double double_value;

  double_value = g_value_get_double(gvalue);
  return vix_result(enif_make_int(env, double_value));
}

static VixResult get_boxed(ErlNifEnv *env, GValue *gvalue) {
  gpointer ptr;
  GType type;

  // duplicate value so that we we can free it ourselves
  ptr = g_value_dup_boxed(gvalue);
  type = G_VALUE_TYPE(gvalue);

  return vix_result(boxed_to_erl_term(env, ptr, type));
}

static VixResult get_g_object(ErlNifEnv *env, GValue *gvalue) {
  GObject *obj;

  obj = g_value_get_object(gvalue);

  // explicitly get a ref for the output property so that we can
  // unref all output objects of the operation at once
  g_object_ref(obj);

  return vix_result(g_object_to_erl_term(env, obj));
}

VixResult get_erl_term_from_g_value(ErlNifEnv *env, GObject *obj,
                                    const char *name, GParamSpec *pspec) {
  GValue gvalue = {0};
  VixResult res;

  g_value_init(&gvalue, G_PARAM_SPEC_VALUE_TYPE(pspec));
  g_object_get_property(obj, name, &gvalue);

  if (G_IS_PARAM_SPEC_ENUM(pspec))
    res = get_enum(env, &gvalue);
  else if (G_IS_PARAM_SPEC_BOOLEAN(pspec))
    res = get_boolean(env, &gvalue);
  else if (G_IS_PARAM_SPEC_UINT64(pspec))
    res = get_uint64(env, &gvalue);
  else if (G_IS_PARAM_SPEC_DOUBLE(pspec))
    res = get_double(env, &gvalue);
  else if (G_IS_PARAM_SPEC_INT(pspec))
    res = get_int(env, &gvalue);
  else if (G_IS_PARAM_SPEC_UINT(pspec))
    res = get_uint(env, &gvalue);
  else if (G_IS_PARAM_SPEC_INT64(pspec))
    res = get_int64(env, &gvalue);
  else if (G_IS_PARAM_SPEC_STRING(pspec))
    res = get_string(env, &gvalue);
  else if (G_IS_PARAM_SPEC_BOXED(pspec))
    res = get_boxed(env, &gvalue);
  else if (G_IS_PARAM_SPEC_OBJECT(pspec))
    res = get_g_object(env, &gvalue);
  else if (G_IS_PARAM_SPEC_FLAGS(pspec))
    res = get_flags(env, &gvalue);
  else
    res = vix_error(env, "Unknown pspec");

  g_value_unset(&gvalue);
  return res;
}
