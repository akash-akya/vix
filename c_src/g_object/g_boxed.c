#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"

static void nif_g_boxed_dtor(ErlNifEnv *env, void *obj) {
  GBoxedResource *g_boxed_r = (GBoxedResource *)obj;
  g_boxed_free(g_boxed_r->boxed_type, g_boxed_r->g_boxed);
  debug("Nif GBoxed base nif_g_boxed_dtor called");
}

static void nif_g_boxed_stop(ErlNifEnv *env, void *obj, int fd,
                             int is_direct_call) {
  debug("Nif GBoxed base nif_g_boxed_stop called");
}

static void nif_g_boxed_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                             ErlNifMonitor *monitor) {
  debug("Nif GBoxed base nif_g_boxed_down called");
}

static ErlNifResourceTypeInit g_boxed_rt_init = {
    nif_g_boxed_dtor, nif_g_boxed_stop, nif_g_boxed_down};

bool erl_term_to_g_boxed(ErlNifEnv *env, ERL_NIF_TERM term, gpointer *ptr) {
  GBoxedResource *g_boxed_r = NULL;
  if (enif_get_resource(env, term, G_BOXED_RT, (void **)&g_boxed_r)) {
    (*ptr) = g_boxed_r->g_boxed;
    return true;
  }
  return false;
}

ERL_NIF_TERM nif_g_boxed_init(ErlNifEnv *env) {
  G_BOXED_RT =
      enif_open_resource_type_x(env, "g_boxed_resource", &g_boxed_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_BOXED_RT)
    return raise_exception(env, "Failed to open g_boxed_resource");

  return ATOM_OK;
}
