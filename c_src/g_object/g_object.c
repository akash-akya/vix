#include <glib-object.h>

#include "../utils.h"

#include "g_object.h"

ErlNifResourceType *G_OBJECT_RT;

// Ownership is traferred to beam resource, `obj` must *not* be freed
// by the caller
ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *obj) {
  ERL_NIF_TERM term;
  GObjectResource *gobject_r;

  gobject_r = enif_alloc_resource(G_OBJECT_RT, sizeof(GObjectResource));

  // TODO: Keep gtype name and use elixir-struct instead of c-struct,
  // so that type information is visible in elixir.
  gobject_r->obj = obj;

  term = enif_make_resource(env, gobject_r);
  enif_release_resource(gobject_r);

  return term;
}

ERL_NIF_TERM nif_g_object_type_name(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GObject *obj;

  if (!erl_term_to_g_object(env, argv[0], &obj))
    return make_error(env, "Failed to get GObject");

  return make_binary(env, G_OBJECT_TYPE_NAME(obj));
}

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term, GObject **obj) {
  GObjectResource *gobject_r = NULL;
  if (enif_get_resource(env, term, G_OBJECT_RT, (void **)&gobject_r)) {
    (*obj) = gobject_r->obj;
    return true;
  }
  return false;
}

static void g_object_dtor(ErlNifEnv *env, void *ptr) {
  GObjectResource *gobject_r = (GObjectResource *)ptr;
  g_object_unref(gobject_r->obj);
  debug("GObjectResource dtor");
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
