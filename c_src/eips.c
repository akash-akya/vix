#include <glib-object.h>
#include <stdio.h>
#include <vips/vips.h>

#include "eips_common.h"
#include "nif_g_boxed.h"
#include "nif_g_object.h"
#include "nif_g_param_spec.h"
#include "nif_g_type.h"
#include "nif_g_value.h"
#include "nif_vips_boxed.h"
#include "nif_vips_operation.h"

ERL_NIF_TERM ATOM_OK;

static const int MAX_PATH_LEN = 1024;

static inline ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
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

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info) {
  ATOM_OK = enif_make_atom(env, "ok");

  nif_g_type_init(env);
  nif_g_object_init(env);
  nif_g_param_spec_init(env);
  nif_g_boxed_init(env);
  nif_vips_operation_init(env);

  if (VIPS_INIT(""))
    return 1;

  return 0;
}

static void on_unload(ErlNifEnv *env, void *priv) {
  vips_shutdown();
  debug("eips unload");
}

static ErlNifFunc nif_funcs[] = {
    {"nif_image_new_from_file", 1, nif_image_new_from_file, USE_DIRTY_IO},
    {"nif_image_write_to_file", 2, nif_image_write_to_file, USE_DIRTY_IO},
    /*  VipsOperation */
    {"nif_vips_operation_call", 2, nif_vips_operation_call, USE_DIRTY_IO},
    {"nif_vips_operation_get_arguments", 1, nif_vips_operation_get_arguments,
     USE_DIRTY_IO},
    {"nif_vips_operation_list", 0, nif_vips_operation_list, USE_DIRTY_IO},
    /*  GObject */
    {"nif_g_object_type", 1, nif_g_object_type, USE_DIRTY_IO},
    {"nif_g_object_type_name", 1, nif_g_object_type_name, USE_DIRTY_IO},
    /*  GType */
    {"nif_g_type_name", 1, nif_g_type_name, USE_DIRTY_IO},
    {"nif_g_type_from_name", 1, nif_g_type_from_name, USE_DIRTY_IO},
    /*  GParamSpec */
    {"nif_g_param_spec_type", 1, nif_g_param_spec_type, USE_DIRTY_IO},
    {"nif_g_param_spec_get_name", 1, nif_g_param_spec_get_name, USE_DIRTY_IO},
    {"nif_g_param_spec_value_type", 1, nif_g_param_spec_value_type,
     USE_DIRTY_IO},
    {"nif_g_param_spec_type_name", 1, nif_g_param_spec_type_name, USE_DIRTY_IO},
    {"nif_g_param_spec_value_type_name", 1, nif_g_param_spec_value_type_name,
     USE_DIRTY_IO},
    /*  VipsBoxed */
    {"nif_int_array", 1, nif_int_array, USE_DIRTY_IO},
    {"nif_double_array", 1, nif_double_array, USE_DIRTY_IO}};

ERL_NIF_INIT(Elixir.Eips.Nif, nif_funcs, &on_load, NULL, NULL, &on_unload)
