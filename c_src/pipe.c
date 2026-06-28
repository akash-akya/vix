#include <errno.h>
#include <fcntl.h>
#include <glib-object.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "pipe.h"
#include "utils.h"

static ErlNifResourceType *FD_RT;

/* TargetPipe reads are chunked; cap one read to avoid huge NIF allocations. */
static const int MAX_READ_BUFFER_SIZE = 64 * 1024 * 1024;

typedef struct {
  int fd;
  /*
   * Dirty read/write calls, enif_select callbacks, owner-process DOWN
   * callbacks, and the resource destructor can all touch this fd. Keep them on
   * one close-once path so the numeric fd is not closed while another path is
   * using it or registering it with enif_select.
   */
  ErlNifMutex *lock;
} FdResource;

static void close_fd_value(int fd) {
  close_fd(&fd);
}

/*
 * Mark the resource closed and return the fd that was previously owned by it.
 * The caller must close the returned fd or hand it to enif_select STOP.
 */
static int fd_resource_take_fd(FdResource *fd_r) {
  int fd;

  enif_mutex_lock(fd_r->lock);
  fd = fd_r->fd;
  fd_r->fd = VIX_FD_CLOSED;
  enif_mutex_unlock(fd_r->lock);

  return fd;
}

static void fd_resource_close(FdResource *fd_r) {
  close_fd_value(fd_resource_take_fd(fd_r));
}

static ERL_NIF_TERM make_bad_fd_error(ErlNifEnv *env) {
  return make_error(env, strerror(EBADF));
}

static void close_fd_term(ErlNifEnv *env, ERL_NIF_TERM fd_term) {
  FdResource *fd_r;

  if (enif_get_resource(env, fd_term, FD_RT, (void **)&fd_r)) {
    fd_resource_close(fd_r);
  }
}

static int set_cloexec(int fd) {
  int flags = fcntl(fd, F_GETFD);
  if (flags == -1) return -1;
  return fcntl(fd, F_SETFD, flags | FD_CLOEXEC);
}

static int set_nonblock(int fd) {
  int flags = fcntl(fd, F_GETFL);
  if (flags == -1) return -1;
  return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int set_cloexec_nonblock(int fd) {
  if (set_cloexec(fd) == -1) return -1;
  return set_nonblock(fd);
}

static void close_pipes(int pipes[2]) {
  for (int i = 0; i < 2; i++) {
    close_fd(&pipes[i]);
  }
}

static VixResult fd_to_erl_term(ErlNifEnv *env, int fd) {
  ErlNifPid pid;
  FdResource *fd_r;
  int ret;
  VixResult res;

  fd_r = enif_alloc_resource(FD_RT, sizeof(FdResource));
  if (!fd_r) {
    SET_ERROR_RESULT(env, "failed to allocate fd resource", res);
    return res;
  }

  fd_r->fd = fd;
  fd_r->lock = enif_mutex_create("vix_fd_resource_lock");
  if (!fd_r->lock) {
    SET_ERROR_RESULT(env, "failed to create fd resource lock", res);
    goto exit;
  }

  if (!enif_self(env, &pid)) {
    SET_ERROR_RESULT(env, "failed get self pid", res);
    goto exit;
  }

  ret = enif_monitor_process(env, fd_r, &pid, NULL);

  if (ret < 0) {
    SET_ERROR_RESULT(env, "no down callback is provided", res);
  } else if (ret > 0) {
    SET_ERROR_RESULT(env, "pid is not alive", res);
  } else {
    res = vix_result(enif_make_resource(env, fd_r));
  }

exit:
  if (!res.is_success) {
    fd_r->fd = VIX_FD_CLOSED;
  }

  enif_release_resource(fd_r);
  return res;
}

ERL_NIF_TERM nif_source_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  ERL_NIF_TERM write_fd_term, source_term;
  VipsSource *source;
  VixResult res;
  int fds[] = {-1, -1};

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (pipe(fds) == -1) {
    ret = make_error(env, "failed to create pipes");
    goto exit;
  }

  if (set_cloexec(fds[0]) < 0 ||
      set_cloexec_nonblock(fds[1]) < 0) {
    ret = make_error(env, "failed to set flags to fd");
    goto close_fd_exit;
  }

  res = fd_to_erl_term(env, fds[1]);
  if (!res.is_success) {
    ret = make_error_term(env, res.result);
    goto close_fd_exit;
  }

  write_fd_term = res.result;
  fds[1] = VIX_FD_CLOSED;

  source = vips_source_new_from_descriptor(fds[0]);
  if (!source) {
    error("Failed to create image from fd. error: %s", vips_error_buffer());
    vips_error_clear();
    close_fd_term(env, write_fd_term);
    ret = make_error(env, "Failed to create VipsSource from fd ");
    goto close_fd_exit;
  }

  // must close read end of the pipe.
  // vips_source_new_from_descriptor calls `dup()`
  close_fd(&fds[0]);

  source_term = g_object_to_erl_term(env, (GObject *)source);
  ret = make_ok(env, enif_make_tuple2(env, write_fd_term, source_term));

  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_target_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  ErlNifTime start;
  VipsTarget *target;
  ERL_NIF_TERM ret, read_fd_term, target_term;
  VixResult res;
  int fds[] = {-1, -1};

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (pipe(fds) == -1) {
    ret = make_error(env, "failed to create pipes");
    goto exit;
  }

  if (set_cloexec_nonblock(fds[0]) < 0 ||
      set_cloexec(fds[1]) < 0) {
    ret = make_error(env, "failed to set flags to fd");
    goto close_fd_exit;
  }

  res = fd_to_erl_term(env, fds[0]);
  if (!res.is_success) {
    ret = make_error_term(env, res.result);
    goto close_fd_exit;
  }

  read_fd_term = res.result;
  fds[0] = VIX_FD_CLOSED;

  target = vips_target_new_to_descriptor(fds[1]);
  if (!target) {
    error("Failed to create VipsTarget. error: %s", vips_error_buffer());
    vips_error_clear();
    close_fd_term(env, read_fd_term);
    ret = make_error(env, "Failed to create VipsTarget");
    goto close_fd_exit;
  }

  // must close write end of the pipe.
  // vips_target_new_to_descriptor calls `dup()`
  close_fd(&fds[1]);

  target_term = g_object_to_erl_term(env, (GObject *)target);
  ret = make_ok(env, enif_make_tuple2(env, read_fd_term, target_term));

  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_pipe_open(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ERL_NIF_TERM ret;
  int fds[] = {-1, -1};
  ERL_NIF_TERM read_fd_term, write_fd_term;
  char mode[10] = {0};
  VixResult res;

  if (enif_get_atom(env, argv[0], mode, 9, ERL_NIF_LATIN1) < 1) {
    ret = make_error(env, "failed to get mode");
    goto exit;
  }

  if (pipe(fds) == -1) {
    ret = make_error(env, "failed to create pipes");
    goto exit;
  }

  if (strcmp(mode, "read") == 0) {
    if (set_cloexec_nonblock(fds[0]) < 0 ||
        set_cloexec(fds[1]) < 0) {
      ret = make_error(env, "failed to set flags to fd");
      goto close_fd_exit;
    }

    res = fd_to_erl_term(env, fds[0]);

    if (!res.is_success) {
      ret = make_error_term(env, res.result);
      goto close_fd_exit;
    }

    read_fd_term = res.result;
    fds[0] = VIX_FD_CLOSED;
    write_fd_term = enif_make_int(env, fds[1]);

  } else {
    if (set_cloexec(fds[0]) < 0 ||
        set_cloexec_nonblock(fds[1]) < 0) {
      ret = make_error(env, "failed to set flags to fd");
      goto close_fd_exit;
    }

    res = fd_to_erl_term(env, fds[1]);

    if (!res.is_success) {
      ret = make_error_term(env, res.result);
      goto close_fd_exit;
    }

    write_fd_term = res.result;
    fds[1] = VIX_FD_CLOSED;
    read_fd_term = enif_make_int(env, fds[0]);
  }

  ret = make_ok(env, enif_make_tuple2(env, read_fd_term, write_fd_term));
  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  return ret;
}

static bool select_write(ErlNifEnv *env, FdResource *fd_r, int fd) {
  int ret;

  ret = enif_select(env, (ErlNifEvent)fd, ERL_NIF_SELECT_WRITE, fd_r, NULL,
                    ATOM_UNDEFINED);

  if (ret != 0) {
    error("failed to enif_select write, %d", ret);
    return false;
  }

  return true;
}

ERL_NIF_TERM nif_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  ErlNifTime start;
  int fd;
  ssize_t size;
  ErlNifBinary bin;
  int write_errno;
  bool select_ok = false;
  FdResource *fd_r;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_resource(env, argv[0], FD_RT, (void **)&fd_r)) {
    ret = make_error(env, "failed to get fd");
    goto exit;
  }

  if (enif_inspect_binary(env, argv[1], &bin) != true) {
    ret = make_error(env, "failed to get binary");
    goto exit;
  }

  if (bin.size == 0) {
    ret = make_error(env, "failed to get binary");
    goto exit;
  }

  /*
   * This fd is nonblocking. The lock is here to keep close/STOP from racing
   * with the numeric fd while write() and any following select registration use
   * it.
   */
  enif_mutex_lock(fd_r->lock);
  fd = fd_r->fd;
  if (fd == VIX_FD_CLOSED) {
    enif_mutex_unlock(fd_r->lock);
    ret = make_bad_fd_error(env);
    goto exit;
  }

  size = write(fd, bin.data, bin.size);
  write_errno = errno;

  if ((size >= 0 && size < (ssize_t)bin.size) ||
      (size < 0 && (write_errno == EAGAIN || write_errno == EWOULDBLOCK))) {
    select_ok = select_write(env, fd_r, fd);
  }
  enif_mutex_unlock(fd_r->lock);

  if (size >= (ssize_t)bin.size) { // request completely satisfied
    ret = make_ok(env, enif_make_int(env, size));
  } else if (size >= 0) { // request partially satisfied
    if (select_ok) {
      ret = make_ok(env, enif_make_int(env, size));
    } else {
      ret = make_error(env, "failed to enif_select write");
    }
  } else if (write_errno == EAGAIN || write_errno == EWOULDBLOCK) { // busy
    if (select_ok) {
      ret = make_error_term(env, ATOM_EAGAIN);
    } else {
      ret = make_error(env, "failed to enif_select write");
    }
  } else if (write_errno == EBADF) {
    ret = make_bad_fd_error(env);
  } else {
    ret = make_error(env, strerror(write_errno));
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

static bool select_read(ErlNifEnv *env, FdResource *fd_r, int fd) {
  int ret;

  ret = enif_select(env, (ErlNifEvent)fd, ERL_NIF_SELECT_READ, fd_r, NULL,
                    ATOM_UNDEFINED);

  if (ret != 0) {
    error("failed to enif_select, %d", ret);
    return false;
  }

  return true;
}

ERL_NIF_TERM nif_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  ErlNifTime start;
  int fd;
  int max_size;
  FdResource *fd_r;
  ssize_t result;
  int read_errno;
  bool select_ok = false;
  ERL_NIF_TERM bin_term = 0;
  ERL_NIF_TERM ret;
  ErlNifBinary read_bin = {0};

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_resource(env, argv[0], FD_RT, (void **)&fd_r)) {
    ret = make_error(env, "failed to get fd");
    goto exit;
  }

  if (!enif_get_int(env, argv[1], &max_size)) {
    ret = make_error(env, "failed to get read max_size");
    goto exit;
  }

  if (max_size < 1) {
    ret = make_error(env, "max_size must be >= 1");
    goto exit;
  }

  if (max_size > MAX_READ_BUFFER_SIZE) {
    ret = make_error(env, "max_size must be <= 64 MiB");
    goto exit;
  }

  if (!enif_alloc_binary((size_t)max_size, &read_bin)) {
    ret = make_error(env, "failed to allocate read buffer");
    goto exit;
  }

  /*
   * This fd is nonblocking. The lock is here to keep close/STOP from racing
   * with the numeric fd while read() and any following select registration use
   * it.
   */
  enif_mutex_lock(fd_r->lock);
  fd = fd_r->fd;
  if (fd == VIX_FD_CLOSED) {
    enif_mutex_unlock(fd_r->lock);
    ret = make_bad_fd_error(env);
    goto exit;
  }

  result = read(fd, read_bin.data, read_bin.size);
  read_errno = errno;

  if (result < 0 && (read_errno == EAGAIN || read_errno == EWOULDBLOCK)) {
    select_ok = select_read(env, fd_r, fd);
  }
  enif_mutex_unlock(fd_r->lock);

  if (result >= 0) {
    size_t bytes_read = (size_t)result;

    if (bytes_read == 0) {
      enif_release_binary(&read_bin);
      read_bin.data = NULL;
      enif_make_new_binary(env, 0, &bin_term);
    } else {
      if (bytes_read < read_bin.size &&
          !enif_realloc_binary(&read_bin, bytes_read)) {
        ret = make_error(env, "failed to resize read buffer");
        goto exit;
      }

      bin_term = enif_make_binary(env, &read_bin);
      read_bin.data = NULL;
    }

    ret = make_ok(env, bin_term);
  } else if (read_errno == EAGAIN || read_errno == EWOULDBLOCK) { // busy
    if (select_ok) {
      ret = make_error_term(env, ATOM_EAGAIN);
    } else {
      ret = make_error(env, "failed to enif_select read");
    }
  } else if (read_errno == EBADF) {
    ret = make_bad_fd_error(env);
  } else {
    ret = make_error(env, strerror(read_errno));
  }

exit:
  if (read_bin.data) {
    enif_release_binary(&read_bin);
  }
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

static void fd_resource_stop_select_or_close(ErlNifEnv *env,
                                             FdResource *fd_r) {
  int fd;
  int ret;

  fd = fd_resource_take_fd(fd_r);

  if (fd == VIX_FD_CLOSED) {
    return;
  }

  ret = enif_select(env, (ErlNifEvent)fd, ERL_NIF_SELECT_STOP, fd_r, NULL,
                    ATOM_UNDEFINED);

  if (ret < 0) {
    error("failed to enif_select stop, %d", ret);
    close_fd_value(fd);
    return;
  }

  /*
   * When STOP is called or scheduled, the stop callback owns the close. If
   * there was no active select to stop, close the resource here.
   */
  if ((ret & ERL_NIF_SELECT_STOP_CALLED) != 0 ||
      (ret & ERL_NIF_SELECT_STOP_SCHEDULED) != 0) {
    return;
  }

  close_fd_value(fd);
}

static void fd_rt_dtor(ErlNifEnv *env, void *obj) {
  debug("fd_rt_dtor called");
  FdResource *fd_r = (FdResource *)obj;
  if (fd_r->lock) {
    fd_resource_close(fd_r);
    enif_mutex_destroy(fd_r->lock);
    fd_r->lock = NULL;
  } else {
    close_fd(&fd_r->fd);
  }
}

static void fd_rt_stop(ErlNifEnv *env, void *obj, int fd, int is_direct_call) {
  debug("fd_rt_stop called %d", fd);

  /*
   * The resource has already been marked closed before STOP is requested. The
   * callback owns the selected event value and only needs to close that value.
   */
  close_fd_value(fd);
}

static void fd_rt_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                       ErlNifMonitor *monitor) {
  debug("fd_rt_down called");
  FdResource *fd_r = (FdResource *)obj;
  fd_resource_stop_select_or_close(env, fd_r);
}

int nif_pipe_init(ErlNifEnv *env) {
  ErlNifResourceTypeInit fd_rt_init;

  fd_rt_init.dtor = fd_rt_dtor;
  fd_rt_init.stop = fd_rt_stop;
  fd_rt_init.down = fd_rt_down;

  FD_RT =
      enif_open_resource_type_x(env, "fd resource", &fd_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  return 0;
}
