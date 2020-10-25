#include "nif_g_object.h"
#include "eips_common.h"
#include "nif_g_type.h"
#include <glib-object.h>

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
  } else {
    return false;
  }
}

ERL_NIF_TERM nif_g_object_type(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GObject *g_object;
  if (!erl_term_to_g_object(env, argv[0], &g_object)) {
    error("Failed to get GObject");
    return enif_make_badarg(env);
  }

  return g_type_to_erl_term(env, G_OBJECT_TYPE(g_object));
}

ERL_NIF_TERM nif_g_object_type_name(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GObject *g_object;
  if (!erl_term_to_g_object(env, argv[0], &g_object)) {
    error("Failed to get GObject");
    return enif_make_badarg(env);
  }

  return enif_make_string(env, G_OBJECT_TYPE_NAME(g_object), ERL_NIF_LATIN1);
}

/******* GObject Resource *******/
static void g_object_dtor(ErlNifEnv *env, void *obj) {
  GObjectResource *g_object_resource = (GObjectResource *)obj;
  g_object_unref(g_object_resource->g_object);
  debug("GObject g_object_dtor called");
}

static void g_object_stop(ErlNifEnv *env, void *obj, int fd,
                          int is_direct_call) {
  debug("GObject g_object_stop called %d", fd);
}

static void g_object_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                          ErlNifMonitor *monitor) {
  debug("GObject g_object_down called");
}

static ErlNifResourceTypeInit g_object_rt_init = {g_object_dtor, g_object_stop,
                                                  g_object_down};

int nif_g_object_init(ErlNifEnv *env) {
  G_OBJECT_RT =
      enif_open_resource_type_x(env, "g_object_resource", &g_object_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  return 0;
}
