#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"

ErlNifResourceType *G_BOXED_RT;

static ERL_NIF_TERM ATOM_UNREF_GBOXED;

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

ERL_NIF_TERM nif_g_boxed_unref(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GBoxedResource *gboxed_r = NULL;

  if (!enif_get_resource(env, argv[0], G_BOXED_RT, (void **)&gboxed_r)) {
    // This should never happen, since g_boxed_unref is an internal call
    return ATOM_ERROR;
  }

  g_boxed_free(gboxed_r->boxed_type, gboxed_r->boxed_ptr);

  gboxed_r->boxed_ptr = NULL;

  debug("GBoxed unref");

  return ATOM_OK;
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
  GBoxedResource *orig_boxed_r = (GBoxedResource *)obj;

  /*
   * Safely unref objects using the janitor process.
   * See g_object_dtor() for details
   */
  if (orig_boxed_r->boxed_ptr != NULL) {
    GBoxedResource *temp_gboxed_r = NULL;
    ERL_NIF_TERM temp_term;

    temp_gboxed_r = enif_alloc_resource(G_BOXED_RT, sizeof(GBoxedResource));
    temp_gboxed_r->boxed_ptr = orig_boxed_r->boxed_ptr;
    temp_gboxed_r->boxed_type = orig_boxed_r->boxed_type;

    temp_term = enif_make_resource(env, temp_gboxed_r);
    enif_release_resource(temp_gboxed_r);

    send_to_janitor(env, ATOM_UNREF_GBOXED, temp_term);

    debug("GBoxedResource is sent to janitor process");
  } else {
    debug("GBoxedResource is already unset");
  }
}

int nif_g_boxed_init(ErlNifEnv *env) {
  G_BOXED_RT = enif_open_resource_type(
      env, NULL, "g_boxed_resource", (ErlNifResourceDtor *)g_boxed_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_BOXED_RT) {
    error("Failed to open g_boxed_resource");
    return 1;
  }

  ATOM_UNREF_GBOXED = make_atom(env, "unref_gboxed");

  return 0;
}
