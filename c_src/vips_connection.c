#include <glib-object.h>
#include <unistd.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "utils.h"
#include "vips_connection.h"

const int STATUS_PENDING = 0;
const int STATUS_DONE = 1;

static ERL_NIF_TERM build_read_message(ErlNifEnv *env, gint64 length,
                                       VixCallbackResource *cb) {
  return enif_make_tuple3(env, make_atom(env, "read"),
                          enif_make_int64(env, length),
                          enif_make_resource(env, cb));
}

static gint64 read_data(VipsSourceCustom *source, void *buffer, gint64 length,
                        void *user) {
  ErlNifEnv *env;
  VixCallbackResource *cb;
  gint64 read = 0;

  env = enif_alloc_env();
  cb = (VixCallbackResource *)user;

  enif_mutex_lock(cb->lock);

  cb->status = STATUS_PENDING;
  cb->result = buffer;
  cb->size = 0;

  if (!enif_send(NULL, &cb->pid, env, build_read_message(env, length, cb))) {
    error("failed to send :read message");
    goto exit;
  }

  while (cb->status == STATUS_PENDING)
    enif_cond_wait(cb->cond, cb->lock);

  read = cb->size;

exit:
  enif_mutex_unlock(cb->lock);
  enif_free_env(env);

  return read;
}

// We dont support seek for any source
static gint64 seek_data(VipsSourceCustom *source, gint64 pos, int whence,
                        void *user) {
  return -1;
}

static void close_data(VipsObject *obj, void *user) {
  VixCallbackResource *cb = (VixCallbackResource *)user;
  ErlNifEnv *env;

  env = enif_alloc_env();
  enif_send(NULL, &cb->pid, env, make_atom(env, "close"));
  enif_free_env(env);

  enif_release_resource(cb);
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

static void cancel_pending_callback(VixCallbackResource *cb) {
  enif_mutex_lock(cb->lock);

  cb->size = 0;
  cb->status = STATUS_DONE;

  enif_cond_signal(cb->cond);
  enif_mutex_unlock(cb->lock);
}

/*
  VipsConnection requires blocking c callbacks to implemented. If we want to
  hook it up with elixir streams, we need a way to synchronously call elixir
  function from c function.

     void func() {
       ...
       result = call_elixir_function();
       ...
       return result;
     }

  We try to acheive this using the combination of mutex, conditional-variables
  and process-message:
   - have a designated beam-process tied to the vips-connection
   - lock the mutex and send a message from vips thread with a c-pointer as
  resource, wait for beam-process to handle and write result
   - upon receiving message, beam-process calls the callback and writes the
  result using a nif call
   - caller thread gets notified and returns the result
*/
ERL_NIF_TERM nif_vips_source_new(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  VipsSourceCustom *source;
  VixCallbackResource *cb;

  cb = enif_alloc_resource(VIX_CALLBACK_RT, sizeof(VixCallbackResource));

  if (!enif_get_local_pid(env, argv[0], &cb->pid)) {
    return make_error(env, "failed to get pid");
  }

  cb->lock = enif_mutex_create("vix:vips_source_mutex");
  cb->cond = enif_cond_create("vix:vips_source_cond");

  if (enif_monitor_process(env, cb, &cb->pid, NULL) != 0)
    return make_error(env, "failed to set monitor");

  source = vips_source_custom_new();

  g_signal_connect(source, "read", G_CALLBACK(read_data), cb);
  g_signal_connect(source, "seek", G_CALLBACK(seek_data), cb);
  g_signal_connect(source, "close", G_CALLBACK(close_data), cb);

  return make_ok(env, g_object_to_erl_term(env, (GObject *)source));
}

static void vix_callback_dtor(ErlNifEnv *env, void *obj) {
  VixCallbackResource *cb = (VixCallbackResource *)obj;

  enif_cond_destroy(cb->cond);
  enif_mutex_destroy(cb->lock);

  debug("VixCallbackResource dtor");
}

static void vix_callback_stop(ErlNifEnv *env, void *obj, int fd,
                              int is_direct_call) {
  debug("Exile vix_callback_stop called");
}

static void vix_callback_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                              ErlNifMonitor *monitor) {
  VixCallbackResource *cb = (VixCallbackResource *)obj;
  cancel_pending_callback(cb);
  debug("Exile vix_callback_down called");
}

static ErlNifResourceTypeInit vix_callback_rt_init = {
    vix_callback_dtor, vix_callback_stop, vix_callback_down};

int nif_vips_connection_init(ErlNifEnv *env) {
  VIX_CALLBACK_RT = enif_open_resource_type_x(
      env, "vix_callback_resource", &vix_callback_rt_init,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!VIX_CALLBACK_RT) {
    error("Failed to open vix_callback_resource");
    return 1;
  }

  return 0;
}
