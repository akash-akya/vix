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

typedef struct _GTypeList {
  GType *types;
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

static VixResult get_operation_properties(ErlNifEnv *env, VipsOperation *op) {

  const char **names;
  int *flags;
  int n_args = 0;

  ERL_NIF_TERM list, name, entry;
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;
  VixResult res;

  if (get_vips_operation_args(op, &names, &flags, &n_args)) {
    error("failed to get args. error: %s", vips_error_buffer());
    vips_error_clear();
    return vix_error(env, "failed to get VipsObject output params");
  }

  list = enif_make_list(env, 0);

  for (int i = 0; i < n_args; i++) {
    if (flags[i] & VIPS_ARGUMENT_OUTPUT) {
      if (vips_object_get_argument(VIPS_OBJECT(op), names[i], &pspec,
                                   &arg_class, &arg_instance)) {
        error("failed to get argument: %s", names[i]);
        // early exit is fine, for already reffed output GObjects
        // since `g_object_dtor` takes care of unreffing
        return vix_error(env, "failed to get output argument");
      }

      res = get_erl_term_from_g_object_property(env, G_OBJECT(op), names[i],
                                                pspec);

      if (!res.is_success)
        return res;

      name = enif_make_string(env, names[i], ERL_NIF_LATIN1);
      entry = enif_make_tuple2(env, name, res.result);
      list = enif_make_list_cell(env, entry, list);
    }
  }

  return vix_result(list);
}

static VixResult set_operation_properties(ErlNifEnv *env, VipsOperation *op,
                                          ERL_NIF_TERM list) {
  guint length = 0;
  ERL_NIF_TERM head;
  VixResult res;
  const ERL_NIF_TERM *tup;
  int count;
  char name[1024];
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;

  GValue gvalue = {0};

  if (!enif_get_list_length(env, list, &length)) {
    return vix_error(env, "Failed to get list length");
  }

  for (guint i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, list, &head, &list))
      return vix_error(env, "Failed to get list");

    if (!enif_get_tuple(env, head, &count, &tup))
      return vix_error(env, "Failed to get tuple");

    if (count != 2)
      return vix_error(env, "Tuple length must be of length 2");

    if (enif_get_string(env, tup[0], name, 1024, ERL_NIF_LATIN1) < 0)
      return vix_error(env, "Failed to get param name");

    if (vips_object_get_argument(VIPS_OBJECT(op), name, &pspec, &arg_class,
                                 &arg_instance))
      return vix_error(env, "Failed to get vips argument");

    res = set_g_value_from_erl_term(env, pspec, tup[1], &gvalue);
    if (!res.is_success)
      return res;

    g_object_set_property(G_OBJECT(op), name, &gvalue);
    g_value_unset(&gvalue);
  }

  return vix_result(ATOM_OK);
}

ERL_NIF_TERM nif_vips_operation_call(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  VixResult res;
  VipsOperation *op = NULL;
  VipsOperation *new_op;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  assert_argc(argc, 2);

  char op_name[200] = {0};
  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1) {
    res = vix_error(env, "operation name must be a valid string");
    goto exit;
  }

  op = vips_operation_new(op_name);

  res = set_operation_properties(env, op, argv[1]);
  if (!res.is_success)
    goto free_and_exit;

  if (!(new_op = vips_cache_operation_build(op))) {
    error("failed to build operation, error: %s", vips_error_buffer());
    vips_error_clear();
    res = vix_error(env, "failed to build operation");
    goto free_and_exit;
  }

  g_object_unref(op);
  op = new_op;

  res = get_operation_properties(env, op);
  if (!res.is_success)
    goto free_and_exit;

free_and_exit:
  // Always unref all used objects, since we are explicitly getting
  // references for output objects
  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  if (res.is_success)
    return make_ok(env, res.result);
  else
    return enif_make_tuple2(env, ATOM_ERROR, res.result);
}

ERL_NIF_TERM nif_vips_operation_get_arguments(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 1);

  VipsOperation *op;
  char op_name[200] = {0};
  const char **names;
  int *flags;
  int n_args = 0;
  ERL_NIF_TERM list, erl_flags, name, priority, tup, description, result;
  GParamSpec *pspec;
  VipsArgumentClass *arg_class;
  VipsArgumentInstance *arg_instance;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1) {
    result = raise_badarg(env, "operation name must be a valid string");
    goto exit;
  }

  op = vips_operation_new(op_name);

  if (get_vips_operation_args(op, &names, &flags, &n_args) != 0) {
    error("failed to get VipsObject arguments. error: %s", vips_error_buffer());
    vips_error_clear();
    result = raise_exception(env, "failed to get VipsObject arguments");
    goto free_and_exit;
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
      result = raise_exception(env, "failed to get VipsObject argument");
      goto free_and_exit;
    }

    priority = enif_make_int(env, arg_class->priority);
    tup = enif_make_tuple4(env, name, g_param_spec_details(env, pspec),
                           priority, erl_flags);
    list = enif_make_list_cell(env, tup, list);
  }

  result = enif_make_tuple2(env, description, list);

free_and_exit:
  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return result;
}

static void *collect_operation_types(GType type, void *user_data) {
  gpointer g_class;
  VipsObjectClass *class;
  GTypeList *type_list;

  g_class = g_type_class_ref(type);
  class = VIPS_OBJECT_CLASS(g_class);

  if (class->deprecated)
    goto skip;
  if (VIPS_IS_OPERATION_CLASS(class) &&
      (VIPS_OPERATION_CLASS(class)->flags & VIPS_OPERATION_DEPRECATED))
    goto skip;
  if (G_TYPE_IS_ABSTRACT(type))
    goto skip;
  if (G_TYPE_CHECK_CLASS_TYPE(class, VIPS_TYPE_FOREIGN))
    goto skip;

  type_list = (GTypeList *)user_data;
  type_list->types[type_list->count] = type;
  type_list->count = type_list->count + 1;

skip:
  g_type_class_unref(g_class);
  return (NULL);
}

ERL_NIF_TERM nif_vips_operation_list(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 0);

  GType type;
  GTypeList type_list;
  ERL_NIF_TERM list, name;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  type_list.types = g_new(GType, 1024);
  type_list.count = 0;

  vips_type_map_all(VIPS_TYPE_OPERATION, collect_operation_types, &type_list);

  list = enif_make_list(env, 0);

  for (guint i = 0; i < type_list.count; i++) {
    type = type_list.types[i];
    name = enif_make_string(env, vips_nickname_find(type), ERL_NIF_LATIN1);
    list = enif_make_list_cell(env, name, list);
  }

  g_free(type_list.types);

  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return list;
}

ERL_NIF_TERM nif_vips_enum_list(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 0);

  GType type;
  GType *types;
  gpointer g_class;
  GEnumClass *enum_class;
  ERL_NIF_TERM enum_values, tuple, enum_str, enum_int, enums, name;
  guint count = 0;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  types = g_type_children(G_TYPE_ENUM, &count);
  enums = enif_make_list(env, 0);

  for (guint i = 0; i < count; i++) {
    type = types[i];

    g_class = g_type_class_ref(type);
    enum_class = G_ENUM_CLASS(g_class);

    enum_values = enif_make_list(env, 0);

    for (guint j = 0; j < enum_class->n_values - 1; j++) {
      enum_str = make_atom(env, enum_class->values[j].value_name);
      enum_int = enif_make_int(env, enum_class->values[j].value);

      tuple = enif_make_tuple2(env, enum_str, enum_int);
      enum_values = enif_make_list_cell(env, tuple, enum_values);
    }

    name = enif_make_string(env, g_type_name(type), ERL_NIF_LATIN1);
    enums = enif_make_list_cell(env, enif_make_tuple2(env, name, enum_values),
                                enums);

    g_type_class_unref(g_class);
  }

  g_free(types);

  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return enums;
}

ERL_NIF_TERM nif_vips_flag_list(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 0);

  GType type;
  GType *types;
  gpointer g_class;
  GFlagsClass *flag_class;
  ERL_NIF_TERM flag_values, tuple, flag_str, flag_int, flags, name;
  guint count = 0;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  types = g_type_children(G_TYPE_FLAGS, &count);
  flags = enif_make_list(env, 0);

  for (guint i = 0; i < count; i++) {
    type = types[i];

    g_class = g_type_class_ref(type);
    flag_class = G_FLAGS_CLASS(g_class);

    flag_values = enif_make_list(env, 0);

    for (guint j = 0; j < flag_class->n_values - 1; j++) {
      flag_str = make_atom(env, flag_class->values[j].value_name);
      flag_int = enif_make_int(env, flag_class->values[j].value);

      tuple = enif_make_tuple2(env, flag_str, flag_int);
      flag_values = enif_make_list_cell(env, tuple, flag_values);
    }

    name = enif_make_string(env, g_type_name(type), ERL_NIF_LATIN1);
    flags = enif_make_list_cell(env, enif_make_tuple2(env, name, flag_values),
                                flags);

    g_type_class_unref(g_class);
  }

  g_free(types);

  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
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

ERL_NIF_TERM nif_vips_shutdown(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);
  vips_shutdown();
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_version(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);
  int major, minor, micro;

  major = vips_version(0);
  minor = vips_version(1);
  micro = vips_version(2);

  return enif_make_tuple3(env, enif_make_int(env, major),
                          enif_make_int(env, minor), enif_make_int(env, micro));
}

static void *load_operation(GType type, void *a) {
  const char **names;
  gpointer g_class;
  VipsObjectClass *class;
  VipsOperation *op;
  int *flags;
  bool *err;
  int n_args = 0;

  err = (bool *)a;

  g_class = g_type_class_ref(type);
  class = VIPS_OBJECT_CLASS(g_class);

  if (class->deprecated)
    goto unref_class_exit;
  if (VIPS_IS_OPERATION_CLASS(class) &&
      (VIPS_OPERATION_CLASS(class)->flags & VIPS_OPERATION_DEPRECATED))
    goto unref_class_exit;
  if (G_TYPE_IS_ABSTRACT(type))
    goto unref_class_exit;

  op = vips_operation_new(vips_nickname_find(type));

  if (op == NULL) {
    goto unref_class_exit;
  }

  if (get_vips_operation_args(op, &names, &flags, &n_args) != 0) {
    error("failed to get VipsObject arguments. error: %s", vips_error_buffer());
    vips_error_clear();
    *err = true;
  }

  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

unref_class_exit:
  g_type_class_unref(g_class);

  if (*err)
    return err;
  else
    return (NULL);
}

static int load_vips_types(ErlNifEnv *env) {
  bool error = false;
  vips_type_map_all(VIPS_TYPE_OPERATION, load_operation, &error);
  return error ? 1 : 0;
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
