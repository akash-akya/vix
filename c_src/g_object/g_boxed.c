#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"

ErlNifResourceType *G_BOXED_RT;

bool erl_term_to_g_boxed(ErlNifEnv *env, ERL_NIF_TERM term, gpointer *ptr) {
  GBoxedResource *boxed_r = NULL;

  if (enif_get_resource(env, term, G_BOXED_RT, (void **)&boxed_r)) {
    (*ptr) = boxed_r->boxed_ptr;
    return true;
  }

  return false;
}

bool erl_term_boxed_type(ErlNifEnv *env, ERL_NIF_TERM term, GType *type) {
  GBoxedResource *boxed_r = NULL;

  if (enif_get_resource(env, term, G_BOXED_RT, (void **)&boxed_r)) {
    (*type) = boxed_r->boxed_type;
    return true;
  }

  return false;
}

ERL_NIF_TERM boxed_to_erl_term(ErlNifEnv *env, gpointer ptr, GType type) {
  ERL_NIF_TERM term;
  GBoxedResource *boxed_r;

  boxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));

  // TODO: use elixir-struct instead of c-struct, so that type
  // information is visible in elixir
  boxed_r->boxed_type = type;
  boxed_r->boxed_ptr = ptr;

  term = enif_make_resource(env, boxed_r);
  enif_release_resource(boxed_r);

  return term;
}

static void g_boxed_dtor(ErlNifEnv *env, void *obj) {
  GBoxedResource *boxed_r = (GBoxedResource *)obj;
  g_boxed_free(boxed_r->boxed_type, boxed_r->boxed_ptr);
  debug("GBoxedResource dtor");
}

int nif_g_boxed_init(ErlNifEnv *env) {
  G_BOXED_RT = enif_open_resource_type(
      env, NULL, "g_boxed_resource", (ErlNifResourceDtor *)g_boxed_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_BOXED_RT) {
    error("Failed to open g_boxed_resource");
    return 1;
  }

  return 0;
}
