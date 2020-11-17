#include "utils.h"
#include <glib-object.h>
#include <stdbool.h>

ERL_NIF_TERM ATOM_OK;
ERL_NIF_TERM ATOM_ERROR;
ERL_NIF_TERM ATOM_NIL;

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, ATOM_ERROR,
                          enif_make_string(env, reason, ERL_NIF_LATIN1));
}

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg) {
  error(msg);
  return enif_raise_exception(env, enif_make_string(env, msg, ERL_NIF_LATIN1));
}

ERL_NIF_TERM raise_badarg(ErlNifEnv *env, const char *reason) {
  error("bad argument: %s", reason);
  return enif_make_badarg(env);
}

ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *name) {
  ERL_NIF_TERM ret;
  if (enif_make_existing_atom(env, name, &ret, ERL_NIF_LATIN1)) {
    return ret;
  }
  return enif_make_atom(env, name);
}

int utils_init(ErlNifEnv *env) {
  ATOM_OK = make_atom(env, "ok");
  ATOM_ERROR = make_atom(env, "error");
  ATOM_NIL = make_atom(env, "nil");

  return 0;
}
