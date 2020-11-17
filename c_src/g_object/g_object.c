#include <glib-object.h>

#include "../utils.h"

#include "g_object.h"

static void g_object_dtor(ErlNifEnv *env, void *ptr) {
  GObjectResource *gobject_r = (GObjectResource *)ptr;
  g_object_unref(gobject_r->obj);
  debug("GObjectResource dtor");
}

ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *obj) {
  GObjectResource *gobject_r =
      enif_alloc_resource(G_OBJECT_RT, sizeof(GObjectResource));

  gobject_r->obj = g_object_ref(obj);

  ERL_NIF_TERM term = enif_make_resource(env, gobject_r);
  enif_release_resource(gobject_r);

  return term;
}

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                          GObject **obj) {
  GObjectResource *gobject_r = NULL;
  if (enif_get_resource(env, term, G_OBJECT_RT, (void **)&gobject_r)) {
    (*obj) = gobject_r->obj;
    return true;
  }
  return false;
}

int nif_g_object_init(ErlNifEnv *env) {
  G_OBJECT_RT = enif_open_resource_type(
      env, NULL, "g_object_resource", (ErlNifResourceDtor *)g_object_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_OBJECT_RT) {
    error("Failed to open gobject_resource");
    return 1;
  }

  return 0;
}
