#include <glib-object.h>
#include <stdio.h>
#include <vips/vips.h>

#include "vix_utils.h"

#include "nif_g_boxed.h"
#include "nif_g_object.h"
#include "nif_g_param_spec.h"
#include "nif_vips_boxed.h"
#include "nif_vips_image.h"
#include "nif_vips_operation.h"

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info) {
  ERL_NIF_TERM res;

  res = vix_utils_init(env);
  if (enif_is_exception(env, res))
    return res;

  res = nif_g_object_init(env);
  if (enif_is_exception(env, res))
    return res;

  res = nif_g_param_spec_init(env);
  if (enif_is_exception(env, res))
    return res;

  res = nif_g_boxed_init(env);
  if (enif_is_exception(env, res))
    return res;

  res = nif_vips_operation_init(env);
  if (enif_is_exception(env, res))
    return res;

  if (VIPS_INIT("vix"))
    return 1;

  return 0;
}

static void on_unload(ErlNifEnv *env, void *priv) {
  vips_shutdown();
  debug("vix unload");
}

static ErlNifFunc nif_funcs[] = {
    /*  VipsImage */
    {"nif_image_new_from_file", 1, nif_image_new_from_file, USE_DIRTY_IO},
    {"nif_image_write_to_file", 2, nif_image_write_to_file, USE_DIRTY_IO},
    /*  VipsOperation */
    {"nif_vips_operation_call", 2, nif_vips_operation_call, USE_DIRTY_IO},
    {"nif_vips_operation_get_arguments", 1, nif_vips_operation_get_arguments,
     USE_DIRTY_IO},
    {"nif_vips_operation_list", 0, nif_vips_operation_list, USE_DIRTY_IO},
    /*  VipsBoxed */
    {"nif_int_array", 1, nif_int_array, USE_DIRTY_IO},
    {"nif_double_array", 1, nif_double_array, USE_DIRTY_IO}};

ERL_NIF_INIT(Elixir.Vix.Nif, nif_funcs, &on_load, NULL, NULL, &on_unload)
