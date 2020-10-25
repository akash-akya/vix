#include <glib-object.h>
#include <stdio.h>
#include <vips/vips.h>

#include "eips_common.h"
#include "nif_g_object.h"
#include "nif_g_type.h"

static ERL_NIF_TERM ATOM_TRUE;
static ERL_NIF_TERM ATOM_FALSE;
static ERL_NIF_TERM ATOM_OK;
static ERL_NIF_TERM ATOM_ERROR;

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

/******* VipsObject Resource *******/
typedef struct VipsObjectResource {
  VipsObject *vips_object;
} VipsObjectResource;

static void vo_dtor(ErlNifEnv *env, void *obj) {
  VipsObjectResource *vips_object_resource = (VipsObjectResource *)obj;

  /* TODO: create separate resource for VipsOperation */
  vips_object_unref_outputs(VIPS_OBJECT(vips_object_resource->vips_object));
  g_object_unref(vips_object_resource->vips_object);

  debug("VipsObjectResource vo_dtor called");
}

static void vo_stop(ErlNifEnv *env, void *obj, int fd, int is_direct_call) {
  debug("VipsObjectResource vo_stop called %d", fd);
}

static void vo_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                    ErlNifMonitor *monitor) {
  debug("VipsObjectResource vo_down called");
}

static ErlNifResourceTypeInit vo_rt_init = {vo_dtor, vo_stop, vo_down};

/******* GParamSpec Resource *******/
static void g_param_spec_dtor(ErlNifEnv *env, void *obj) {
  debug("GParamSpec g_param_spec_dtor called");
}

static void g_param_spec_stop(ErlNifEnv *env, void *obj, int fd,
                              int is_direct_call) {
  debug("GParamSpec g_param_spec_stop called %d", fd);
}

static void g_param_spec_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                              ErlNifMonitor *monitor) {
  debug("GParamSpec g_param_spec_down called");
}

static ErlNifResourceTypeInit g_param_spec_rt_init = {
    g_param_spec_dtor, g_param_spec_stop, g_param_spec_down};

/******* VipsImage Resource *******/
static void nif_vips_image_dtor(ErlNifEnv *env, void *obj) {
  g_object_unref(obj);
  debug("VipsImage nif_vips_image_dtor called");
}

static void nif_vips_image_stop(ErlNifEnv *env, void *obj, int fd,
                                int is_direct_call) {
  debug("VipsImage nif_vips_image_stop called %d", fd);
}

static void nif_vips_image_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                                ErlNifMonitor *monitor) {
  debug("VipsImage nif_vips_image_down called");
}

static ErlNifResourceTypeInit nif_vips_image_rt_init = {
    nif_vips_image_dtor, nif_vips_image_stop, nif_vips_image_down};

/***** Private *****/
typedef struct EipsPriv {
  ErlNifResourceType *vo_rt;
  ErlNifResourceType *g_param_spec_rt;
  ErlNifResourceType *g_type_rt;
  ErlNifResourceType *g_object_rt;
  ErlNifResourceType *nif_vips_image_rt;
} EipsPriv;

static ERL_NIF_TERM invert(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  if (argc != 2) {
    return enif_make_badarg(env);
  }

  char src[MAX_PATH_LEN + 1];
  char dst[MAX_PATH_LEN + 1];

  if (enif_get_string(env, argv[0], src, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0)
    return enif_make_badarg(env);

  if (enif_get_string(env, argv[1], dst, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0)
    return enif_make_badarg(env);

  VipsImage *in;
  VipsImage *out;
  VipsOperation *op;
  VipsOperation *new_op;
  GValue gvalue = {0};

  if (!(in = vips_image_new_from_file(src, NULL)))
    vips_error_exit(NULL);

  /* Create a new operator from a nickname. NULL for unknown operator.
   */
  op = vips_operation_new("invert");

  /* Init a gvalue as an image, set it to in, use the gvalue to set the
   * operator property.
   */
  g_value_init(&gvalue, VIPS_TYPE_IMAGE);
  g_value_set_object(&gvalue, in);
  g_object_set_property(G_OBJECT(op), "in", &gvalue);
  g_value_unset(&gvalue);

  /* We no longer need in: op will hold a ref to it as long as it needs
   * it.
   */
  g_object_unref(in);

  /* Call the operation. This will look up the operation+args in the vips
   * operation cache and either return a previous operation, or build
   * this one. In either case, we have a new ref we must release.
   */
  if (!(new_op = vips_cache_operation_build(op))) {
    g_object_unref(op);
    vips_error_exit(NULL);
  }
  g_object_unref(op);
  op = new_op;

  /* Now get the result from op. g_value_get_object() does not ref the
   * object, so we need to make a ref for out to hold.
   */
  g_value_init(&gvalue, VIPS_TYPE_IMAGE);
  g_object_get_property(G_OBJECT(op), "out", &gvalue);
  out = VIPS_IMAGE(g_value_get_object(&gvalue));
  g_object_ref(out);
  g_value_unset(&gvalue);

  /* All done: we can unref op. The output objects from op actually hold
   * refs back to it, so before we can unref op, we must unref them.
   */
  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

  if (vips_image_write_to_file(out, dst, NULL))
    vips_error_exit(NULL);

  g_object_unref(out);

  return make_ok(env, ATOM_TRUE);
}

/***** VipsObject Access *****/
static ERL_NIF_TERM vips_object_to_erl_term(ErlNifEnv *env,
                                            VipsObject *vips_object) {
  EipsPriv *data = enif_priv_data(env);
  VipsObjectResource *vips_object_r;

  vips_object_r = enif_alloc_resource(data->vo_rt, sizeof(VipsObjectResource));
  vips_object_r->vips_object = (VipsObject *)g_object_ref(vips_object);

  ERL_NIF_TERM term = enif_make_resource(env, vips_object_r);
  enif_release_resource(vips_object_r);

  return term;
}

static ERL_NIF_TERM vips_image_to_erl_term(ErlNifEnv *env,
                                           VipsImage *vips_image) {
  EipsPriv *data = enif_priv_data(env);
  VipsObjectResource *vips_object_r;

  vips_object_r = enif_alloc_resource(data->vo_rt, sizeof(VipsObjectResource));
  vips_object_r->vips_object = (VipsObject *)g_object_ref(vips_image);

  ERL_NIF_TERM term = enif_make_resource(env, vips_object_r);
  enif_release_resource(vips_object_r);

  return term;
}

static bool erl_term_to_vips_object(ErlNifEnv *env, ERL_NIF_TERM term,
                                    VipsObject **vips_object) {
  VipsObjectResource *vips_object_r = NULL;
  struct EipsPriv *data = enif_priv_data(env);

  if (enif_get_resource(env, term, data->vo_rt, (void **)&vips_object_r)) {
    (*vips_object) = vips_object_r->vips_object;
    return true;
  } else {
    return false;
  }
}

/*************** VipsObject ***************/

static void print_g_type_name(GParamSpec *pspec) {
  debug("GParamSpec name: %s", g_type_name(pspec->value_type));
}

static ERL_NIF_TERM nif_operation_set_property(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]) {
  if (argc != 4) {
    error("number of arguments must be 4");
    return enif_make_badarg(env);
  }

  VipsOperation *op;
  if (!erl_term_to_vips_object(env, argv[0], (VipsObject **)&op)) {
    error("Failed to get VipsObject");
    return enif_make_badarg(env);
  }

  char name[1024];
  if (enif_get_string(env, argv[1], name, 2014, ERL_NIF_LATIN1) < 0) {
    error("failed to get param name");
    return enif_make_badarg(env);
  }

  GType g_type;
  if (!erl_term_to_g_type(env, argv[2], &g_type)) {
    error("failed to get GType argument");
    return enif_make_badarg(env);
  }

  GObject *g_object;
  if (!erl_term_to_g_object(env, argv[3], &g_object)) {
    error("failed to get GObject argument");
    return enif_make_badarg(env);
  }

  GValue gvalue = {0};

  g_value_init(&gvalue, g_type);
  g_value_set_object(&gvalue, g_object);
  g_object_set_property(G_OBJECT(op), name, &gvalue);
  g_value_unset(&gvalue);

  return ATOM_OK;
}

typedef struct EipsResult {
  bool success;
  ERL_NIF_TERM term; // error in case of success == false
} EipsResult;

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
  char g_type_nickname[1024];
  GType g_type;
  GObject *g_object;

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

    if (count != 3) {
      error("Tuple length must be 3");
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
        1) {
      error("failed to get GType nickname argument");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    g_type = vips_type_find("VipsObject", g_type_nickname);

    if (!erl_term_to_g_object(env, tup[2], &g_object)) {
      error("failed to get GObject argument");
      result.success = false;
      result.term = enif_make_badarg(env);
      return result;
    }

    g_value_init(&gvalue, g_type);
    g_value_set_object(&gvalue, g_object);
    g_object_set_property(G_OBJECT(op), name, &gvalue);
    g_value_unset(&gvalue);
  }

  result.success = true;
  return result;
}

static ERL_NIF_TERM nif_operation_call_with_args(ErlNifEnv *env, int argc,
                                                 const ERL_NIF_TERM argv[]) {
  if (argc != 3) {
    error("number of arguments must be 3");
    return enif_make_badarg(env);
  }

  char op_name[200] = {'\0'};
  if (enif_get_string(env, argv[0], op_name, 200, ERL_NIF_LATIN1) < 1) {
    error("operation name must be a valid string");
    return enif_make_badarg(env);
  }
  VipsOperation *op = vips_operation_new(op_name);

  debug("created operation");

  EipsResult result = set_operation_properties(env, op, argv[1]);
  if (!result.success) {
    return result.term;
  }

  debug("set operation properties");

  VipsOperation *new_op;
  if (!(new_op = vips_cache_operation_build(op))) {
    g_object_unref(op);
    error("Failed to call vips operation: %s", vips_error_buffer());
    return enif_raise_exception(
        env,
        enif_make_string(env, "Failed to call VipsOperation", ERL_NIF_LATIN1));
  }

  debug("run operation");

  g_object_unref(op);
  op = new_op;

  result = get_operation_properties(env, op, argv[2]);
  if (!result.success) {
    error("NIF Vips Operation get operation properties failed");
  }

  debug("got operation properties");

  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

  return result.term;
}

static ERL_NIF_TERM nif_operation_call(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  VipsObjectResource *vips_object_r = NULL;
  VipsOperation *op, *new_op;

  struct EipsPriv *data = enif_priv_data(env);
  if (!enif_get_resource(env, argv[0], data->vo_rt, (void **)&vips_object_r)) {
    error("Failed to get VipsObject");
    return enif_make_badarg(env);
  }

  op = (VipsOperation *)vips_object_r->vips_object;

  if (!(new_op = vips_cache_operation_build(op))) {
    g_object_unref(op);
    error("Failed to call vips operation");
    return enif_raise_exception(
        env,
        enif_make_string(env, "Failed to call VipsOperation", ERL_NIF_LATIN1));
  }

  /* we release old op and replace it with new op */
  g_object_unref(op);
  vips_object_r->vips_object = (VipsObject *)new_op;

  return ATOM_OK;
}

static ERL_NIF_TERM nif_operation_get_property(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]) {
  if (argc != 3) {
    error("number of arguments must be 3");
    return enif_make_badarg(env);
  }

  VipsOperation *op;
  if (!erl_term_to_vips_object(env, argv[0], (VipsObject **)&op)) {
    error("Failed to get VipsObject");
    return enif_make_badarg(env);
  }

  char name[1024];
  if (enif_get_string(env, argv[1], name, 2014, ERL_NIF_LATIN1) < 0) {
    error("failed to get param name");
    return enif_make_badarg(env);
  }

  GType g_type;
  if (!erl_term_to_g_type(env, argv[2], &g_type)) {
    error("failed to get GType argument");
    return enif_make_badarg(env);
  }

  GValue gvalue = {0};

  g_value_init(&gvalue, g_type);
  g_object_get_property(G_OBJECT(op), name, &gvalue);

  GObject *g_object = g_value_get_object(&gvalue);
  g_object_ref(g_object);
  g_value_unset(&gvalue);

  /* All done: we can unref op. The output objects from op actually hold
   * refs back to it, so before we can unref op, we must unref them.
   */
  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);

  return ATOM_OK;
}

static ERL_NIF_TERM nif_vips_object_to_g_object(ErlNifEnv *env, int argc,
                                                const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  VipsObject *vips_object;
  if (!erl_term_to_vips_object(env, argv[0], &vips_object)) {
    error("Failed to get VipsObject");
    return enif_make_badarg(env);
  }

  return make_ok(env, g_object_to_erl_term(env, G_OBJECT(vips_object)));
}

static ERL_NIF_TERM nif_g_object_to_vips_object(ErlNifEnv *env, int argc,
                                                const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GObject *g_object;
  if (!erl_term_to_g_object(env, argv[0], &g_object)) {
    error("Failed to get GObject");
    return enif_make_badarg(env);
  }

  return vips_object_to_erl_term(env, VIPS_OBJECT(g_object));
}

static ERL_NIF_TERM nif_g_object_to_vips_image(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GObject *g_object;
  if (!erl_term_to_g_object(env, argv[0], &g_object)) {
    error("Failed to get GObject");
    return enif_make_badarg(env);
  }

  return vips_image_to_erl_term(env, VIPS_IMAGE(g_object));
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

  if (!erl_term_to_vips_object(env, argv[0], (VipsObject **)&image)) {
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

  ERL_NIF_TERM gparamspec_name = enif_make_string(
      env, g_type_name(class->parent.pspec->value_type), ERL_NIF_LATIN1);

  ERL_NIF_TERM g_type =
      g_type_to_erl_term(env, class->parent.pspec->value_type);

  debug("class name: %s -> %s", g_type_name(class->parent.pspec->value_type),
        class->object_class->description);
  /* debug("GType: %d", class->parent.pspec->value_type); */
  /* print_g_type_name(class->parent.pspec); */
  /* vips_object_print_summary_class(class->object_class); */

  ERL_NIF_TERM priority = enif_make_int(env, class->priority);
  ERL_NIF_TERM offset = enif_make_uint(env, class->offset);

  return enif_make_tuple4(env, gparamspec_name, g_type, priority, offset);
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

  if (!erl_term_to_vips_object(env, argv[0], (VipsObject **)&op)) {
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
  return make_ok(env, vips_object_to_erl_term(env, (VipsObject *)op));
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

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info) {
  struct EipsPriv *data = enif_alloc(sizeof(struct EipsPriv));

  if (!data)
    return 1;

  ATOM_TRUE = enif_make_atom(env, "true");
  ATOM_FALSE = enif_make_atom(env, "false");
  ATOM_OK = enif_make_atom(env, "ok");
  ATOM_ERROR = enif_make_atom(env, "error");

  data->vo_rt =
      enif_open_resource_type_x(env, "eips_resource", &vo_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  data->g_param_spec_rt =
      enif_open_resource_type_x(env, "eips_resource", &g_param_spec_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  data->nif_vips_image_rt =
      enif_open_resource_type_x(env, "eips_resource", &nif_vips_image_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  nif_g_type_init(env);
  nif_g_object_init(env);

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

  *priv = (void *)data;

  if (VIPS_INIT(""))
    return 1;

  return 0;
}

static void on_unload(ErlNifEnv *env, void *priv) { debug("eips unload"); }

static ErlNifFunc nif_funcs[] = {
    {"nif_image_new_from_file", 1, nif_image_new_from_file, USE_DIRTY_IO},
    {"nif_vips_object_to_g_object", 1, nif_vips_object_to_g_object,
     USE_DIRTY_IO},
    {"nif_g_object_to_vips_object", 1, nif_g_object_to_vips_object,
     USE_DIRTY_IO},
    {"nif_g_object_to_vips_image", 1, nif_g_object_to_vips_image, USE_DIRTY_IO},
    {"nif_create_op", 1, nif_create_op, USE_DIRTY_IO},
    {"nif_get_op_arguments", 1, nif_get_op_arguments, USE_DIRTY_IO},
    {"nif_operation_set_property", 4, nif_operation_set_property, USE_DIRTY_IO},
    {"nif_operation_call", 1, nif_operation_call, USE_DIRTY_IO},
    {"nif_operation_call_with_args", 3, nif_operation_call_with_args,
     USE_DIRTY_IO},
    {"nif_operation_get_property", 3, nif_operation_get_property, USE_DIRTY_IO},
    {"nif_image_write_to_file", 2, nif_image_write_to_file, USE_DIRTY_IO},
    {"nif_vips_type_find", 1, nif_vips_type_find, USE_DIRTY_IO},
    {"invert", 2, invert, USE_DIRTY_IO},
    /*  GObject */
    {"nif_g_object_type", 1, nif_g_object_type, USE_DIRTY_IO},
    {"nif_g_object_type_name", 1, nif_g_object_type_name, USE_DIRTY_IO},
    /*  GType */
    {"nif_g_type_name", 1, nif_g_type_name, USE_DIRTY_IO}};

ERL_NIF_INIT(Elixir.Eips.Nif, nif_funcs, &on_load, NULL, NULL, &on_unload)
