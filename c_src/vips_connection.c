#include <glib-object.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "utils.h"
#include "vips_connection.h"

const int STATUS_PENDING = 0;
const int STATUS_DONE = 1;

typedef struct _VixCallback {
  ErlNifPid *pid;
  ErlNifMutex *lock;
  ErlNifCond *cond;
} VixCallback;

static ERL_NIF_TERM new_vix_cb_result_term(ErlNifEnv *env, void *ptr,
                                           int *status) {
  ERL_NIF_TERM term;
  VixCallbackResultResource *cb_r;

  cb_r = enif_alloc_resource(VIX_CALLBACK_RESULT_RT,
                             sizeof(VixCallbackResultResource));

  status = STATUS_PENDING;

  cb_r->status = status;
  cb_r->result = ptr;

  term = enif_make_resource(env, cb_r);
  enif_release_resource(cb_r);

  return term;
}

static int send_read_msg(ErlNifPid *pid, gint64 length, void *buffer,
                         int *status) {
  ErlNifEnv *env;
  ERL_NIF_TERM term;
  int res;

  env = enif_alloc_env();

  term = new_vix_cb_result_term(env, buffer, status);

  msg = enif_make_tuple3(env, make_atom(env, "read"),
                         enif_make_int64(env, length) term);

  res = enif_send(NULL, pid, env, msg);

  enif_free_env(env);
  return res;
}

static gint64 read_from_erl(VipsSourceCustom *source, void *buffer,
                            gint64 length, void *user) {
  size_t items;
  VixCallback *cb;
  ERL_NIF_TERM msg;
  int res;
  int status = STATUS_PENDING;

  cb = (VixCallback *)user;

  enif_mutex_lock(cb->lock);

  debug("size: %d", length);

  res = send_read_msg(pid, length, buffer, &status);

  if (!res) {
    error("failed to send message");
    goto exit;
  }

  debug("sent msg", items);

  while (status == PENDING)
    enif_cond_wait(cb->cond, cb->lock);

  debug("read", items);

exit:
  enif_mutex_unlock(cb->lock);
  return (items);
}

static gint64 seek_from_erl(VipsSourceCustom *source, gint64 pos, int whence,
                            void *user) {
  return -1;
}

ERL_NIF_TERM nif_vips_source_new(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 0);

  VipsSourceCustom *source;
  ErlNifPid pid;
  VixCallback *cb;
  ErlNifMutex *lock;

  if (!enif_self(env, &pid))
    return make_error(env, "failed to create vips source");

  lock = enif_mutex_create("vix:source");

  cb = g_new(VixCallback, 1);

  cb->pid = pid;
  cb->lock = lock;

  source = vips_source_custom_new();

  g_signal_connect(source, "read", G_CALLBACK(read_from_erl), cb);
  g_signal_connect(source, "seek", G_CALLBACK(seek_from_erl), conn);

  return make_ok(env, g_object_to_erl_term(env, source));
}

ERL_NIF_TERM nif_vips_conn_write_result(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

  VipsSourceCustom *source;
  ErlNifPid pid;
  VixCallback *cb;
  ErlNifMutex *lock;

  if (!enif_self(env, &pid))
    return make_error(env, "failed to create vips source");

  lock = enif_mutex_create("vix:source");

  cb = g_new(VixCallback, 1);

  cb->pid = pid;
  cb->lock = lock;

  return make_ok(env, g_object_to_erl_term(env, source));
}

static void vix_callback_dtor(ErlNifEnv *env, void *obj) {
  debug("VixCallbackResultResource dtor");
}

int nif_vips_connection_init(ErlNifEnv *env) {
  VIX_CALLBACK_RESULT_RT =
      enif_open_resource_type(env, NULL, "vix_callback_result_resource",
                              (ErlNifResourceDtor *)vix_callback_dtor,
                              ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!VIX_CALLBACK_RESULT_RT) {
    error("Failed to open vix_callback_result_resource);
    return 1;
  }

  return 0;
}
