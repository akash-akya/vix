#include <glib-object.h>

#include "../utils.h"

#include "g_value.h"
#include "g_boxed.h"
#include "g_object.h"

static ERL_NIF_TERM set_enum(ErlNifEnv *env, GParamSpec *pspec,
                             ERL_NIF_TERM term, GValue *gvalue) {
  char enum_string[512];

  if (enif_get_atom(env, term, (char *)&enum_string, 512, ERL_NIF_LATIN1) < 1) {
    error("failed to get enum atom");
    return raise_exception(env, "failed to get enum atom");
  }

  GParamSpecEnum *pspec_enum = G_PARAM_SPEC_ENUM(pspec);
  GEnumValue *g_enum_value =
      g_enum_get_value_by_name(pspec_enum->enum_class, enum_string);

  if (!g_enum_value) {
    error("Could not find enum value");
    return raise_exception(env, "Could not find enum value");
  }

  g_value_set_enum(gvalue, g_enum_value->value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_flags(ErlNifEnv *env, GParamSpec *pspec,
                              ERL_NIF_TERM list, GValue *gvalue) {
  char flag_string[512];

  ERL_NIF_TERM head;
  unsigned int length;

  GParamSpecFlags *pspec_flags;
  GFlagsValue *g_flags_value;

  if (enif_get_list_length(env, list, &length)) {
    error("Failed to get list length");
    return raise_exception(env, "Failed to get list length");
  }

  int flag = 0;

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      error("Failed to get list entry");
      return raise_exception(env, "Failed to get list entry");
    }

    if (enif_get_atom(env, head, (char *)&flag_string, 512, ERL_NIF_LATIN1) <
        1) {
      error("failed to get flag atom");
      return raise_exception(env, "failed to get flag atom");
    }

    pspec_flags = G_PARAM_SPEC_FLAGS(pspec);
    g_flags_value =
        g_flags_get_value_by_name(pspec_flags->flags_class, flag_string);

    if (!g_flags_value) {
      error("Could not find enum value");
      return raise_exception(env, "Could not find enum value");
    }

    flag = flag | g_flags_value->value;
  }

  g_value_set_flags(gvalue, flag);
  return ATOM_OK;
}

static ERL_NIF_TERM set_boolean(ErlNifEnv *env, ERL_NIF_TERM term,
                                GValue *gvalue) {
  char atom[10] = {0};
  bool boolean_value;

  if (enif_get_atom(env, term, atom, 9, ERL_NIF_LATIN1) < 1) {
    error("failed to get atom");
    return raise_exception(env, "failed to get atom");
  }

  if (strcmp(atom, "true") == 0) {
    boolean_value = true;
  } else if (strcmp(atom, "false") == 0) {
    boolean_value = false;
  } else {
    error("invalid atom value, value must be :true or :false");
    return raise_exception(env,
                           "invalid atom value, value must be :true or :false");
  }

  g_value_set_boolean(gvalue, boolean_value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_int(ErlNifEnv *env, ERL_NIF_TERM term, GValue *gvalue) {
  int int_value;

  if (!enif_get_int(env, term, &int_value)) {
    error("failed to get int from erl term");
    return raise_exception(env, "failed to get int from erl term");
  }

  g_value_set_int(gvalue, int_value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_uint(ErlNifEnv *env, ERL_NIF_TERM term,
                             GValue *gvalue) {
  unsigned int uint_value;

  if (!enif_get_uint(env, term, &uint_value)) {
    error("failed to get uint from erl term");
    return raise_exception(env, "failed to get uint from erl term");
  }

  g_value_set_uint(gvalue, uint_value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_int64(ErlNifEnv *env, ERL_NIF_TERM term,
                              GValue *gvalue) {
  long int64_value;

  if (!enif_get_int64(env, term, &int64_value)) {
    error("failed to get int64 from erl term");
    return raise_exception(env, "failed to get int64 from erl term");
  }

  g_value_set_int64(gvalue, int64_value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_string(ErlNifEnv *env, ERL_NIF_TERM term,
                               GValue *gvalue) {
  char value[512];

  if (enif_get_string(env, term, (char *)&value, 511, ERL_NIF_LATIN1) < 0) {
    error("failed to get string from erl term");
    return raise_exception(env, "failed to get string from erl term");
  }

  g_value_set_string(gvalue, value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_uint64(ErlNifEnv *env, ERL_NIF_TERM term,
                               GValue *gvalue) {
  unsigned long uint64_value;

  if (!enif_get_uint64(env, term, &uint64_value)) {
    error("failed to get uint64 from erl term");
    return raise_exception(env, "failed to get uint64 from erl term");
  }

  g_value_set_uint64(gvalue, uint64_value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_double(ErlNifEnv *env, ERL_NIF_TERM term,
                               GValue *gvalue) {
  double double_value;

  if (!enif_get_double(env, term, &double_value)) {
    error("failed to get double from erl term");
    return raise_exception(env, "failed to get double from erl term");
  }

  g_value_set_double(gvalue, double_value);
  return ATOM_OK;
}

static ERL_NIF_TERM set_boxed(ErlNifEnv *env, ERL_NIF_TERM term,
                              GValue *gvalue) {
  gpointer ptr = NULL;

  if (!erl_term_to_g_boxed(env, term, &ptr)) {
    error("failed to get boxed pointer from erl term");
    return raise_exception(env, "failed to get boxed pointer from erl term");
  }

  g_value_set_boxed(gvalue, ptr);
  return ATOM_OK;
}

static ERL_NIF_TERM set_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                                 GValue *gvalue) {
  GObject *g_object;

  if (!erl_term_to_g_object(env, term, &g_object)) {
    error("failed to get GObject argument");
    return raise_exception(env, "failed to get GObject argument");
  }

  g_value_set_object(gvalue, g_object);
  return ATOM_OK;
}

ERL_NIF_TERM set_g_value_from_erl_term(ErlNifEnv *env, GParamSpec *pspec,
                                       ERL_NIF_TERM term, GValue *gvalue) {
  g_value_init(gvalue, G_PARAM_SPEC_VALUE_TYPE(pspec));

  if (G_IS_PARAM_SPEC_ENUM(pspec)) {
    return set_enum(env, pspec, term, gvalue);
  } else if (G_IS_PARAM_SPEC_BOOLEAN(pspec)) {
    return set_boolean(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_UINT64(pspec)) {
    return set_uint64(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_DOUBLE(pspec)) {
    return set_double(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_INT(pspec)) {
    return set_int(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_UINT(pspec)) {
    return set_uint(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_INT64(pspec)) {
    return set_int64(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_STRING(pspec)) {
    return set_string(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_BOXED(pspec)) {
    return set_boxed(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_OBJECT(pspec)) {
    return set_g_object(env, term, gvalue);
  } else if (G_IS_PARAM_SPEC_FLAGS(pspec)) {
    return set_flags(env, pspec, term, gvalue);
  } else {
    error("Unknown pspec");
    return raise_exception(env, "Unknown pspec");
  }
}
