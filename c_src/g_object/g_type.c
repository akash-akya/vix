#include <glib-object.h>

#include "../utils.h"

#include "g_boxed.h"
#include "g_object.h"
#include "g_type.h"

ErlNifResourceType *G_TYPE_RT;

static ERL_NIF_TERM g_type_to_erl_term(ErlNifEnv *env, GType type) {
  GTypeResource *gtype_r;
  ERL_NIF_TERM term;

  gtype_r = enif_alloc_resource(G_TYPE_RT, sizeof(GTypeResource));
  gtype_r->type = type;

  term = enif_make_resource(env, gtype_r);
  enif_release_resource(gtype_r);

  return term;
}

static bool erl_term_to_g_type(ErlNifEnv *env, ERL_NIF_TERM term, GType *type) {
  GTypeResource *gtype_r = NULL;
  if (enif_get_resource(env, term, G_TYPE_RT, (void **)&gtype_r)) {
    (*type) = gtype_r->type;
    return true;
  }
  return false;
}

ERL_NIF_TERM nif_g_type_from_instance(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {

  ASSERT_ARGC(argc, 1);

  ERL_NIF_TERM term;
  GObject *obj;
  GType type;

  if (erl_term_to_g_object(env, argv[0], &obj)) {
    term = g_type_to_erl_term(env, G_TYPE_FROM_INSTANCE(obj));
    return make_ok(env, term);
  } else if (erl_term_boxed_type(env, argv[0], &type)) {
    term = g_type_to_erl_term(env, type);
    return make_ok(env, term);
  } else {
    return make_error(env, "Invalid GTypeInstance");
  }
}

ERL_NIF_TERM nif_g_type_name(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GType type;

  if (!erl_term_to_g_type(env, argv[0], &type))
    return make_error(env, "Failed to get GType");

  return make_ok(env, make_binary(env, g_type_name(type)));
}

static void g_type_dtor(ErlNifEnv *env, void *obj) {
  debug("GTypeResource dtor");
}

int nif_g_type_init(ErlNifEnv *env) {
  G_TYPE_RT = enif_open_resource_type(
      env, NULL, "g_type_resource", (ErlNifResourceDtor *)g_type_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_TYPE_RT) {
    error("Failed to open g_type_resource");
    return 1;
  }

  return 0;
}
