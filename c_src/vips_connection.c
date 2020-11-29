#include <glib-object.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "utils.h"
#include "vips_connection.h"

const int STATUS_PENDING = 0;
const int STATUS_DONE = 1;

static gint64 read_from_erl(VipsSourceCustom *source, void *buffer,
                            gint64 length, void *user) {
  ErlNifEnv *env;
  VixCallbackResource *cb;
  ERL_NIF_TERM msg;
  ErlNifPid *pid;
  gint64 read_length;

  pid = (ErlNifPid *)user;
  env = enif_alloc_env();

  cb = enif_alloc_resource(VIX_CALLBACK_RT, sizeof(VixCallbackResource));

  cb->lock = enif_mutex_create("vix:source_mutex");
  cb->cond = enif_cond_create("vix:source_cond");
  cb->status = STATUS_PENDING;
  cb->result = buffer;

  enif_mutex_lock(cb->lock);

  msg = enif_make_tuple3(env, make_atom(env, "read"),
                         enif_make_int64(env, length),
                         enif_make_resource(env, cb));

  if (!enif_send(NULL, pid, env, msg)) {
    error("failed to send message");
    enif_release_resource(cb);
    return -1;
  }

  while (cb->status == STATUS_PENDING)
    enif_cond_wait(cb->cond, cb->lock);

  read_length = cb->size;

  enif_mutex_unlock(cb->lock);

  if (read_length < length) {
    enif_send(NULL, pid, env, make_atom(env, "close"));
    g_free(pid);
  }

  enif_release_resource(cb);
  enif_free_env(env);

  return read_length;
}

static gint64 seek_from_erl(VipsSourceCustom *source, gint64 pos, int whence,
                            void *user) {
  return -1;
}

ERL_NIF_TERM nif_vips_source_new(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);

  VipsSourceCustom *source;
  ErlNifPid *pid;

  pid = g_new(ErlNifPid, 1);

  if (!enif_self(env, pid))
    return make_error(env, "failed to create vips source");

  source = vips_source_custom_new();

  g_signal_connect(source, "read", G_CALLBACK(read_from_erl), pid);
  g_signal_connect(source, "seek", G_CALLBACK(seek_from_erl), pid);

  return make_ok(env, g_object_to_erl_term(env, (GObject *)source));
}

ERL_NIF_TERM nif_vips_conn_write_result(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

  VixCallbackResource *cb;
  ErlNifBinary bin;

  if (!enif_inspect_binary(env, argv[0], &bin)) {
    return make_error(env, "failed to get binary");
  }

  if (!enif_get_resource(env, argv[1], VIX_CALLBACK_RT, (void **)&cb)) {
    return make_error(env, "failed to get result term");
  }

  enif_mutex_lock(cb->lock);

  memcpy(cb->result, bin.data, bin.size);

  cb->size = bin.size;
  cb->status = STATUS_DONE;

  enif_cond_signal(cb->cond);
  enif_mutex_unlock(cb->lock);

  return ATOM_OK;
}

static void vix_callback_dtor(ErlNifEnv *env, void *obj) {
  debug("VixCallbackResource dtor");
}

int nif_vips_connection_init(ErlNifEnv *env) {
  VIX_CALLBACK_RT =
      enif_open_resource_type(env, NULL, "vix_callback_resource",
                              (ErlNifResourceDtor *)vix_callback_dtor,
                              ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!VIX_CALLBACK_RT) {
    error("Failed to open vix_callback_resource");
    return 1;
  }

  return 0;
}
