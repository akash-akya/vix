#include <glib-object.h>
#include <vips/vips.h>

#include "nif_vips_image.h"
#include "nif_g_object.h"
#include "vix_utils.h"

const int MAX_PATH_LEN = 1024;

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
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

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
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
