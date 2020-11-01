#include <glib-object.h>
#include <stdbool.h>
#include "vix_utils.h"

ERL_NIF_TERM ATOM_OK;

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

void vix_utils_init(ErlNifEnv *env){
  ATOM_OK = enif_make_atom(env, "ok");
}

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg) {
  return enif_raise_exception(env, enif_make_string(env, msg, ERL_NIF_LATIN1));
}
