#include <glib-object.h>
#include <string.h>
#include <vips/vips.h>

#include "async.h"
#include "g_object/g_object.h"
#include "pipe.h"
#include "utils.h"

/*
 * Streams a save to an Elixir process (the owner).
 *
 * The save writes to a VipsTargetCustom backed by a bounded buffer and waits
 * while it is full. The owner never waits: it gets `{:error, :eagain}` and
 * then a `:vix_pipe_ready` message.
 */

typedef struct {
  GMutex lock;
  GCond cond;
  GByteArray *buffer;
  ErlNifPid owner;
  bool owner_waiting;
  bool writer_closed;
  bool reader_closed;
} VixPipe;

static ErlNifResourceType *PIPE_RT;

static ERL_NIF_TERM ATOM_VIX_PIPE_READY;

#define PIPE_CAPACITY (64 * 1024)

/* Call with the lock held */
static bool take_owner_waiting(VixPipe *pipe) {
  bool waiting = pipe->owner_waiting;
  pipe->owner_waiting = false;
  return waiting;
}

static void notify_owner(VixPipe *pipe) {
  ErlNifEnv *env = enif_alloc_env();
  enif_send(NULL, &pipe->owner, env, ATOM_VIX_PIPE_READY);
  enif_free_env(env);
}

static void close_pipe(VixPipe *pipe, bool writer) {
  bool notify;

  g_mutex_lock(&pipe->lock);
  if (writer) {
    pipe->writer_closed = true;
  } else {
    pipe->reader_closed = true;
  }
  g_cond_broadcast(&pipe->cond);
  // the reader closes only by exiting, so there is nobody to notify then
  notify = take_owner_waiting(pipe) && writer;
  g_mutex_unlock(&pipe->lock);

  if (notify)
    notify_owner(pipe);
}

static gint64 target_write(VipsTargetCustom *target, const void *data,
                           gint64 length, VixPipe *pipe) {
  guint size;
  bool notify;

  g_mutex_lock(&pipe->lock);
  while (pipe->buffer->len >= PIPE_CAPACITY && !pipe->reader_closed)
    vix_async_wait(&pipe->cond, &pipe->lock);

  if (pipe->reader_closed) {
    g_mutex_unlock(&pipe->lock);
    return -1;
  }

  // libvips writes the rest in later calls
  size = (guint)MIN(length, (gint64)(PIPE_CAPACITY - pipe->buffer->len));
  g_byte_array_append(pipe->buffer, data, size);
  notify = take_owner_waiting(pipe);
  g_mutex_unlock(&pipe->lock);

  if (notify)
    notify_owner(pipe);

  return size;
}

#if (VIPS_MAJOR_VERSION < 8) ||                                                \
    (VIPS_MAJOR_VERSION == 8 && VIPS_MINOR_VERSION < 13)
static void target_finish(VipsTargetCustom *target, VixPipe *pipe) {
  close_pipe(pipe, true);
}
#else
static int target_end(VipsTargetCustom *target, VixPipe *pipe) {
  close_pipe(pipe, true);
  return 0;
}
#endif

static void target_destroyed(VixPipe *pipe) {
  close_pipe(pipe, true);
  enif_release_resource(pipe);
}

ERL_NIF_TERM nif_target_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  VipsTargetCustom *target;
  VixPipe *pipe;
  ERL_NIF_TERM target_term, pipe_term;

  target = vips_target_custom_new();
  // owns the target, so it is unreffed on error too
  target_term = g_object_to_erl_term(env, (GObject *)target);

  pipe = enif_alloc_resource(PIPE_RT, sizeof(VixPipe));
  g_mutex_init(&pipe->lock);
  g_cond_init(&pipe->cond);
  pipe->buffer = g_byte_array_new();
  pipe->owner_waiting = false;
  pipe->writer_closed = false;
  pipe->reader_closed = false;

  pipe_term = enif_make_resource(env, pipe);
  enif_release_resource(pipe);

  // stop the save if the owner exits
  if (!enif_self(env, &pipe->owner) ||
      enif_monitor_process(env, pipe, &pipe->owner, NULL) != 0) {
    return make_error(env, "Failed to monitor the owner");
  }

  // the target holds a reference until it is freed
  enif_keep_resource(pipe);
  g_object_set_data_full(G_OBJECT(target), "vix-pipe", pipe,
                         (GDestroyNotify)target_destroyed);

  g_signal_connect(target, "write", G_CALLBACK(target_write), pipe);
#if (VIPS_MAJOR_VERSION < 8) ||                                                \
    (VIPS_MAJOR_VERSION == 8 && VIPS_MINOR_VERSION < 13)
  g_signal_connect(target, "finish", G_CALLBACK(target_finish), pipe);
#else
  g_signal_connect(target, "end", G_CALLBACK(target_end), pipe);
#endif

  return make_ok(env, enif_make_tuple2(env, pipe_term, target_term));
}

ERL_NIF_TERM nif_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VixPipe *pipe;
  int max_size;
  guint size;
  ERL_NIF_TERM bin, ret;

  if (!enif_get_resource(env, argv[0], PIPE_RT, (void **)&pipe))
    return make_error(env, "failed to get pipe");

  if (!enif_get_int(env, argv[1], &max_size) || max_size < 1)
    return make_error(env, "max_size must be >= 1");

  g_mutex_lock(&pipe->lock);
  if (pipe->buffer->len > 0) {
    size = MIN(pipe->buffer->len, (guint)max_size);
    memcpy(enif_make_new_binary(env, size, &bin), pipe->buffer->data, size);
    g_byte_array_remove_range(pipe->buffer, 0, size);
    g_cond_broadcast(&pipe->cond);
    ret = make_ok(env, bin);
  } else if (pipe->writer_closed) {
    enif_make_new_binary(env, 0, &bin);
    ret = make_ok(env, bin); // EOF
  } else {
    pipe->owner_waiting = true;
    ret = make_error_term(env, ATOM_EAGAIN);
  }
  g_mutex_unlock(&pipe->lock);

  return ret;
}

static void pipe_rt_dtor(ErlNifEnv *env, void *obj) {
  VixPipe *pipe = (VixPipe *)obj;

  g_byte_array_unref(pipe->buffer);
  g_cond_clear(&pipe->cond);
  g_mutex_clear(&pipe->lock);
}

static void pipe_rt_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                         ErlNifMonitor *monitor) {
  close_pipe((VixPipe *)obj, false);
}

int nif_pipe_init(ErlNifEnv *env) {
  ErlNifResourceTypeInit pipe_rt_init = {0};

  pipe_rt_init.dtor = pipe_rt_dtor;
  pipe_rt_init.down = pipe_rt_down;
  PIPE_RT =
      enif_open_resource_type_x(env, "vix pipe", &pipe_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  ATOM_VIX_PIPE_READY = make_atom(env, "vix_pipe_ready");
  return PIPE_RT ? 0 : 1;
}
