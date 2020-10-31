#include "nif_g_type.h"
#include "vix_common.h"
#include <glib-object.h>

static inline ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

ERL_NIF_TERM g_type_to_erl_term(ErlNifEnv *env, GType g_type) {
  GTypeResource *g_type_r =
      enif_alloc_resource(G_TYPE_RT, sizeof(GTypeResource));

  g_type_r->g_type = g_type;
  ERL_NIF_TERM term = enif_make_resource(env, g_type_r);
  enif_release_resource(g_type_r);

  return term;
}

bool erl_term_to_g_type(ErlNifEnv *env, ERL_NIF_TERM term, GType *g_type) {
  GTypeResource *g_type_r = NULL;
  if (enif_get_resource(env, term, G_TYPE_RT, (void **)&g_type_r)) {
    (*g_type) = g_type_r->g_type;
    return true;
  } else {
    return false;
  }
}

ERL_NIF_TERM nif_g_type_name(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GType g_type;
  if (!erl_term_to_g_type(env, argv[0], &g_type)) {
    error("Failed to get GType");
    return enif_make_badarg(env);
  }

  return enif_make_string(env, g_type_name(g_type), ERL_NIF_LATIN1);
}

ERL_NIF_TERM nif_g_type_from_name(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  char name[200] = {'\0'};
  if (enif_get_string(env, argv[0], name, 200, ERL_NIF_LATIN1) < 1) {
    error("name must be a valid string");
    return enif_make_badarg(env);
  }

  GType g_type = g_type_from_name(name);
  if (!g_type) {
    error("GType not found %s", name);
    return enif_raise_exception(
        env, enif_make_string(env, "GType not found", ERL_NIF_LATIN1));
  }

  return make_ok(env, g_type_to_erl_term(env, g_type));
}

/******* GType Resource *******/
static void g_type_dtor(ErlNifEnv *env, void *obj) {
  debug("GType g_type_dtor called");
}

static void g_type_stop(ErlNifEnv *env, void *obj, int fd, int is_direct_call) {
  debug("GType g_type_stop called %d", fd);
}

static void g_type_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                        ErlNifMonitor *monitor) {
  debug("GType g_type_down called");
}

static ErlNifResourceTypeInit g_type_rt_init = {g_type_dtor, g_type_stop,
                                                g_type_down};

int nif_g_type_init(ErlNifEnv *env) {

  G_TYPE_RT =
      enif_open_resource_type_x(env, "g_type_resource", &g_type_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);
  return 0;
}
