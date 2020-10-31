#include "nif_g_param_spec.h"
#include "eips_common.h"
#include "nif_g_type.h"
#include <glib-object.h>

/******* Public *******/
ERL_NIF_TERM g_param_spec_to_erl_term(ErlNifEnv *env, GParamSpec *pspec) {
  GParamSpecResource *pspec_r =
      enif_alloc_resource(G_PARAM_SPEC_RT, sizeof(GParamSpecResource));

  pspec_r->pspec = pspec;
  ERL_NIF_TERM term = enif_make_resource(env, pspec_r);
  enif_release_resource(pspec_r);

  return term;
}

bool erl_term_to_g_param_spec(ErlNifEnv *env, ERL_NIF_TERM term,
                              GParamSpec **pspec) {
  GParamSpecResource *pspec_r = NULL;
  if (enif_get_resource(env, term, G_PARAM_SPEC_RT, (void **)&pspec_r)) {
    (*pspec) = pspec_r->pspec;
    return true;
  } else {
    return false;
  }
}

ERL_NIF_TERM nif_g_param_spec_type(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GParamSpec *pspec;
  if (!erl_term_to_g_param_spec(env, argv[0], &pspec)) {
    error("Failed to get GParamSpec");
    return enif_make_badarg(env);
  }

  return g_type_to_erl_term(env, G_PARAM_SPEC_TYPE(pspec));
}

ERL_NIF_TERM nif_g_param_spec_value_type(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GParamSpec *pspec;
  if (!erl_term_to_g_param_spec(env, argv[0], &pspec)) {
    error("Failed to get GParamSpec");
    return enif_make_badarg(env);
  }

  return g_type_to_erl_term(env, G_PARAM_SPEC_VALUE_TYPE(pspec));
}

ERL_NIF_TERM nif_g_param_spec_get_name(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GParamSpec *pspec;
  if (!erl_term_to_g_param_spec(env, argv[0], &pspec)) {
    error("Failed to get GParamSpec");
    return enif_make_badarg(env);
  }

  return enif_make_string(env, g_param_spec_get_name(pspec), ERL_NIF_LATIN1);
}

ERL_NIF_TERM nif_g_param_spec_type_name(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GParamSpec *pspec;
  if (!erl_term_to_g_param_spec(env, argv[0], &pspec)) {
    error("Failed to get GParamSpec");
    return enif_make_badarg(env);
  }

  GType gtype = G_PARAM_SPEC_TYPE(pspec);
  return enif_make_string(env, g_type_name(gtype), ERL_NIF_LATIN1);
}

ERL_NIF_TERM nif_g_param_spec_value_type_name(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]) {
  if (argc != 1) {
    error("number of arguments must be 1");
    return enif_make_badarg(env);
  }

  GParamSpec *pspec;
  if (!erl_term_to_g_param_spec(env, argv[0], &pspec)) {
    error("Failed to get GParamSpec");
    return enif_make_badarg(env);
  }

  GType gtype = G_PARAM_SPEC_VALUE_TYPE(pspec);
  return enif_make_string(env, g_type_name(gtype), ERL_NIF_LATIN1);
}

/******* GParamSpec Resource *******/
static void g_param_spec_dtor(ErlNifEnv *env, void *obj) {
  debug("GParamSpec g_param_spec_dtor called");
}

static void g_param_spec_stop(ErlNifEnv *env, void *obj, int fd,
                              int is_direct_call) {
  debug("GParamSpec g_param_spec_stop called %d", fd);
}

static void g_param_spec_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                              ErlNifMonitor *monitor) {
  debug("GParamSpec g_param_spec_down called");
}

static ErlNifResourceTypeInit g_param_spec_rt_init = {
    g_param_spec_dtor, g_param_spec_stop, g_param_spec_down};

int nif_g_param_spec_init(ErlNifEnv *env) {

  G_PARAM_SPEC_RT = enif_open_resource_type_x(
      env, "g_param_spec_resource", &g_param_spec_rt_init,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);
  return 0;
}
