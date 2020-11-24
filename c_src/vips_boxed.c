#include "vips_boxed.h"
#include "g_object/g_boxed.h"
#include "g_object/g_object.h"
#include "utils.h"
#include <stdbool.h>
#include <vips/vips.h>

static VipsArrayInt *erl_list_to_vips_int_array(ErlNifEnv *env,
                                                ERL_NIF_TERM list,
                                                unsigned int length,
                                                int *array) {
  ERL_NIF_TERM head, tail;
  int value;

  tail = list;

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, tail, &head, &tail)) {
      error("Failed to get list entry");
      return NULL;
    }

    if (!enif_get_int(env, head, &value)) {
      error("Failed to get int");
      return NULL;
    }

    array[i] = value;
  }

  return vips_array_int_new(array, length);
}

static VipsArrayDouble *erl_list_to_vips_double_array(ErlNifEnv *env,
                                                      ERL_NIF_TERM list,
                                                      unsigned int length,
                                                      double *array) {
  ERL_NIF_TERM head, tail;
  double value;

  tail = list;

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, tail, &head, &tail)) {
      error("Failed to get list entry");
      return NULL;
    }

    if (!enif_get_double(env, head, &value)) {
      error("Failed to get double");
      return NULL;
    }

    array[i] = value;
  }

  return vips_array_double_new(array, length);
}

static VipsArrayImage *erl_list_to_vips_image_array(ErlNifEnv *env,
                                                    ERL_NIF_TERM list,
                                                    unsigned int length,
                                                    VipsImage **array) {
  ERL_NIF_TERM head, tail;
  VipsImage *img;

  tail = list;

  for (unsigned int i = 0; i < length; i++) {
    if (!enif_get_list_cell(env, tail, &head, &tail)) {
      error("Failed to get list entry");
      return NULL;
    }

    if (!erl_term_to_g_object(env, head, (GObject **)&img)) {
      error("failed to get VipsImage");
      return NULL;
    }

    array[i] = img;
  }

  return vips_array_image_new(array, length);
}

ERL_NIF_TERM nif_int_array(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 1);

  GBoxedResource *boxed_r;
  unsigned int len;
  int *array;
  VipsArrayInt *vips_array;
  ERL_NIF_TERM ret;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_list_length(env, argv[0], &len)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  array = g_new(int, len);

  boxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));
  vips_array = erl_list_to_vips_int_array(env, argv[0], len, array);

  boxed_r->boxed_type = VIPS_TYPE_ARRAY_INT;
  boxed_r->boxed_ptr = vips_array;

  ret = enif_make_resource(env, boxed_r);
  enif_release_resource(boxed_r);

  g_free(array);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_double_array(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  GBoxedResource *boxed_r;
  unsigned int len;
  double *array;
  VipsArrayDouble *vips_array;
  ERL_NIF_TERM ret;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_list_length(env, argv[0], &len)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  array = g_new(double, len);

  boxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));
  vips_array = erl_list_to_vips_double_array(env, argv[0], len, array);

  boxed_r->boxed_type = VIPS_TYPE_ARRAY_DOUBLE;
  boxed_r->boxed_ptr = vips_array;

  ret = enif_make_resource(env, boxed_r);
  enif_release_resource(boxed_r);

  g_free(array);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_array(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  GBoxedResource *boxed_r;
  unsigned int len;
  VipsImage **array;
  VipsArrayImage *vips_array;
  ERL_NIF_TERM ret;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_list_length(env, argv[0], &len)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  array = g_new(VipsImage *, len);

  boxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));
  vips_array = erl_list_to_vips_image_array(env, argv[0], len, array);

  boxed_r->boxed_type = VIPS_TYPE_ARRAY_IMAGE;
  boxed_r->boxed_ptr = vips_array;

  ret = enif_make_resource(env, boxed_r);
  enif_release_resource(boxed_r);

  g_free(array);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}
