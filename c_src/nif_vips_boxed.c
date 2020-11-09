#include "nif_vips_boxed.h"
#include "nif_g_boxed.h"
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

ERL_NIF_TERM nif_int_array(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {

  assert_argc(argc, 1);

  GBoxedResource *g_boxed_r =
      enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));

  unsigned int len;
  if (!enif_get_list_length(env, argv[0], &len)) {
    error("Failed to get list length");
    return enif_make_badarg(env);
  }

  int array[len];
  VipsArrayInt *vips_array =
      erl_list_to_vips_int_array(env, argv[0], len, array);

  g_boxed_r->boxed_type = VIPS_TYPE_ARRAY_INT;
  g_boxed_r->g_boxed = vips_array;

  ERL_NIF_TERM term = enif_make_resource(env, g_boxed_r);
  enif_release_resource(g_boxed_r);

  return term;
}

ERL_NIF_TERM nif_double_array(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  GBoxedResource *g_boxed_r =
      enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));

  unsigned int len;
  if (!enif_get_list_length(env, argv[0], &len)) {
    error("Failed to get list length");
    return enif_make_badarg(env);
  }

  double array[len];
  VipsArrayDouble *vips_array =
      erl_list_to_vips_double_array(env, argv[0], len, array);

  g_boxed_r->boxed_type = VIPS_TYPE_ARRAY_DOUBLE;
  g_boxed_r->g_boxed = vips_array;

  ERL_NIF_TERM term = enif_make_resource(env, g_boxed_r);
  enif_release_resource(g_boxed_r);

  return term;
}
