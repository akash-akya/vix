#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"
#include "g_value.h"

static VixResult set_enum(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  int value;
  VixResult res;

  if (!enif_get_int(env, term, &value)) {
    SET_ERROR_RESULT(env, "failed to get enum int value from erl term", res);
    return res;
  }

  g_value_set_enum(gvalue, value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_flags(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  int value;
  VixResult res;

  if (!enif_get_int(env, term, &value)) {
    SET_ERROR_RESULT(env, "failed to get flag int value from erl term", res);
    return res;
  }

  g_value_set_flags(gvalue, value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_boolean(ErlNifEnv *env, ERL_NIF_TERM term,
                             GValue *gvalue) {
  char atom[10] = {0};
  bool boolean_value;
  VixResult res;

  if (enif_get_atom(env, term, atom, 9, ERL_NIF_LATIN1) < 1) {
    SET_ERROR_RESULT(env, "failed to get atom", res);
    return res;
  }

  if (strcmp(atom, "true") == 0) {
    boolean_value = true;
  } else if (strcmp(atom, "false") == 0) {
    boolean_value = false;
  } else {
    SET_ERROR_RESULT(env, "invalid atom value, value must be :true or :false",
                     res);
    return res;
  }

  g_value_set_boolean(gvalue, boolean_value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_int(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  int int_value;
  VixResult res;

  if (!enif_get_int(env, term, &int_value)) {
    SET_ERROR_RESULT(env, "failed to get int from erl term", res);
    return res;
  }

  g_value_set_int(gvalue, int_value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_uint(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  unsigned int uint_value;
  VixResult res;

  if (!enif_get_uint(env, term, &uint_value)) {
    SET_ERROR_RESULT(env, "failed to get uint from erl term", res);
    return res;
  }

  g_value_set_uint(gvalue, uint_value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_int64(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  ErlNifSInt64 int64_value;
  VixResult res;

  if (!enif_get_int64(env, term, &int64_value)) {
    SET_ERROR_RESULT(env, "failed to get int64 from erl term", res);
    return res;
  }

  g_value_set_int64(gvalue, int64_value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_string(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  ErlNifBinary bin;
  VixResult res;

  if (!enif_inspect_iolist_as_binary(env, term, &bin)) {
    SET_ERROR_RESULT(env, "failed to get string from erl term", res);
    return res;
  }

  // we ensure that data is appended with NULL while passing string from elixir
  g_value_set_string(gvalue, (const gchar *)bin.data);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_uint64(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  ErlNifUInt64 uint64_value;
  VixResult res;

  if (!enif_get_uint64(env, term, &uint64_value)) {
    SET_ERROR_RESULT(env, "failed to get uint64 from erl term", res);
    return res;
  }

  g_value_set_uint64(gvalue, uint64_value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_double(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  double double_value;
  VixResult res;

  if (!enif_get_double(env, term, &double_value)) {
    SET_ERROR_RESULT(env, "failed to get double from erl term", res);
    return res;
  }

  g_value_set_double(gvalue, double_value);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_boxed(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  gpointer ptr = NULL;
  VixResult res;

  if (!erl_term_to_g_boxed(env, term, &ptr)) {
    SET_ERROR_RESULT(env, "failed to get boxed pointer from erl term", res);
    return res;
  }

  g_value_set_boxed(gvalue, ptr);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

static VixResult set_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                              GValue *gvalue) {
  GObject *obj;
  VixResult res;

  if (!erl_term_to_g_object(env, term, &obj)) {
    SET_ERROR_RESULT(env, "failed to get GObject argument", res);
    return res;
  }

  g_value_set_object(gvalue, obj);
  SET_VIX_RESULT(res, ATOM_OK);
  return res;
}

VixResult set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                    ERL_NIF_TERM term, GValue *gvalue) {
  VixResult res;

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
  else {
    SET_ERROR_RESULT(env, "unknown pspec", res);
    return res;
  }
}

static VixResult get_enum(ErlNifEnv *env, GValue *gvalue) {
  gint enum_int;

  enum_int = g_value_get_enum(gvalue);
  return vix_result(enif_make_int(env, enum_int));
}

static VixResult get_enum_as_atom(ErlNifEnv *env, GValue *gvalue) {
  gint enum_int;
  ERL_NIF_TERM enum_term;
  GEnumClass *enum_class;
  GEnumValue *enum_value;

  enum_class = g_type_class_ref(G_VALUE_TYPE(gvalue));

  enum_int = g_value_get_enum(gvalue);
  enum_value = g_enum_get_value(enum_class, enum_int);
  enum_term = enif_make_atom(env, enum_value->value_name);

  g_type_class_unref(enum_class);
  return vix_result(enum_term);
}

static VixResult get_flags(ErlNifEnv *env, GValue *gvalue) {
  gint flags_int;

  flags_int = g_value_get_flags(gvalue);
  return vix_result(enif_make_int(env, flags_int));
}

static VixResult get_flags_as_atoms(ErlNifEnv *env, GValue *gvalue) {
  guint flags;
  guint flag;
  ERL_NIF_TERM flags_list;
  ERL_NIF_TERM flag_term;
  GFlagsClass *flags_class;
  GFlagsValue *flags_value;
  int bit_pos;

  flags_list = enif_make_list(env, 0);

  flags_class = g_type_class_ref(G_VALUE_TYPE(gvalue));
  flags = g_value_get_flags(gvalue);

  bit_pos = 0;

  while (flags > 0) {
    if (flags & 0x01) {
      flag = 1 << bit_pos;

      flags_value = g_flags_get_first_value(flags_class, flag);
      flag_term = enif_make_atom(env, flags_value->value_name);

      flags_list = enif_make_list_cell(env, flag_term, flags_list);
    }

    bit_pos++;
    flags = flags >> 1;
  }

  g_type_class_unref(flags_class);
  return vix_result(flags_list);
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
  ErlNifSInt64 int64_value;

  int64_value = g_value_get_int64(gvalue);
  return vix_result(enif_make_int(env, int64_value));
}

static VixResult get_string_as_binary(ErlNifEnv *env, GValue *gvalue) {
  const gchar *str;
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;
  VixResult res;

  str = g_value_get_string(gvalue);

  if (str != NULL) {
    length = strlen(str);
    temp = enif_make_new_binary(env, length, &bin);
    memcpy(temp, str, length);
    SET_VIX_RESULT(res, bin);
  } else {
    res.is_success = false;
    res.result = ATOM_NULL_VALUE;
  }

  return res;
}

static VixResult get_uint64(ErlNifEnv *env, GValue *gvalue) {
  ErlNifUInt64 uint64_value;

  uint64_value = g_value_get_uint64(gvalue);
  return vix_result(enif_make_int(env, uint64_value));
}

static VixResult get_double(ErlNifEnv *env, GValue *gvalue) {
  double double_value;

  double_value = g_value_get_double(gvalue);

  /*
   * NOTE: erlang does not support NaN & infinity, we only handle finite double
   * value. see: https://erlang.org/doc/man/erl_nif.html#enif_make_double
   */
  return vix_result(enif_make_double(env, double_value));
}

static VixResult get_boxed(ErlNifEnv *env, GValue *gvalue) {
  gpointer ptr;
  GType type;
  VixResult res;

  // duplicate value so that we can free it ourselves
  ptr = g_value_dup_boxed(gvalue);

  if (ptr != NULL) {
    type = G_VALUE_TYPE(gvalue);
    SET_VIX_RESULT(res, boxed_to_erl_term(env, ptr, type));
  } else {
    res.is_success = false;
    res.result = ATOM_NULL_VALUE;
  }

  return res;
}

static VixResult get_g_object(ErlNifEnv *env, GValue *gvalue) {
  GObject *obj;
  VixResult res;

  obj = g_value_get_object(gvalue);

  if (obj != NULL) {
    // explicitly get a ref for the output property so that we can
    // unref all output objects of the operation at once
    g_object_ref(obj);
    SET_VIX_RESULT(res, g_object_to_erl_term(env, obj));
  } else {
    res.is_success = false;
    res.result = ATOM_NULL_VALUE;
  }

  return res;
}

VixResult get_erl_term_from_g_object_property(ErlNifEnv *env, GObject *obj,
                                              const char *name,
                                              GParamSpec *pspec) {
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
    res = get_string_as_binary(env, &gvalue);
  else if (G_IS_PARAM_SPEC_BOXED(pspec))
    res = get_boxed(env, &gvalue);
  else if (G_IS_PARAM_SPEC_OBJECT(pspec))
    res = get_g_object(env, &gvalue);
  else if (G_IS_PARAM_SPEC_FLAGS(pspec))
    res = get_flags(env, &gvalue);
  else
    SET_ERROR_RESULT(env, "unknown pspec", res);

  g_value_unset(&gvalue);
  return res;
}

VixResult g_value_to_erl_term(ErlNifEnv *env, GValue gvalue) {
  VixResult res;
  GType type;

  type = G_VALUE_TYPE(&gvalue);

  debug("G_VALUE_TYPE: %s", g_type_name(type));

  if (type == G_TYPE_BOOLEAN)
    res = get_boolean(env, &gvalue);
  else if (type == G_TYPE_UINT64)
    res = get_uint64(env, &gvalue);
  else if (type == G_TYPE_DOUBLE)
    res = get_double(env, &gvalue);
  else if (type == G_TYPE_INT)
    res = get_int(env, &gvalue);
  else if (type == G_TYPE_UINT)
    res = get_uint(env, &gvalue);
  else if (type == G_TYPE_INT64)
    res = get_int64(env, &gvalue);
  else if (type == G_TYPE_STRING)
    res = get_string_as_binary(env, &gvalue);
  else if (G_TYPE_IS_BOXED(type))
    res = get_boxed(env, &gvalue);
  else if (G_TYPE_IS_ENUM(type))
    res = get_enum_as_atom(env, &gvalue);
  else if (G_TYPE_IS_OBJECT(type))
    res = get_g_object(env, &gvalue);
  else if (G_TYPE_IS_FLAGS(type))
    res = get_flags_as_atoms(env, &gvalue);
  else
    SET_ERROR_RESULT(env, "specified GValue type is not supported", res);

  g_value_unset(&gvalue);
  return res;
}

VixResult erl_term_to_g_value(ErlNifEnv *env, GType type, ERL_NIF_TERM term,
                              GValue *gvalue) {
  VixResult res;

  debug("G_VALUE_TYPE: %s", g_type_name(type));

  g_value_init(gvalue, type);

  if (type == G_TYPE_BOOLEAN)
    return set_boolean(env, term, gvalue);
  else if (type == G_TYPE_UINT64)
    return set_uint64(env, term, gvalue);
  else if (type == G_TYPE_DOUBLE)
    return set_double(env, term, gvalue);
  else if (type == G_TYPE_INT)
    return set_int(env, term, gvalue);
  else if (type == G_TYPE_UINT)
    return set_uint(env, term, gvalue);
  else if (type == G_TYPE_INT64)
    return set_int64(env, term, gvalue);
  else if (type == G_TYPE_STRING)
    return set_string(env, term, gvalue);
  else if (G_TYPE_IS_BOXED(type))
    return set_boxed(env, term, gvalue);
  else if (G_TYPE_IS_ENUM(type))
    return set_enum(env, term, gvalue);
  else if (G_TYPE_IS_OBJECT(type))
    return set_g_object(env, term, gvalue);
  else if (G_TYPE_IS_FLAGS(type))
    return set_flags(env, term, gvalue);
  else {
    SET_ERROR_RESULT(env, "specified GValue type is not supported", res);
    return res;
  }
}
