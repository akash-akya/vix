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

static int set_flag(int fd, int flags) {
  return fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | flags);
}

static void close_pipes(int pipes[2]) {
  for (int i = 0; i < 2; i++) {
    close(pipes[i]);
  }
}

static VixResult fd_to_erl_term(ErlNifEnv *env, int fd) {
  ErlNifPid pid;
  int *fd_r;
  int ret;
  VixResult res;

  fd_r = enif_alloc_resource(FD_RT, sizeof(int));
  *fd_r = fd;

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

  if (set_flag(fds[0], O_CLOEXEC) < 0 ||
      set_flag(fds[1], O_CLOEXEC | O_NONBLOCK) < 0) {
    ret = make_error(env, "failed to set flags to fd");
    goto close_fd_exit;
  }

  res = fd_to_erl_term(env, fds[1]);
  if (!res.is_success) {
    ret = make_error_term(env, res.result);
    goto close_fd_exit;
  }

  write_fd_term = res.result;

  source = vips_source_new_from_descriptor(fds[0]);
  if (!source) {
    error("Failed to create image from fd. error: %s", vips_error_buffer());
    vips_error_clear();
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

  if (set_flag(fds[0], O_CLOEXEC | O_NONBLOCK) < 0 ||
      set_flag(fds[1], O_CLOEXEC) < 0) {
    ret = make_error(env, "failed to set flags to fd");
    goto close_fd_exit;
  }

  res = fd_to_erl_term(env, fds[0]);
  if (!res.is_success) {
    ret = make_error_term(env, res.result);
    goto close_fd_exit;
  }

  read_fd_term = res.result;

  target = vips_target_new_to_descriptor(fds[1]);
  if (!target) {
    error("Failed to create VipsTarget. error: %s", vips_error_buffer());
    vips_error_clear();
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
    if (set_flag(fds[0], O_CLOEXEC | O_NONBLOCK) < 0 ||
        set_flag(fds[1], O_CLOEXEC) < 0) {
      ret = make_error(env, "failed to set flags to fd");
      goto close_fd_exit;
    }

    res = fd_to_erl_term(env, fds[0]);

    if (!res.is_success) {
      ret = make_error_term(env, res.result);
      goto close_fd_exit;
    }

    read_fd_term = res.result;
    write_fd_term = enif_make_int(env, fds[1]);

  } else {

    if (set_flag(fds[0], O_CLOEXEC) < 0 ||
        set_flag(fds[1], O_CLOEXEC | O_NONBLOCK) < 0) {
      ret = make_error(env, "failed to set flags to fd");
      goto close_fd_exit;
    }

    res = fd_to_erl_term(env, fds[1]);

    if (!res.is_success) {
      ret = make_error_term(env, res.result);
      goto close_fd_exit;
    }

    write_fd_term = res.result;
    read_fd_term = enif_make_int(env, fds[0]);
  }

  ret = make_ok(env, enif_make_tuple2(env, read_fd_term, write_fd_term));
  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  return ret;
}

static bool select_write(ErlNifEnv *env, int *fd) {
  int ret;

  ret = enif_select(env, *fd, ERL_NIF_SELECT_WRITE, fd, NULL, ATOM_UNDEFINED);

  if (ret != 0) {
    error("failed to enif_select write, %d", ret);
    return false;
  }

  return true;
}

ERL_NIF_TERM nif_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  ErlNifTime start;
  ssize_t size;
  ErlNifBinary bin;
  int write_errno;
  int *fd;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_resource(env, argv[0], FD_RT, (void **)&fd)) {
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

  size = write(*fd, bin.data, bin.size);
  write_errno = errno;

  if (size >= (ssize_t)bin.size) { // request completely satisfied
    ret = make_ok(env, enif_make_int(env, size));
  } else if (size >= 0) { // request partially satisfied
    if (select_write(env, fd)) {
      ret = make_ok(env, enif_make_int(env, size));
    } else {
      ret = make_error(env, "failed to enif_select write");
    }
  } else if (write_errno == EAGAIN || write_errno == EWOULDBLOCK) { // busy
    if (select_write(env, fd)) {
      ret = make_error_term(env, ATOM_EAGAIN);
    } else {
      ret = make_error(env, "failed to enif_select write");
    }
  } else {
    ret = make_error(env, strerror(write_errno));
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

static bool select_read(ErlNifEnv *env, int *fd) {
  int ret;

  ret = enif_select(env, *fd, ERL_NIF_SELECT_READ, fd, NULL, ATOM_UNDEFINED);

  if (ret != 0) {
    error("failed to enif_select, %d", ret);
    return false;
  }

  return true;
}

ERL_NIF_TERM nif_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  ErlNifTime start;
  int max_size;
  int *fd;
  ssize_t result;
  int read_errno;
  ERL_NIF_TERM bin_term = 0;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_resource(env, argv[0], FD_RT, (void **)&fd)) {
    ret = make_error(env, "failed to get fd");
    goto exit;
  }

  if (!enif_get_int(env, argv[1], &max_size)) {
    ret = make_error(env, "failed to get read max_size");
    goto exit;
  }

  if (max_size < 1) {
    ret = make_error(env, "max_size must be >= 0");
    goto exit;
  }

  {
    unsigned char buf[max_size];

    result = read(*fd, buf, max_size);
    read_errno = errno;

    if (result >= 0) {
      /* no need to release this binary */
      unsigned char *temp = enif_make_new_binary(env, result, &bin_term);
      memcpy(temp, buf, result);
      ret = make_ok(env, bin_term);
    } else if (read_errno == EAGAIN || read_errno == EWOULDBLOCK) { // busy
      if (select_read(env, fd)) {
        ret = make_error_term(env, ATOM_EAGAIN);
      } else {
        ret = make_error(env, "failed to enif_select read");
      }
    } else {
      ret = make_error(env, strerror(read_errno));
    }
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

static bool cancel_select(ErlNifEnv *env, int *fd) {
  int ret;

  if (*fd != VIX_FD_CLOSED) {
    ret = enif_select(env, *fd, ERL_NIF_SELECT_STOP, fd, NULL, ATOM_UNDEFINED);

    if (ret < 0) {
      error("failed to enif_select stop, %d", ret);
      return false;
    }

    return true;
  }

  return true;
}

static void fd_rt_dtor(ErlNifEnv *env, void *obj) {
  debug("fd_rt_dtor called");
  int *fd = (int *)obj;
  close_fd(fd);
}

static void fd_rt_stop(ErlNifEnv *env, void *obj, int fd, int is_direct_call) {
  debug("fd_rt_stop called %d", fd);
}

static void fd_rt_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                       ErlNifMonitor *monitor) {
  debug("fd_rt_down called");
  int *fd = (int *)obj;
  cancel_select(env, fd);
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
