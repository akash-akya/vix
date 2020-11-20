#include <glib-object.h>
#include <stdio.h>
#include <vips/vips.h>

#include "g_object/g_boxed.h"
#include "g_object/g_object.h"
#include "g_object/g_param_spec.h"
#include "g_object/g_value.h"
#include "utils.h"
#include "vips_boxed.h"
#include "vips_operation.h"

static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_NONE;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_REQUIRED;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_CONSTRUCT;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_SET_ONCE;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_SET_ALWAYS;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_INPUT;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_OUTPUT;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_DEPRECATED;
static ERL_NIF_TERM ATOM_VIPS_ARGUMENT_MODIFY;

typedef struct GTypeList {
  GType *gtype;
  unsigned int count;
} GTypeList;

typedef struct _VipsNameFlagsPair {
  const char **names;
  int *flags;
} VipsNameFlagsPair;

static void *vips_object_find_args(VipsObject *object, GParamSpec *pspec,
                                   VipsArgumentClass *argument_class,
                                   VipsArgumentInstance *argument_instance,
                                   void *a, void *b) {
  VipsNameFlagsPair *pair = (VipsNameFlagsPair *)a;
  int *i = (int *)b;

  pair->names[*i] = g_param_spec_get_name(pspec);
  pair->flags[*i] = (int)argument_class->flags;

  *i += 1;

  return (NULL);
}

static int get_vips_operation_args(VipsOperation *op, const char ***names,
                                   int **flags, int *n_args) {
  VipsObject *object;
  VipsObjectClass *object_class;
  VipsNameFlagsPair pair;
  int n, i;

  object = VIPS_OBJECT(op);

  object_class = VIPS_OBJECT_GET_CLASS(object);
  n = g_slist_length(object_class->argument_table_traverse);

  pair.names = VIPS_ARRAY(object, n, const char *);
  pair.flags = VIPS_ARRAY(object, n, int);
  if (!pair.names || !pair.flags)
    return (-1);

  i = 0;
  (void)vips_argument_map(object, vips_object_find_args, &pair, &i);

  if (names)
    *names = pair.names;
  if (flags)
    *flags = pair.flags;
  if (n_args)
    *n_args = n;

  return (0);
}

static ERL_NIF_TERM vips_argument_flags_to_erl_terms(ErlNifEnv *env,
                                                     int flags) {
  ERL_NIF_TERM list;

  list = enif_make_list(env, 0);

  if (flags & VIPS_ARGUMENT_REQUIRED)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_REQUIRED, list);

  if (flags & VIPS_ARGUMENT_CONSTRUCT)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_CONSTRUCT, list);

  if (flags & VIPS_ARGUMENT_SET_ONCE)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_SET_ONCE, list);

  if (flags & VIPS_ARGUMENT_SET_ALWAYS)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_SET_ALWAYS, list);

  if (flags & VIPS_ARGUMENT_INPUT)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_INPUT, list);

  if (flags & VIPS_ARGUMENT_OUTPUT)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_OUTPUT, list);

  if (flags & VIPS_ARGUMENT_DEPRECATED)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_DEPRECATED, list);

  if (flags & VIPS_ARGUMENT_MODIFY)
    list = enif_make_list_cell(env, ATOM_VIPS_ARGUMENT_MODIFY, list);

  return list;
}

static ERL_NIF_TERM get_operation_properties(ErlNifEnv *env,
                                             VipsOperation *op) {

  GValue gvalue = {0};
  GObject *obj;

  const char **names;
  int *flags;
  int n_args = 0;

  if (get_vips_operation_args(op, &names, &flags, &n_args)) {
    error("failed to get args. error: %s", vips_error_buffer());
    vips_error_clear();
    return enif_make_badarg(env);
  }

  ERL_NIF_TERM list;
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;

  list = enif_make_list(env, 0);

  for (int i = 0; i < n_args; i++) {
    if (flags[i] & VIPS_ARGUMENT_OUTPUT) {
      if (vips_object_get_argument(VIPS_OBJECT(op), names[i], &pspec,
                                   &arg_class, &arg_instance)) {
        error("failed to get argument: %s", names[i]);
        return raise_exception(env, "failed to get argument");
      }

      g_value_init(&gvalue, G_PARAM_SPEC_VALUE_TYPE(pspec));
      g_object_get_property(G_OBJECT(op), names[i], &gvalue);

      obj = g_value_get_object(&gvalue);
      list = enif_make_list_cell(env, g_object_to_erl_term(env, obj), list);
      g_value_unset(&gvalue);
    }
  }

  return list;
}

static ERL_NIF_TERM set_operation_properties(ErlNifEnv *env, VipsOperation *op,
                                             ERL_NIF_TERM list) {
  unsigned int length = 0;

  if (!enif_get_list_length(env, list, &length)) {
    error("Failed to get list length");
    return enif_make_badarg(env);
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
      return enif_make_badarg(env);
    }

    if (!enif_get_tuple(env, head, &count, &tup)) {
      error("Failed to get tuple");
      return enif_make_badarg(env);
    }

    if (count != 2) {
      error("Tuple length must be of length 2");
      return enif_make_badarg(env);
    }

    if (enif_get_string(env, tup[0], name, 1024, ERL_NIF_LATIN1) < 0) {
      error("failed to get param name");
      return enif_make_badarg(env);
    }

    if (vips_object_get_argument(VIPS_OBJECT(op), name, &pspec, &arg_class,
                                 &arg_instance)) {
      error("failed to get argument: %s", name);
      return raise_exception(env, "failed to get argument");
    }

    ERL_NIF_TERM res = set_g_value_from_erl_term(env, pspec, tup[1], &gvalue);
    if (enif_is_exception(env, res))
      return res;

    g_object_set_property(G_OBJECT(op), name, &gvalue);
    g_value_unset(&gvalue);
  }

  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_operation_call(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  ERL_NIF_TERM result;
  VipsOperation *op = NULL;

  assert_argc(argc, 2);

  char op_name[200] = {'\0'};
  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1) {
    error("operation name must be a valid string");
    result = enif_make_badarg(env);
    goto exit;
  }

  op = vips_operation_new(op_name);

  result = set_operation_properties(env, op, argv[1]);
  if (enif_is_exception(env, result)) {
    error("failed to set input properties");
    goto exit;
  }

  VipsOperation *new_op;
  if (!(new_op = vips_cache_operation_build(op))) {
    error("failed to build operation, error: %s", vips_error_buffer());
    vips_error_clear();
    result = raise_exception(env, "failed to build operation");
    goto exit;
  }

  g_object_unref(op);
  op = new_op;

  result = get_operation_properties(env, op);
  if (enif_is_exception(env, result)) {
    error("failed to get output properties");
    goto exit;
  }

exit:
  if (op) {
    vips_object_unref_outputs(VIPS_OBJECT(op));
    g_object_unref(op);
  }
  return result;
}

ERL_NIF_TERM nif_vips_operation_get_arguments(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 1);

  VipsOperation *op;
  char op_name[200] = {0};
  const char **names;
  int *flags;
  int n_args = 0;
  ERL_NIF_TERM list, erl_flags, name, priority, tup, description;
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;

  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1)
    return raise_badarg(env, "operation name must be a valid string");

  op = vips_operation_new(op_name);

  if (get_vips_operation_args(op, &names, &flags, &n_args) != 0) {
    error("failed to get VipsObject arguments. error: %s", vips_error_buffer());
    vips_error_clear();
    return raise_exception(env, "failed to get VipsObject arguments");
  }

  description = enif_make_string(
      env, vips_object_get_description(VIPS_OBJECT(op)), ERL_NIF_LATIN1);

  list = enif_make_list(env, 0);

  for (int i = 0; i < n_args; i++) {
    name = enif_make_string(env, names[i], ERL_NIF_LATIN1);
    erl_flags = vips_argument_flags_to_erl_terms(env, flags[i]);

    if (vips_object_get_argument(VIPS_OBJECT(op), names[i], &pspec, &arg_class,
                                 &arg_instance)) {
      error("failed to get VipsObject argument. error: %s",
            vips_error_buffer());
      vips_error_clear();
      return raise_exception(env, "failed to get VipsObject argument");
    }

    priority = enif_make_int(env, arg_class->priority);
    tup = enif_make_tuple4(env, name, g_param_spec_details(env, pspec),
                           priority, erl_flags);
    list = enif_make_list_cell(env, tup, list);
  }

  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

  return enif_make_tuple2(env, description, list);
}

static void *list_class(GType type, void *user_data) {
  gpointer g_class;
  VipsObjectClass *class;

  g_class = g_type_class_ref(type);
  class = VIPS_OBJECT_CLASS(g_class);

  if (class->deprecated)
    return (NULL);
  if (VIPS_IS_OPERATION_CLASS(class) &&
      (VIPS_OPERATION_CLASS(class)->flags & VIPS_OPERATION_DEPRECATED))
    return (NULL);
  if (G_TYPE_IS_ABSTRACT(type))
    return (NULL);
  if (G_TYPE_CHECK_CLASS_TYPE(class, VIPS_TYPE_FOREIGN))
    return (NULL);

  GTypeList *list = (GTypeList *)user_data;

  list->gtype[list->count] = type;
  list->count = list->count + 1;

  g_type_class_unref(g_class);

  return (NULL);
}

ERL_NIF_TERM nif_vips_operation_list(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 0);

  GType _gtype[1024], gtype;
  GTypeList list;
  ERL_NIF_TERM erl_term, name;
  gpointer g_class;

  list.gtype = (GType *)&_gtype;
  list.count = 0;

  vips_type_map_all(VIPS_TYPE_OPERATION, list_class, &list);

  erl_term = enif_make_list(env, 0);

  for (unsigned int i = 0; i < list.count; i++) {
    gtype = list.gtype[i];
    g_class = g_type_class_ref(gtype);

    name = enif_make_string(env, vips_nickname_find(list.gtype[i]),
                            ERL_NIF_LATIN1);

    erl_term = enif_make_list_cell(env, name, erl_term);

    g_type_class_unref(g_class);
  }

  return erl_term;
}

ERL_NIF_TERM nif_vips_enum_list(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 0);

  GType gtype;
  GType *types;
  gpointer g_class;
  GEnumClass *enum_class;
  ERL_NIF_TERM enum_values, tuple, enum_str, enum_int, enums, name;
  guint count = 0;

  types = g_type_children(G_TYPE_ENUM, &count);
  enums = enif_make_list(env, 0);

  for (guint i = 0; i < count; i++) {
    gtype = types[i];

    g_class = g_type_class_ref(gtype);
    enum_class = G_ENUM_CLASS(g_class);

    enum_values = enif_make_list(env, 0);

    for (unsigned int j = 0; j < enum_class->n_values - 1; j++) {
      enum_str = make_atom(env, enum_class->values[j].value_name);
      enum_int = enif_make_int(env, enum_class->values[j].value);

      tuple = enif_make_tuple2(env, enum_str, enum_int);
      enum_values = enif_make_list_cell(env, tuple, enum_values);
    }

    name = enif_make_string(env, g_type_name(gtype), ERL_NIF_LATIN1);
    enums = enif_make_list_cell(env, enif_make_tuple2(env, name, enum_values),
                                enums);

    g_type_class_unref(g_class);
  }

  g_free(types);
  return enums;
}

ERL_NIF_TERM nif_vips_flag_list(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 0);

  GType gtype;
  GType *types;
  gpointer g_class;
  GFlagsClass *flag_class;
  ERL_NIF_TERM flag_values, tuple, flag_str, flag_int, flags, name;
  guint count = 0;

  types = g_type_children(G_TYPE_FLAGS, &count);
  flags = enif_make_list(env, 0);

  for (guint i = 0; i < count; i++) {
    gtype = types[i];

    g_class = g_type_class_ref(gtype);
    flag_class = G_FLAGS_CLASS(g_class);

    flag_values = enif_make_list(env, 0);

    for (unsigned int j = 0; j < flag_class->n_values - 1; j++) {
      flag_str = make_atom(env, flag_class->values[j].value_name);
      flag_int = enif_make_int(env, flag_class->values[j].value);

      tuple = enif_make_tuple2(env, flag_str, flag_int);
      flag_values = enif_make_list_cell(env, tuple, flag_values);
    }

    name = enif_make_string(env, g_type_name(gtype), ERL_NIF_LATIN1);
    flags = enif_make_list_cell(env, enif_make_tuple2(env, name, flag_values),
                                flags);

    g_type_class_unref(g_class);
  }

  g_free(types);
  return flags;
}

ERL_NIF_TERM nif_vips_cache_set_max(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  int max_op;

  if (!enif_get_int(env, argv[0], &max_op)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_cache_set_max(max_op);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_cache_get_max(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);
  return make_ok(env, enif_make_int(env, vips_cache_get_max()));
}

ERL_NIF_TERM nif_vips_concurrency_set(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  int concurrency;

  if (!enif_get_int(env, argv[0], &concurrency)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_concurrency_set(concurrency);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_concurrency_get(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);
  return make_ok(env, enif_make_int(env, vips_concurrency_get()));
}

ERL_NIF_TERM nif_vips_cache_set_max_files(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  int max_files;

  if (!enif_get_int(env, argv[0], &max_files)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_cache_set_max_files(max_files);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_cache_get_max_files(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);
  return make_ok(env, enif_make_int(env, vips_cache_get_max_files()));
}

ERL_NIF_TERM nif_vips_cache_set_max_mem(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  unsigned long max_mem;

  if (!enif_get_uint64(env, argv[0], &max_mem)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_cache_set_max_mem(max_mem);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_cache_get_max_mem(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);
  return make_ok(env, enif_make_uint64(env, vips_cache_get_max_mem()));
}

static bool load_operation(GType type) {
  const char **names;
  gpointer g_class;
  VipsObjectClass *class;
  VipsOperation *op;
  bool err = true;

  int n_args = 0;
  int *flags;

  g_class = g_type_class_ref(type);
  class = VIPS_OBJECT_CLASS(g_class);

  if (class->deprecated)
    goto unref_class_exit;
  if (VIPS_IS_OPERATION_CLASS(class) &&
      (VIPS_OPERATION_CLASS(class)->flags & VIPS_OPERATION_DEPRECATED))
    goto unref_class_exit;

  op = vips_operation_new(vips_nickname_find(type));

  if (op == NULL)
    goto unref_class_exit;

  if (get_vips_operation_args(op, &names, &flags, &n_args) != 0) {
    error("failed to get VipsObject arguments. error: %s", vips_error_buffer());
    vips_error_clear();
  } else {
    err = false;
  }

  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

unref_class_exit:
  g_type_class_unref(g_class);

  return err;
}

static int load_vips_types(ErlNifEnv *env) {
  bool err;
  guint count;
  GType *types;

  types = g_type_children(VIPS_TYPE_OPERATION, &count);

  for (guint i = 0; i < count; i++) {
    err = load_operation(types[i]);
    if (!err)
      break;
  }

  g_free(types);
  return err ? 1 : 0;
}

int nif_vips_operation_init(ErlNifEnv *env) {
  ATOM_VIPS_ARGUMENT_NONE = make_atom(env, "vips_argument_none");
  ATOM_VIPS_ARGUMENT_REQUIRED = make_atom(env, "vips_argument_required");
  ATOM_VIPS_ARGUMENT_CONSTRUCT = make_atom(env, "vips_argument_construct");
  ATOM_VIPS_ARGUMENT_SET_ONCE = make_atom(env, "vips_argument_set_once");
  ATOM_VIPS_ARGUMENT_SET_ALWAYS = make_atom(env, "vips_argument_set_always");
  ATOM_VIPS_ARGUMENT_INPUT = make_atom(env, "vips_argument_input");
  ATOM_VIPS_ARGUMENT_OUTPUT = make_atom(env, "vips_argument_output");
  ATOM_VIPS_ARGUMENT_DEPRECATED = make_atom(env, "vips_argument_deprecated");
  ATOM_VIPS_ARGUMENT_MODIFY = make_atom(env, "vips_argument_modify");

  /* There is a race condition; if we attempt to access subclass of a
     class before definitions are "loaded" we won't be able to get any
     entries */
  return load_vips_types(env);
}
