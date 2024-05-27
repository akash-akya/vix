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
    SET_RESULT_FROM_VIPS_ERROR(env, "failed to get output fields", res);
    return res;
  }

  list = enif_make_list(env, 0);

  for (int i = 0; i < n_args; i++) {
    if (flags[i] & VIPS_ARGUMENT_OUTPUT) {
      if (vips_object_get_argument(VIPS_OBJECT(op), names[i], &pspec,
                                   &arg_class, &arg_instance)) {
        error("failed to get argument: %s", names[i]);
        SET_RESULT_FROM_VIPS_ERROR(env, names[i], res);
        // early exit is fine, for already reffed output GObjects
        // since `g_object_dtor` takes care of unreffing
        return res;
      }

      res = get_erl_term_from_g_object_property(env, G_OBJECT(op), names[i],
                                                pspec);

      if (!res.is_success)
        return res;

      name = make_binary(env, names[i]);
      entry = enif_make_tuple2(env, name, res.result);
      list = enif_make_list_cell(env, entry, list);
    }
  }

  SET_VIX_RESULT(res, list);
  return res;
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
    SET_ERROR_RESULT(env, "failed to get param list length", res);
    return res;
  }

  for (guint i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      SET_ERROR_RESULT(env, "failed to get param list entry", res);
      return res;
    }

    if (!enif_get_tuple(env, head, &count, &tup)) {
      SET_ERROR_RESULT(env, "failed to get param tuple", res);
      return res;
    }

    if (count != 2) {
      SET_ERROR_RESULT(env, "tuple length must be 2", res);
      return res;
    }

    if (!get_binary(env, tup[0], name, 1024)) {
      SET_ERROR_RESULT(env, "failed to get param name", res);
      return res;
    }
    if (vips_object_get_argument(VIPS_OBJECT(op), name, &pspec, &arg_class,
                                 &arg_instance)) {
      SET_ERROR_RESULT(env, "failed to get vips argument", res);
      return res;
    }

    res = set_g_value_from_erl_term(env, pspec, tup[1], &gvalue);
    if (!res.is_success)
      return res;

    g_object_set_property(G_OBJECT(op), name, &gvalue);
    g_value_unset(&gvalue);
  }

  SET_VIX_RESULT(res, list);
  return res;
}

ERL_NIF_TERM nif_vips_operation_call(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  VixResult res;
  VipsOperation *op = NULL;
  VipsOperation *new_op;
  ErlNifTime start;
  char op_name[200] = {0};

  start = enif_monotonic_time(ERL_NIF_USEC);

  ASSERT_ARGC(argc, 2);

  if (!get_binary(env, argv[0], op_name, 200)) {
    SET_ERROR_RESULT(env, "operation name must be a valid string", res);
    goto exit;
  }

  op = vips_operation_new(op_name);

  res = set_operation_properties(env, op, argv[1]);
  if (!res.is_success)
    goto free_and_exit;

  if (!(new_op = vips_cache_operation_build(op))) {
    SET_RESULT_FROM_VIPS_ERROR(env, "operation build", res);
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

  ASSERT_ARGC(argc, 1);

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

  if (!get_binary(env, argv[0], op_name, 200)) {
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

  description = make_binary(env, vips_object_get_description(VIPS_OBJECT(op)));

  list = enif_make_list(env, 0);

  for (int i = 0; i < n_args; i++) {
    name = make_binary(env, names[i]);
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

  type_list = (GTypeList *)user_data;
  type_list->types[type_list->count] = type;
  type_list->count = type_list->count + 1;

skip:
  g_type_class_unref(g_class);
  return (NULL);
}

ERL_NIF_TERM nif_vips_operation_list(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {

  ASSERT_ARGC(argc, 0);

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
    name = make_binary(env, vips_nickname_find(type));
    list = enif_make_list_cell(env, name, list);
  }

  g_free(type_list.types);

  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return list;
}

ERL_NIF_TERM nif_vips_enum_list(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {

  ASSERT_ARGC(argc, 0);

  GType type;
  GType *types;
  gpointer g_class;
  GEnumClass *enum_class;
  ERL_NIF_TERM enum_values, tuple, enum_atom, enum_int, enums, name;
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
      enum_atom = make_atom(env, enum_class->values[j].value_name);
      enum_int = enif_make_int(env, enum_class->values[j].value);

      tuple = enif_make_tuple2(env, enum_atom, enum_int);
      enum_values = enif_make_list_cell(env, tuple, enum_values);
    }

    name = make_binary(env, g_type_name(type));
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

  ASSERT_ARGC(argc, 0);

  GType type;
  GType *types;
  gpointer g_class;
  GFlagsClass *flag_class;
  ERL_NIF_TERM flag_values, tuple, flag_atom, flag_int, flags, name;
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
      flag_atom = make_atom(env, flag_class->values[j].value_name);
      flag_int = enif_make_int(env, flag_class->values[j].value);

      tuple = enif_make_tuple2(env, flag_atom, flag_int);
      flag_values = enif_make_list_cell(env, tuple, flag_values);
    }

    name = make_binary(env, g_type_name(type));
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
  ASSERT_ARGC(argc, 1);

  int max_op;

  if (!enif_get_int(env, argv[0], &max_op)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_cache_set_max(max_op);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_cache_get_max(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  return enif_make_int(env, vips_cache_get_max());
}

ERL_NIF_TERM nif_vips_concurrency_set(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  int concurrency;

  if (!enif_get_int(env, argv[0], &concurrency)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_concurrency_set(concurrency);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_concurrency_get(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  return enif_make_int(env, vips_concurrency_get());
}

ERL_NIF_TERM nif_vips_cache_set_max_files(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  int max_files;

  if (!enif_get_int(env, argv[0], &max_files)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_cache_set_max_files(max_files);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_cache_get_max_files(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  return enif_make_int(env, vips_cache_get_max_files());
}

ERL_NIF_TERM nif_vips_cache_set_max_mem(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifUInt64 max_mem;

  if (!enif_get_uint64(env, argv[0], &max_mem)) {
    return raise_badarg(env, "Failed to integer value");
  }

  vips_cache_set_max_mem(max_mem);
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_cache_get_max_mem(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  return enif_make_uint64(env, vips_cache_get_max_mem());
}

ERL_NIF_TERM nif_vips_leak_set(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifUInt64 value = 0;

  if (!enif_get_uint64(env, argv[0], &value)) {
    return raise_badarg(env, "Failed to integer value");
  }

  if (value != 0) {
    vips_leak_set(TRUE);
  } else {
    vips_leak_set(FALSE);
  }

  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_tracked_get_mem(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  return enif_make_uint64(env, vips_tracked_get_mem());
}

ERL_NIF_TERM nif_vips_tracked_get_mem_highwater(ErlNifEnv *env, int argc,
                                                const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  return enif_make_uint64(env, vips_tracked_get_mem_highwater());
}

ERL_NIF_TERM nif_vips_shutdown(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  vips_shutdown();
  return ATOM_OK;
}

ERL_NIF_TERM nif_vips_version(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);
  int major, minor, micro;

  major = vips_version(0);
  minor = vips_version(1);
  micro = vips_version(2);

  return enif_make_tuple3(env, enif_make_int(env, major),
                          enif_make_int(env, minor), enif_make_int(env, micro));
}

ERL_NIF_TERM nif_vips_nickname_find(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);
  char gtype_name[MAX_G_TYPE_NAME_LENGTH];
  const char *nickname;
  GType type;
  ERL_NIF_TERM ret;

  if (!get_binary(env, argv[0], gtype_name, MAX_G_TYPE_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get GType name");
    goto exit;
  }

  type = g_type_from_name(gtype_name);

  if (type == 0) {
    ret = make_error(env, "GType for the given name not found");
    goto exit;
  }

  nickname = vips_nickname_find(type);

  if (!nickname) {
    ret = make_error(env, "Vips nickname not found for given type");
    goto exit;
  }

  ret = make_ok(env, make_binary(env, nickname));

exit:
  return ret;
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
