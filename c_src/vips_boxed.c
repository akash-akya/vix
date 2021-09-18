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

  ASSERT_ARGC(argc, 1);

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
  ASSERT_ARGC(argc, 1);

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
  ASSERT_ARGC(argc, 1);

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

ERL_NIF_TERM nif_vips_blob(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GBoxedResource *boxed_r;
  VipsBlob *vips_blob;
  ERL_NIF_TERM ret;
  ErlNifBinary bin;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_inspect_binary(env, argv[0], &bin)) {
    error("failed to get binary from erl term");
    ret = enif_make_badarg(env);
    goto exit;
  }

  vips_blob = vips_blob_copy(bin.data, bin.size);

  boxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));
  boxed_r->boxed_type = VIPS_TYPE_BLOB;
  boxed_r->boxed_ptr = vips_blob;

  ret = enif_make_resource(env, boxed_r);
  enif_release_resource(boxed_r);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_vips_ref_string(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GBoxedResource *boxed_r;
  VipsRefString *vips_ref_string;
  ERL_NIF_TERM ret;
  ErlNifBinary bin;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_inspect_iolist_as_binary(env, argv[0], &bin)) {
    error("failed to get binary from erl term");
    ret = enif_make_badarg(env);
    goto exit;
  }

  // we ensure that data is appended with NULL while passing string from elixir
  vips_ref_string = vips_ref_string_new((const char *)bin.data);

  if (!vips_ref_string) {
    error("failed to create vips ref string");
    ret = enif_make_badarg(env);
    goto exit;
  }

  boxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));
  boxed_r->boxed_type = VIPS_TYPE_REF_STRING;
  boxed_r->boxed_ptr = vips_ref_string;

  ret = enif_make_resource(env, boxed_r);
  enif_release_resource(boxed_r);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_vips_int_array_to_erl_list(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsArrayInt *int_array;
  ERL_NIF_TERM list;
  ERL_NIF_TERM vips_array_term;
  GType type;
  int *arr;
  int n;
  ErlNifTime start;
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  vips_array_term = argv[0];

  if (!erl_term_boxed_type(env, vips_array_term, &type)) {
    SET_ERROR_RESULT(env, "failed to get type of boxed term", res);
    goto exit;
  }

  if (type != VIPS_TYPE_ARRAY_INT) {
    SET_ERROR_RESULT(env, "term is not a VIPS_TYPE_ARRAY_INT", res);
    goto exit;
  }

  if (!erl_term_to_g_boxed(env, vips_array_term, (gpointer *)&int_array)) {
    SET_ERROR_RESULT(env, "failed to get boxed term", res);
    goto exit;
  }

  arr = vips_array_int_get(int_array, &n);

  list = enif_make_list(env, 0);

  for (int i = n - 1; i >= 0; i--) {
    list = enif_make_list_cell(env, enif_make_int(env, arr[i]), list);
  }

  SET_VIX_RESULT(res, list);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  if (res.is_success)
    return make_ok(env, res.result);
  else
    return enif_make_tuple2(env, ATOM_ERROR, res.result);
}

ERL_NIF_TERM nif_vips_double_array_to_erl_list(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsArrayDouble *double_array;
  ERL_NIF_TERM list;
  ERL_NIF_TERM vips_array_term;
  GType type;
  double *arr;
  int n;
  ErlNifTime start;
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  vips_array_term = argv[0];

  if (!erl_term_boxed_type(env, vips_array_term, &type)) {
    SET_ERROR_RESULT(env, "failed to get type of boxed term", res);
    goto exit;
  }

  if (type != VIPS_TYPE_ARRAY_DOUBLE) {
    SET_ERROR_RESULT(env, "term is not a VIPS_TYPE_ARRAY_DOUBLE", res);
    goto exit;
  }

  if (!erl_term_to_g_boxed(env, vips_array_term, (gpointer *)&double_array)) {
    SET_ERROR_RESULT(env, "failed to get boxed term", res);
    goto exit;
  }

  arr = vips_array_double_get(double_array, &n);

  list = enif_make_list(env, 0);

  for (int i = n - 1; i >= 0; i--) {
    list = enif_make_list_cell(env, enif_make_double(env, arr[i]), list);
  }

  SET_VIX_RESULT(res, list);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  if (res.is_success)
    return make_ok(env, res.result);
  else
    return enif_make_tuple2(env, ATOM_ERROR, res.result);
}

ERL_NIF_TERM nif_vips_image_array_to_erl_list(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsArrayImage *image_array;
  ERL_NIF_TERM list;
  ERL_NIF_TERM vips_array_term;
  GType type;
  VipsImage **arr;
  VipsImage *image;
  int n;
  ErlNifTime start;
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  vips_array_term = argv[0];

  if (!erl_term_boxed_type(env, vips_array_term, &type)) {
    SET_ERROR_RESULT(env, "failed to get type of boxed term", res);
    goto exit;
  }

  if (type != VIPS_TYPE_ARRAY_IMAGE) {
    SET_ERROR_RESULT(env, "term is not a VIPS_TYPE_ARRAY_IMAGE", res);
    goto exit;
  }

  if (!erl_term_to_g_boxed(env, vips_array_term, (gpointer *)&image_array)) {
    SET_ERROR_RESULT(env, "failed to get boxed term", res);
    goto exit;
  }

  arr = vips_array_image_get(image_array, &n);

  list = enif_make_list(env, 0);

  for (int i = n - 1; i >= 0; i--) {
    image = arr[i];
    g_object_ref(image);
    list = enif_make_list_cell(env, g_object_to_erl_term(env, (GObject *)image),
                               list);
  }

  SET_VIX_RESULT(res, list);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  if (res.is_success)
    return make_ok(env, res.result);
  else
    return enif_make_tuple2(env, ATOM_ERROR, res.result);
}

ERL_NIF_TERM nif_vips_blob_to_erl_binary(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsBlob *blob;
  ERL_NIF_TERM vips_blob_term;
  ERL_NIF_TERM bin_term;
  GType type;
  size_t length;
  const void *blob_data;
  unsigned char *erl_bin_data;
  ErlNifTime start;
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  vips_blob_term = argv[0];

  if (!erl_term_boxed_type(env, vips_blob_term, &type)) {
    SET_ERROR_RESULT(env, "failed to get type of boxed term", res);
    goto exit;
  }

  if (type != VIPS_TYPE_BLOB) {
    SET_ERROR_RESULT(env, "term is not a VIPS_TYPE_BLOB", res);
    goto exit;
  }

  if (!erl_term_to_g_boxed(env, vips_blob_term, (gpointer *)&blob)) {
    SET_ERROR_RESULT(env, "failed to get boxed term", res);
    goto exit;
  }

  blob_data = vips_blob_get(blob, &length);
  erl_bin_data = enif_make_new_binary(env, length, &bin_term);
  memcpy(erl_bin_data, blob_data, length);

  SET_VIX_RESULT(res, bin_term);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  if (res.is_success)
    return make_ok(env, res.result);
  else
    return enif_make_tuple2(env, ATOM_ERROR, res.result);
}

ERL_NIF_TERM nif_vips_ref_string_to_erl_binary(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsRefString *vips_ref_string;
  ERL_NIF_TERM vips_ref_string_term;
  ERL_NIF_TERM bin_term;
  GType type;
  size_t length;
  const char *string;
  unsigned char *erl_bin_data;
  ErlNifTime start;
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  vips_ref_string_term = argv[0];

  if (!erl_term_boxed_type(env, vips_ref_string_term, &type)) {
    SET_ERROR_RESULT(env, "failed to get type of ref string term", res);
    goto exit;
  }

  if (type != VIPS_TYPE_REF_STRING) {
    SET_ERROR_RESULT(env, "term is not a VIPS_TYPE_REF_STRING", res);
    goto exit;
  }

  if (!erl_term_to_g_boxed(env, vips_ref_string_term,
                           (gpointer *)&vips_ref_string)) {
    SET_ERROR_RESULT(env, "failed to get boxed term", res);
    goto exit;
  }

  string = vips_ref_string_get(vips_ref_string, &length);
  erl_bin_data = enif_make_new_binary(env, length, &bin_term);
  memcpy(erl_bin_data, string, length);

  SET_VIX_RESULT(res, bin_term);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  if (res.is_success)
    return make_ok(env, res.result);
  else
    return enif_make_tuple2(env, ATOM_ERROR, res.result);
}
