#include <glib-object.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "utils.h"
#include "vips_image.h"

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  char src[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (enif_get_string(env, argv[0], src, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0) {
    ret = raise_badarg(env, "Failed to get file name");
    goto exit;
  }

  image = vips_image_new_from_file(src, NULL);

  if (!image) {
    error("Failed to read image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to read image");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

  char dst[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (enif_get_string(env, argv[1], dst, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0) {
    ret = make_error(env, "Failed to get destination path");
    goto exit;
  }

  if (vips_image_write_to_file(image, dst, NULL)) {
    error("Failed to write VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write VipsImage");
    goto exit;
  }

  ret = ATOM_OK;

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);

  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  image = vips_image_new();

  if (!image) {
    error("Failed to create VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create VipsImage");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  char format[100];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (enif_get_string(env, argv[0], format, VIPS_PATH_MAX, ERL_NIF_LATIN1) <
      0) {
    ret = raise_badarg(env, "Failed to get format");
    goto exit;
  }

  image = vips_image_new_temp_file(format);

  if (!image) {
    error("Failed to create VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create VipsImage");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_matrix_from_array(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 5);

  VipsImage *image;
  int width, height;
  double scale, offset;
  double *array;
  ERL_NIF_TERM list, head, ret;
  guint size;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_int(env, argv[0], &width)) {
    error("failed to get width");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_int(env, argv[1], &height)) {
    error("failed to get height");
    ret = enif_make_badarg(env);
    goto exit;
  }

  list = argv[2];

  if (!enif_get_list_length(env, list, &size)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_double(env, argv[3], &scale)) {
    error("Failed to get scale");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_double(env, argv[4], &offset)) {
    error("Failed to get offset");
    ret = enif_make_badarg(env);
    goto exit;
  }

  array = g_new(double, size);

  for (guint i = 0; i < size; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      ret = make_error(env, "Failed to get list entry");
      goto free_and_exit;
    }

    if (!enif_get_double(env, head, &array[i])) {
      ret = make_error(env, "Failed to get double");
      goto free_and_exit;
    }
  }

  image = vips_image_new_matrix_from_array(width, height, array, size);

  if (!image) {
    error("Failed to read image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create matrix from array");
    goto free_and_exit;
  }

  vips_image_set_double(image, "scale", scale);

  vips_image_set_double(image, "offset", offset);

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

free_and_exit:
  g_free(array);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_write_to_file_thread(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

  char dst[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (enif_get_string(env, argv[1], dst, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0) {
    ret = make_error(env, "Failed to get destination path");
    goto exit;
  }

  if (vips_image_write_to_file(image, dst, NULL)) {
    error("Failed to write VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write VipsImage");
    goto exit;
  }

  ret = ATOM_OK;

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}
