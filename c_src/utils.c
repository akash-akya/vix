#include "utils.h"
#include <errno.h>
#include <glib-object.h>
#include <stdbool.h>
#include <unistd.h>

ErlNifResourceType *VIX_BINARY_RT;

int MAX_G_TYPE_NAME_LENGTH = 1024;

const int VIX_FD_CLOSED = -1;

ERL_NIF_TERM ATOM_OK;
ERL_NIF_TERM ATOM_ERROR;
ERL_NIF_TERM ATOM_NIL;
ERL_NIF_TERM ATOM_TRUE;
ERL_NIF_TERM ATOM_FALSE;
ERL_NIF_TERM ATOM_NULL_VALUE;
ERL_NIF_TERM ATOM_UNDEFINED;
ERL_NIF_TERM ATOM_EAGAIN;

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, ATOM_ERROR, make_binary(env, reason));
}

ERL_NIF_TERM make_error_term(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_ERROR, term);
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

static void vix_binary_dtor(ErlNifEnv *env, void *ptr) {
  VixBinaryResource *vix_bin_r = (VixBinaryResource *)ptr;
  g_free(vix_bin_r->data);
  debug("vix_binary_resource dtor");
}

int utils_init(ErlNifEnv *env) {
  ATOM_OK = make_atom(env, "ok");
  ATOM_ERROR = make_atom(env, "error");
  ATOM_NIL = make_atom(env, "nil");
  ATOM_TRUE = make_atom(env, "true");
  ATOM_FALSE = make_atom(env, "false");
  ATOM_NULL_VALUE = make_atom(env, "null_value");
  ATOM_UNDEFINED = make_atom(env, "undefined");
  ATOM_EAGAIN = make_atom(env, "eagain");

  VIX_BINARY_RT = enif_open_resource_type(
      env, NULL, "vix_binary_resource", (ErlNifResourceDtor *)vix_binary_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!VIX_BINARY_RT) {
    error("Failed to open vix_binary_resource");
    return 1;
  }

  return 0;
}

int close_fd(int *fd) {
  int ret = 0;

  if (*fd != VIX_FD_CLOSED) {
    ret = close(*fd);

    if (ret != 0) {
      error("failed to close fd: %d, error: %s", *fd, strerror(errno));
    } else {
      *fd = VIX_FD_CLOSED;
    }
  }

  return ret;
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

ERL_NIF_TERM to_binary_term(ErlNifEnv *env, void *data, size_t size) {
  VixBinaryResource *vix_bin_r =
      enif_alloc_resource(VIX_BINARY_RT, sizeof(VixBinaryResource));
  ERL_NIF_TERM bin_term;

  vix_bin_r->data = data;
  vix_bin_r->size = size;

  bin_term = enif_make_resource_binary(env, vix_bin_r, vix_bin_r->data,
                                       vix_bin_r->size);

  enif_release_resource(vix_bin_r);

  return bin_term;
}
