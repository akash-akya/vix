#include "utils.h"
#include <glib-object.h>
#include <stdbool.h>

int MAX_G_TYPE_NAME_LENGTH = 1024;

ERL_NIF_TERM ATOM_OK;
ERL_NIF_TERM ATOM_ERROR;
ERL_NIF_TERM ATOM_NIL;
ERL_NIF_TERM ATOM_TRUE;
ERL_NIF_TERM ATOM_FALSE;
ERL_NIF_TERM ATOM_NULL_VALUE;

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, ATOM_ERROR, make_binary(env, reason));
}

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg) {
  return enif_raise_exception(env, make_binary(env, msg));
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

ERL_NIF_TERM make_binary(ErlNifEnv *env, const char *str) {
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;

  length = strlen(str);
  temp = enif_make_new_binary(env, length, &bin);
  memcpy(temp, str, length);

  return bin;
}

bool get_binary(ErlNifEnv *env, ERL_NIF_TERM bin_term, char *str,
                ssize_t dest_size) {
  ErlNifBinary bin;

  if (!enif_inspect_binary(env, bin_term, &bin)) {
    error("failed to get binary string from erl term");
    return false;
  }

  if (bin.size >= dest_size) {
    error("destination size is smaller than required");
    return false;
  }

  memcpy(str, bin.data, bin.size);
  str[bin.size] = '\0';

  return true;
}

VixResult vix_result(ERL_NIF_TERM term) {
  return (VixResult){.is_success = true, .result = term};
}

int utils_init(ErlNifEnv *env) {
  ATOM_OK = make_atom(env, "ok");
  ATOM_ERROR = make_atom(env, "error");
  ATOM_NIL = make_atom(env, "nil");
  ATOM_TRUE = make_atom(env, "true");
  ATOM_FALSE = make_atom(env, "false");
  ATOM_NULL_VALUE = make_atom(env, "null_value");

  return 0;
}

void notify_consumed_timeslice(ErlNifEnv *env, ErlNifTime start,
                               ErlNifTime stop) {
  ErlNifTime pct;

  pct = (ErlNifTime)((stop - start) / 10);
  if (pct > 100)
    pct = 100;
  else if (pct == 0)
    pct = 1;
  enif_consume_timeslice(env, pct);
}
