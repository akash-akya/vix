#include "nif_g_value.h"
#include "nif_g_boxed.h"
#include "nif_g_object.h"
#include "vix_utils.h"
#include <glib-object.h>

static GValueResult set_enum(ErlNifEnv *env, GParamSpec *pspec,
                             ERL_NIF_TERM term, GValue *gvalue) {
  GValueResult res = {true, 0};
  char enum_string[512];

  if (enif_get_atom(env, term, (char *)&enum_string, 512, ERL_NIF_LATIN1) < 1) {
    error("failed to get enum atom");
    res.is_success = false;
    return res;
  }

  GParamSpecEnum *pspec_enum = G_PARAM_SPEC_ENUM(pspec);
  GEnumValue *g_enum_value =
      g_enum_get_value_by_name(pspec_enum->enum_class, enum_string);

  if (!g_enum_value) {
    error("Could not find enum value");
    res.is_success = false;
    return res;
  }

  g_value_set_enum(gvalue, g_enum_value->value);
  return res;
}

static GValueResult set_flags(ErlNifEnv *env, GParamSpec *pspec,
                              ERL_NIF_TERM list, GValue *gvalue) {
  GValueResult res = {true, 0};
  char flag_string[512];

  ERL_NIF_TERM head;
  unsigned int length;

  GParamSpecFlags *pspec_flags;
  GFlagsValue *g_flags_value;

  if (enif_get_list_length(env, list, &length)) {
    error("Failed to get list length");
    res.is_success = false;
    return res;
  }

  int flag = 0;

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      error("Failed to get list entry");
      res.is_success = false;
      return res;
    }

    if (enif_get_atom(env, head, (char *)&flag_string, 512, ERL_NIF_LATIN1) <
        1) {
      error("failed to get flag atom");
      res.is_success = false;
      return res;
    }

    pspec_flags = G_PARAM_SPEC_FLAGS(pspec);
    g_flags_value =
        g_flags_get_value_by_name(pspec_flags->flags_class, flag_string);

    if (!g_flags_value) {
      error("Could not find enum value");
      res.is_success = false;
      return res;
    }

    flag = flag | g_flags_value->value;
  }

  g_value_set_flags(gvalue, flag);
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

static GValueResult set_uint(ErlNifEnv *env, ERL_NIF_TERM term,
                             GValue *gvalue) {
  unsigned int uint_value;
  GValueResult res = {true, 0};

  if (!enif_get_uint(env, term, &uint_value)) {
    error("failed to get uint from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_uint(gvalue, uint_value);
  return res;
}

static GValueResult set_int64(ErlNifEnv *env, ERL_NIF_TERM term,
                              GValue *gvalue) {
  long int64_value;
  GValueResult res = {true, 0};

  if (!enif_get_int64(env, term, &int64_value)) {
    error("failed to get int64 from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_int64(gvalue, int64_value);
  return res;
}

static GValueResult set_string(ErlNifEnv *env, ERL_NIF_TERM term,
                               GValue *gvalue) {
  GValueResult res = {true, 0};
  char value[512];

  if (enif_get_string(env, term, (char *)&value, 511, ERL_NIF_LATIN1) < 0) {
    error("failed to get string from erl term");
    res.is_success = false;
    return res;
  }

  g_value_set_string(gvalue, value);
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
    res = set_enum(env, pspec, term, gvalue);
  } else if (G_IS_PARAM_SPEC_BOOLEAN(pspec)) {
    res = set_boolean(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_UINT64(pspec)) {
    res = set_uint64(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_DOUBLE(pspec)) {
    res = set_double(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_INT(pspec)) {
    res = set_int(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_UINT(pspec)) {
    res = set_uint(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_INT64(pspec)) {
    res = set_int64(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_STRING(pspec)) {
    res = set_string(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_BOXED(pspec)) {
    res = set_boxed(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_OBJECT(pspec)) {
    res = set_g_object(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_FLAGS(pspec)) {
    res = set_flags(env, pspec, term, gvalue);
  } else {
    error("Invalid pspec");
    res.is_success = false;
  }

  return res;
}
