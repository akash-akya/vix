#include "nif_g_object.h"
#include "eips_common.h"
#include "nif_g_type.h"
#include <glib-object.h>

/******* GObject Private *******/
static void nif_g_object_dtor(ErlNifEnv *env, void *obj) {
  GObjectResource *g_object_r = (GObjectResource *)obj;
  NifGObjectClass *g_class = g_object_r->class;

  debug("Nif GObject base nif_g_object_dtor called");
  g_object_r->class = g_class->parent;
  (*g_class->dtor)(env, g_object_r);
}

static void nif_g_object_stop(ErlNifEnv *env, void *obj, int fd,
                              int is_direct_call) {
  debug("Nif GObject base nif_g_object_stop called");
}

static void nif_g_object_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                              ErlNifMonitor *monitor) {
  debug("Nif GObject base nif_g_object_down called");
}

static ErlNifResourceTypeInit g_object_rt_init = {
    nif_g_object_dtor, nif_g_object_stop, nif_g_object_down};

/******* GObject *******/
static void g_object_dtor(ErlNifEnv *env, GObjectResource *g_object_r) {
  g_object_unref(g_object_r->g_object);
  debug("GObject g_object_dtor called");
}

NifGObjectClass NIF_G_OBJECT_CLASS = {g_object_dtor, NULL};

/******* GObject Generic API *******/
ERL_NIF_TERM g_object_to_erl_term_with_type(ErlNifEnv *env, GObject *g_object,
                                            NifGObjectClass *nif_g_class) {
  GObjectResource *g_object_r =
      enif_alloc_resource(G_OBJECT_RT, sizeof(GObjectResource));

  g_object_r->g_object = g_object_ref(g_object);
  g_object_r->class = nif_g_class;

  ERL_NIF_TERM term = enif_make_resource(env, g_object_r);
  enif_release_resource(g_object_r);

  return term;
}

bool erl_term_to_g_object_with_type(ErlNifEnv *env, ERL_NIF_TERM term,
                                    GObject **g_object,
                                    NifGObjectClass *nif_g_class) {
  GObjectResource *g_object_r = NULL;
  if (enif_get_resource(env, term, G_OBJECT_RT, (void **)&g_object_r)) {
    /* if (g_object_r->class == nif_g_class) { */
      (*g_object) = g_object_r->g_object;
      return true;
    /* } else { */
    /*   error("NifGObjectClass does not match with the resource"); */
    /* } */
  }
  return false;
}

/******* GObject Public API *******/
ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *g_object) {
  return g_object_to_erl_term_with_type(env, g_object, &NIF_G_OBJECT_CLASS);
}

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term,
                          GObject **g_object) {
  return erl_term_to_g_object_with_type(env, term, g_object,
                                        &NIF_G_OBJECT_CLASS);
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

void super_g_object_dtor(ErlNifEnv *env, GObjectResource *g_object_r) {
  NifGObjectClass *parent = g_object_r->class->parent;
  g_object_r->class = parent;
  (*(parent->dtor))(env, g_object_r);
}

int nif_g_object_init(ErlNifEnv *env) {
  G_OBJECT_RT =
      enif_open_resource_type_x(env, "g_object_resource", &g_object_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  return 0;
}
