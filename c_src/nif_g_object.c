#include "nif_g_object.h"
#include "vix_utils.h"
#include <glib-object.h>

static void nif_g_object_dtor(ErlNifEnv *env, void *obj) {
  GObjectResource *g_object_r = (GObjectResource *)obj;

  debug("Nif GObject nif_g_object_dtor called");
  g_object_unref(g_object_r->g_object);
}

static void nif_g_object_stop(ErlNifEnv *env, void *obj, int fd,
                              int is_direct_call) {
  debug("Nif GObject nif_g_object_stop called");
}

static void nif_g_object_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                              ErlNifMonitor *monitor) {
  debug("Nif GObject nif_g_object_down called");
}

static ErlNifResourceTypeInit g_object_rt_init = {
    nif_g_object_dtor, nif_g_object_stop, nif_g_object_down};

/******* GObject Generic API *******/
ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *g_object) {
  GObjectResource *g_object_r =
      enif_alloc_resource(G_OBJECT_RT, sizeof(GObjectResource));

  g_object_r->g_object = g_object_ref(g_object);

  ERL_NIF_TERM term = enif_make_resource(env, g_object_r);
  enif_release_resource(g_object_r);

  return term;
}

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                          GObject **g_object) {
  GObjectResource *g_object_r = NULL;
  if (enif_get_resource(env, term, G_OBJECT_RT, (void **)&g_object_r)) {
    (*g_object) = g_object_r->g_object;
    return true;
  }
  return false;
}

ERL_NIF_TERM nif_g_object_init(ErlNifEnv *env) {
  G_OBJECT_RT =
      enif_open_resource_type_x(env, "g_object_resource", &g_object_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_OBJECT_RT)
    return raise_exception(env, "Failed to open g_object_resource");

  return ATOM_OK;
}
