#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"

static void nif_g_boxed_dtor(ErlNifEnv *env, void *obj) {
  GBoxedResource *boxed_r = (GBoxedResource *)obj;
  g_boxed_free(boxed_r->boxed_type, boxed_r->boxed_ptr);
  debug("GBoxedResource dtor");
}

bool erl_term_to_g_boxed(ErlNifEnv *env, ERL_NIF_TERM term, gpointer *ptr) {
  GBoxedResource *boxed_r = NULL;

  if (enif_get_resource(env, term, G_BOXED_RT, (void **)&boxed_r)) {
    (*ptr) = boxed_r->boxed_ptr;
    return true;
  }

  return false;
}

int nif_g_boxed_init(ErlNifEnv *env) {
  G_BOXED_RT = enif_open_resource_type(
      env, NULL, "g_boxed_resource", (ErlNifResourceDtor *)nif_g_boxed_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_BOXED_RT) {
    error("Failed to open g_boxed_resource");
    return 1;
  }

  return 0;
}
