#include <glib-object.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "g_object/g_value.h"
#include "utils.h"
#include "vips_foreign.h"

ERL_NIF_TERM nif_foreign_find_load_buffer(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  ErlNifBinary bin;
  const char *name;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_inspect_binary(env, argv[0], &bin)) {
    error("failed to get binary from erl term");
    ret = enif_make_badarg(env);
    goto exit;
  }

  name = vips_foreign_find_load_buffer(bin.data, bin.size);

  if (!name) {
    error("Failed to find load buffer. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to find load buffer");
    goto exit;
  }

  ret = make_ok(env, make_binary(env, name));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_foreign_find_save_buffer(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  char suffix[VIPS_PATH_MAX];
  const char *name;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!get_binary(env, argv[0], suffix, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get suffix");
    goto exit;
  }

  name = vips_foreign_find_save_buffer(suffix);

  if (!name) {
    error("Failed to find save buffer. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to find save buffer");
    goto exit;
  }

  ret = make_ok(env, make_binary(env, name));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_foreign_find_load(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  char filename[VIPS_PATH_MAX];
  const char *name;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!get_binary(env, argv[0], filename, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get filename");
    goto exit;
  }

  name = vips_foreign_find_load(filename);

  if (!name) {
    error("Failed to find load. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to find load");
    goto exit;
  }

  ret = make_ok(env, make_binary(env, name));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_foreign_find_save(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  char filename[VIPS_PATH_MAX];
  const char *name;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!get_binary(env, argv[0], filename, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get filename");
    goto exit;
  }

  name = vips_foreign_find_save(filename);

  if (!name) {
    error("Failed to find save. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to find save");
    goto exit;
  }

  ret = make_ok(env, make_binary(env, name));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_foreign_get_suffixes(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  gchar **suffixes;
  ERL_NIF_TERM list;
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;

  start = enif_monotonic_time(ERL_NIF_USEC);

  suffixes = vips_foreign_get_suffixes();

  if (!suffixes) {
    error("Failed to fetch suffixes. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to fetch suffixes");
    goto exit;
  }

  list = enif_make_list(env, 0);
  for (int i = 0; suffixes[i] != NULL; i++) {
    length = strlen(suffixes[i]);
    temp = enif_make_new_binary(env, length, &bin);
    memcpy(temp, suffixes[i], length);

    list = enif_make_list_cell(env, bin, list);
  }
  g_strfreev(suffixes);

  ret = make_ok(env, list);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}
