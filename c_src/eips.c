#include <glib-object.h>
#include <stdio.h>
#include <vips/vips.h>

#include "eips_common.h"
#include "nif_g_object.h"
#include "nif_g_param_spec.h"
#include "nif_g_type.h"
#include "nif_g_value.h"
#include "nif_vips_object.h"

ERL_NIF_TERM ATOM_TRUE;
ERL_NIF_TERM ATOM_FALSE;
ERL_NIF_TERM ATOM_OK;
ERL_NIF_TERM ATOM_ERROR;

/* VipsArgumentFlags */
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_NONE;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_REQUIRED;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_CONSTRUCT;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_SET_ONCE;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_SET_ALWAYS;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_INPUT;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_OUTPUT;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_DEPRECATED;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_MODIFY;

static const int MAX_PATH_LEN = 1024;

static inline ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

typedef struct EipsResult {
  bool success;
  ERL_NIF_TERM term; // error in case of success == false
} EipsResult;

static ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg) {
  return enif_raise_exception(env, enif_make_string(env, msg, ERL_NIF_LATIN1));
}

static EipsResult get_operation_properties(ErlNifEnv *env, VipsOperation *op,
                                           ERL_NIF_TERM list) {

  EipsResult result;
  unsigned int length = 0;

  if (!enif_get_list_length(env, list, &length)) {
    error("Failed to get list length");
    result.success = false;
    result.term = enif_make_badarg(env);
    return result;
  }

  ERL_NIF_TERM head, erl_terms[length];
  const ERL_NIF_TERM *tup;
  int count;

  char name[1024];
  GType g_type;
  char g_type_nickname[1024];

  GValue gvalue = {0};
  GObject *g_object;

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      error("Failed to get list");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (!enif_get_tuple(env, head, &count, &tup)) {
      error("Failed to get tuple");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (count != 2) {
      error("Tuple length must be 2");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (enif_get_string(env, tup[0], name, 1024, ERL_NIF_LATIN1) < 0) {
      error("failed to get param name");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (enif_get_string(env, tup[1], g_type_nickname, 1024, ERL_NIF_LATIN1) <
        0) {
      error("failed to get GType nickname argument");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }
    g_type = vips_type_find("VipsObject", g_type_nickname);

    g_value_init(&gvalue, g_type);
    g_object_get_property(G_OBJECT(op), name, &gvalue);

    g_object = g_value_get_object(&gvalue);
    erl_terms[i] = g_object_to_erl_term(env, g_object);
    g_value_unset(&gvalue);
  }

  result.success = true;
  result.term = enif_make_list_from_array(env, erl_terms, length);

  return result;
}

static EipsResult set_operation_properties(ErlNifEnv *env, VipsOperation *op,
                                           ERL_NIF_TERM list) {

  EipsResult result;
  unsigned int length = 0;

  if (!enif_get_list_length(env, list, &length)) {
    error("Failed to get list length");
    result.success = false;
    result.term = enif_make_badarg(env);
    return result;
  }

  ERL_NIF_TERM head;
  const ERL_NIF_TERM *tup;
  int count;

  char name[1024];
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;

  GValue gvalue = {0};

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      error("Failed to get list");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (!enif_get_tuple(env, head, &count, &tup)) {
      error("Failed to get tuple");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (count != 2) {
      error("Tuple length must be 2");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (enif_get_string(env, tup[0], name, 1024, ERL_NIF_LATIN1) < 0) {
      error("failed to get param name");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    if (vips_object_get_argument(VIPS_OBJECT(op), name, &pspec, &arg_class,
                                 &arg_instance)) {
      error("failed to get argument: %s", name);
      result.success = false;
      result.term = raise_exception(env, "failed to get argument");
      return result;
    }

    GValueResult res = set_g_value_from_erl_term(env, pspec, tup[1], &gvalue);
    if (!res.is_success) {
      result.success = false;
      result.term = res.term;
      return result;
    }

    g_object_set_property(G_OBJECT(op), name, &gvalue);
    g_value_unset(&gvalue);
  }

  result.success = true;
  return result;
}

static ERL_NIF_TERM nif_operation_call_with_args(ErlNifEnv *env, int argc,
                                                 const ERL_NIF_TERM argv[]) {
  ERL_NIF_TERM result;
  VipsOperation *op = NULL;

  if (argc != 3) {
    error("number of arguments must be 3");
    result = enif_make_badarg(env);
    goto exit;
  }

  char op_name[200] = {'\0'};
  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1) {
    error("operation name must be a valid string");
    result = enif_make_badarg(env);
    goto exit;
  }
  op = vips_operation_new(op_name);

  debug("created operation");

  EipsResult op_result = set_operation_properties(env, op, argv[1]);
  if (!op_result.success) {
    result = op_result.term;
    goto exit;
  }

  debug("set operation properties");

  VipsOperation *new_op;
  if (!(new_op = vips_cache_operation_build(op))) {
    error("Failed to call vips operation: %s", vips_error_buffer());
    result = enif_raise_exception(
        env,
        enif_make_string(env, "Failed to call VipsOperation", ERL_NIF_LATIN1));
    goto exit;
  }

  debug("run operation");

  g_object_unref(op);
  op = new_op;

  op_result = get_operation_properties(env, op, argv[2]);
  if (!op_result.success) {
    error("NIF Vips Operation get operation properties failed");
    result = op_result.term;
    goto exit;
  }
  debug("got operation properties");
  result = op_result.term;

exit:
  if (op) {
    /* vips_object_unref_outputs(VIPS_OBJECT(op)); */
    /* g_object_unref(op); */
  }
  return result;
}

static ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  char src[MAX_PATH_LEN + 1];
  VipsImage *image;

  if (enif_get_string(env, argv[0], src, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0)
    return enif_make_badarg(env);

  image = vips_image_new_from_file(src, NULL);

  if (!image) {
    error("Failed to read image");
    return enif_raise_exception(
        env, enif_make_string(env, "\"nif_image_new_from_file\" failed",
                              ERL_NIF_LATIN1));
  }

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
}

static ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  if (argc != 2) {
    error("number of arguments must be 2");
    return enif_make_badarg(env);
  }

  char dst[MAX_PATH_LEN + 1];
  VipsImage *image;

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    error("Failed to get VipsImage");
    return enif_make_badarg(env);
  }

  if (enif_get_string(env, argv[1], dst, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0) {
    error("Failed to get image destination path");
    return enif_make_badarg(env);
  }

  int ret = vips_image_write_to_file(image, dst, NULL);

  if (ret) {
    error("Failed to write VipsImage");
    return enif_raise_exception(
        env,
        enif_make_string(env, "Failed to write VipsImage", ERL_NIF_LATIN1));
  }

  return ATOM_OK;
}

static ERL_NIF_TERM vips_argument_class_to_erl_term(ErlNifEnv *env,
                                                    VipsArgumentClass *class) {
  ERL_NIF_TERM pspec_term = g_param_spec_to_erl_term(env, class->parent.pspec);

  ERL_NIF_TERM g_type =
      g_type_to_erl_term(env, class->parent.pspec->value_type);

  debug("class name: %s -> %s", g_type_name(class->parent.pspec->value_type),
        class->object_class->description);

  /* debug("GType: %d", class->parent.pspec->value_type); */
  /* print_g_type_name(class->parent.pspec); */
  /* vips_object_print_summary_class(class->object_class); */

  ERL_NIF_TERM priority = enif_make_int(env, class->priority);
  ERL_NIF_TERM offset = enif_make_uint(env, class->offset);

  return enif_make_tuple4(env, pspec_term, g_type, priority, offset);
}

#define VIPS_ARGUMENT_COUNT 8

static ERL_NIF_TERM vips_argument_flags_to_erl_terms(ErlNifEnv *env,
                                                     int flags) {
  ERL_NIF_TERM erl_terms[8];
  int len = 0;

  if (flags & VIPS_ARGUMENT_REQUIRED) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_REQUIRED;
    len++;
  }

  if (flags & VIPS_ARGUMENT_CONSTRUCT) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_CONSTRUCT;
    len++;
  }

  if (flags & VIPS_ARGUMENT_SET_ONCE) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_SET_ONCE;
    len++;
  }

  if (flags & VIPS_ARGUMENT_SET_ALWAYS) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_SET_ALWAYS;
    len++;
  }

  if (flags & VIPS_ARGUMENT_INPUT) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_INPUT;
    len++;
  }

  if (flags & VIPS_ARGUMENT_OUTPUT) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_OUTPUT;
    len++;
  }

  if (flags & VIPS_ARGUMENT_DEPRECATED) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_DEPRECATED;
    len++;
  }

  if (flags & VIPS_ARGUMENT_MODIFY) {
    erl_terms[len] = ATOM_VIPS_ARGUMENT_MODIFY;
    len++;
  }

  return enif_make_list_from_array(env, erl_terms, len);
}

static ERL_NIF_TERM eips_get_argument(ErlNifEnv *env, VipsOperation *op,
                                      const char *arg_name) {
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;

  if (vips_object_get_argument(VIPS_OBJECT(op), arg_name, &pspec, &arg_class,
                               &arg_instance)) {
    error("\"vips_object_get_argument\" failed");
    return enif_raise_exception(
        env, enif_make_string(env, "\"vips_object_get_argument\" failed",
                              ERL_NIF_LATIN1));
  }
  return vips_argument_class_to_erl_term(env, arg_class);
}

static ERL_NIF_TERM nif_get_op_arguments(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    return enif_make_badarg(env);
  }

  VipsOperation *op;

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&op)) {
    error("Failed to get VipsObject");
    return enif_make_badarg(env);
  }

  const char **names;
  int *flags;
  int n_args = 0;

  if (vips_object_get_args(VIPS_OBJECT(op), &names, &flags, &n_args)) {
    error("failed to get args for the operation");
    return enif_raise_exception(
        env,
        enif_make_string(env, "failed to get VipsObject args", ERL_NIF_LATIN1));
  }

  ERL_NIF_TERM erl_terms[n_args];
  ERL_NIF_TERM erl_flags, erl_name, erl_arg;

  for (int i = 0; i < n_args; i++) {
    erl_arg = eips_get_argument(env, op, names[i]);
    erl_name = enif_make_string(env, names[i], ERL_NIF_LATIN1);
    erl_flags = vips_argument_flags_to_erl_terms(env, flags[i]);
    /* erl_flag = enif_make_int(env, flags[i]); */

    erl_terms[i] = enif_make_tuple3(env, erl_name, erl_arg, erl_flags);
  }

  return enif_make_list_from_array(env, erl_terms, n_args);
}

static ERL_NIF_TERM nif_create_op(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    return enif_make_badarg(env);
  }

  char op_name[200] = {'\0'};
  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1) {
    error("operator name must be a valid string");
    return enif_make_badarg(env);
  }

  VipsOperation *op = vips_operation_new(op_name);
  return make_ok(env, g_object_to_erl_term(env, (GObject *)op));
}

static ERL_NIF_TERM nif_vips_type_find(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    return enif_make_badarg(env);
  }

  char nickname[200] = {'\0'};
  if (enif_get_string(env, argv[0], nickname, 200, ERL_NIF_LATIN1) < 1) {
    error("operator name must be a valid string");
    return enif_make_badarg(env);
  }

  GType g_type = vips_type_find("VipsObject", nickname);

  if (!g_type) {
    error("Class not found %s", nickname);
    return enif_make_badarg(env);
  }

  return make_ok(env, g_type_to_erl_term(env, g_type));
}

static ERL_NIF_TERM nif_get_enum_value(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  if (argc != 2) {
    error("number of arguments must be 2");
    return enif_make_badarg(env);
  }

  GParamSpec *pspec;
  if (!erl_term_to_g_param_spec(env, argv[0], &pspec)) {
    error("param must be a GParamSpec");
    return enif_make_badarg(env);
  }

  char enum_string[250] = {0};
  if (enif_get_string(env, argv[1], enum_string, 250, ERL_NIF_LATIN1) < 1) {
    error("param must be a string");
    return enif_make_badarg(env);
  }

  GParamSpecEnum *pspec_enum = G_PARAM_SPEC_ENUM(pspec);
  GEnumValue *g_enum_value =
      g_enum_get_value_by_name(pspec_enum->enum_class, enum_string);

  if (!g_enum_value) {
    error("Could not find enum value");
    return raise_exception(env, "Could not find enum value");
  }
  return enif_make_int(env, g_enum_value->value);
}

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info) {

  ATOM_TRUE = enif_make_atom(env, "true");
  ATOM_FALSE = enif_make_atom(env, "false");
  ATOM_OK = enif_make_atom(env, "ok");
  ATOM_ERROR = enif_make_atom(env, "error");

  nif_g_type_init(env);
  nif_g_object_init(env);
  nif_g_param_spec_init(env);

  ATOM_VIPS_ARGUMENT_NONE = enif_make_atom(env, "vips_argument_none");
  ATOM_VIPS_ARGUMENT_REQUIRED = enif_make_atom(env, "vips_argument_required");
  ATOM_VIPS_ARGUMENT_CONSTRUCT = enif_make_atom(env, "vips_argument_construct");
  ATOM_VIPS_ARGUMENT_SET_ONCE = enif_make_atom(env, "vips_argument_set_once");
  ATOM_VIPS_ARGUMENT_SET_ALWAYS =
      enif_make_atom(env, "vips_argument_set_always");
  ATOM_VIPS_ARGUMENT_INPUT = enif_make_atom(env, "vips_argument_input");
  ATOM_VIPS_ARGUMENT_OUTPUT = enif_make_atom(env, "vips_argument_output");
  ATOM_VIPS_ARGUMENT_DEPRECATED =
      enif_make_atom(env, "vips_argument_deprecated");
  ATOM_VIPS_ARGUMENT_MODIFY = enif_make_atom(env, "vips_argument_modify");

  if (VIPS_INIT(""))
    return 1;

  return 0;
}

static void on_unload(ErlNifEnv *env, void *priv) {
  vips_shutdown();
  debug("eips unload");
}

static ErlNifFunc nif_funcs[] = {
    {"nif_image_new_from_file", 1, nif_image_new_from_file, USE_DIRTY_IO},
    {"nif_create_op", 1, nif_create_op, USE_DIRTY_IO},
    {"nif_get_op_arguments", 1, nif_get_op_arguments, USE_DIRTY_IO},
    {"nif_operation_call_with_args", 3, nif_operation_call_with_args,
     USE_DIRTY_IO},
    {"nif_image_write_to_file", 2, nif_image_write_to_file, USE_DIRTY_IO},
    {"nif_vips_type_find", 1, nif_vips_type_find, USE_DIRTY_IO},
    {"nif_get_enum_value", 2, nif_get_enum_value, USE_DIRTY_IO},
    /*  GObject */
    {"nif_g_object_type", 1, nif_g_object_type, USE_DIRTY_IO},
    {"nif_g_object_type_name", 1, nif_g_object_type_name, USE_DIRTY_IO},
    /*  GType */
    {"nif_g_type_name", 1, nif_g_type_name, USE_DIRTY_IO},
    {"nif_g_type_from_name", 1, nif_g_type_from_name, USE_DIRTY_IO},
    /*  GParamSpec */
    {"nif_g_param_spec_type", 1, nif_g_param_spec_type, USE_DIRTY_IO},
    {"nif_g_param_spec_get_name", 1, nif_g_param_spec_get_name, USE_DIRTY_IO},
    {"nif_g_param_spec_value_type", 1, nif_g_param_spec_value_type,
     USE_DIRTY_IO}};

ERL_NIF_INIT(Elixir.Eips.Nif, nif_funcs, &on_load, NULL, NULL, &on_unload)
