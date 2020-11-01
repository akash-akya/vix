#include <glib-object.h>
#include <vips/vips.h>

#include "nif_g_object.h"
#include "nif_vips_image.h"
#include "vix_utils.h"

const int MAX_PATH_LEN = 1024;

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  char src[MAX_PATH_LEN + 1];
  VipsImage *image;

  if (enif_get_string(env, argv[0], src, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0)
    return raise_badarg(env, "Failed to get file name");

  image = vips_image_new_from_file(src, NULL);

  if (!image)
    return make_error(env, "Failed to read image");

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
}

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

  char dst[MAX_PATH_LEN + 1];
  VipsImage *image;

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image))
    return make_error(env, "Failed to get VipsImage");

  if (enif_get_string(env, argv[1], dst, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0)
    return make_error(env, "Failed to get destination path");

  if (vips_image_write_to_file(image, dst, NULL))
    return make_error(env, "Failed to write VipsImage");

  return ATOM_OK;
}

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);

  VipsImage *image = vips_image_new();

  if (!image)
    return make_error(env, "Failed create VipsImage");

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
}

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  char format[100];
  VipsImage *image;

  if (enif_get_string(env, argv[0], format, MAX_PATH_LEN, ERL_NIF_LATIN1) < 0)
    return raise_badarg(env, "Failed to get format");

  image = vips_image_new_temp_file(format);

  if (!image)
    return make_error(env, "Failed create VipsImage");

  return make_ok(env, g_object_to_erl_term(env, (GObject *)image));
}
