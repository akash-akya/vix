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

  if (enif_get_string(env, argv[0], src, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0)
    return raise_badarg(env, "Failed to get file name");

  image = vips_image_new_from_file(src, NULL);

  if (!image) {
    error("Failed to read image. error: %s", vips_error_buffer());
    vips_error_clear();
    return make_error(env, "Failed to read image");
  }

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
}

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

  char dst[VIPS_PATH_MAX];
  VipsImage *image;

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image))
    return make_error(env, "Failed to get VipsImage");

  if (enif_get_string(env, argv[1], dst, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0)
    return make_error(env, "Failed to get destination path");

  if (vips_image_write_to_file(image, dst, NULL)) {
    error("Failed to write VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    return make_error(env, "Failed to write VipsImage");
  }

  return ATOM_OK;
}

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);

  VipsImage *image = vips_image_new();

  if (!image) {
    error("Failed to create VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    return make_error(env, "Failed create VipsImage");
  }

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
}

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  char format[100];
  VipsImage *image;

  if (enif_get_string(env, argv[0], format, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0)
    return raise_badarg(env, "Failed to get format");

  image = vips_image_new_temp_file(format);

  if (!image) {
    error("Failed to create VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    return make_error(env, "Failed create VipsImage");
  }

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
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

  if (!enif_get_int(env, argv[0], &width)) {
    error("failed to get width");
    return enif_make_badarg(env);
  }

  if (!enif_get_int(env, argv[1], &height)) {
    error("failed to get height");
    return enif_make_badarg(env);
  }

  list = argv[2];

  if (!enif_get_list_length(env, list, &size)) {
    error("Failed to get list length");
    return enif_make_badarg(env);
  }

  if (!enif_get_double(env, argv[3], &scale)) {
    error("Failed to get scale");
    return enif_make_badarg(env);
  }

  if (!enif_get_double(env, argv[4], &offset)) {
    error("Failed to get offset");
    return enif_make_badarg(env);
  }

  array = g_new(double, size);

  for (guint i = 0; i < size; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      ret = make_error(env, "Failed to get list entry");
      goto exit;
    }

    if (!enif_get_double(env, head, &array[i])) {
      ret = make_error(env, "Failed to get double");
      goto exit;
    }
  }

  image = vips_image_new_matrix_from_array(width, height, array, size);

  if (!image) {
    error("Failed to read image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create matrix from array");
    goto exit;
  }

  vips_image_set_double(image, "scale", scale);

  vips_image_set_double(image, "offset", offset);

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  g_free(array);
  return ret;
}
