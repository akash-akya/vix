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

ERL_NIF_TERM nif_foreign_find_load_source(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  VipsSource *source;
  const char *name;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&source)) {
    ret = make_error(env, "Failed to get VipsSource");
    goto exit;
  }

  name = vips_foreign_find_load_source(source);

  if (!name) {
    error("Failed to find the loader for the source. error: %s",
          vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to find loader for the source");
    goto exit;
  }

  ret = make_ok(env, make_binary(env, name));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_foreign_find_save_target(ErlNifEnv *env, int argc,
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

  name = vips_foreign_find_save_target(suffix);

  if (!name) {
    error("Failed to find saver for the target. error: %s",
          vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to find saver for the target");
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

/**
 *
 * Based on
 * https://github.com/libvips/libvips/blob/19eba89148695a2780f49b43bc70c426f21fdec1/libvips/foreign/foreign.c#L2056
 *
 */
static void *
vips_foreign_get_loader_suffixes_count_cb(VipsForeignLoadClass *load_class,
                                          void *a, void *b) {
  VipsForeignClass *foreign_class = VIPS_FOREIGN_CLASS(load_class);
  int *n_fields = (int *)a;

  int i;

  if (foreign_class->suffs)
    for (i = 0; foreign_class->suffs[i]; i++)
      *n_fields += 1;

  return (NULL);
}

static void *
vips_foreign_get_loader_suffixes_add_cb(VipsForeignLoadClass *load_class,
                                        void *a, void *b) {
  VipsForeignClass *foreign_class = VIPS_FOREIGN_CLASS(load_class);
  gchar ***p = (gchar ***)a;

  int i;

  if (foreign_class->suffs)
    for (i = 0; foreign_class->suffs[i]; i++) {
      **p = g_strdup(foreign_class->suffs[i]);
      *p += 1;
    }

  return (NULL);
}

/**
 * vips_foreign_get_loader_suffixes: (method)
 *
 * Get a %NULL-terminated array listing all the supported loader suffixes.
 *
 * Free the return result with g_strfreev().
 *
 * Returns: (transfer full): all supported file extensions, as a
 * %NULL-terminated array.
 */
static gchar **vips_foreign_get_loader_suffixes(void) {
  int n_suffs;
  gchar **suffs;
  gchar **p;

  n_suffs = 0;
  (void)vips_foreign_map(
      "VipsForeignLoad",
      (VipsSListMap2Fn)vips_foreign_get_loader_suffixes_count_cb, &n_suffs,
      NULL);

  suffs = g_new0(gchar *, n_suffs + 1);
  p = suffs;
  (void)vips_foreign_map(
      "VipsForeignLoad",
      (VipsSListMap2Fn)vips_foreign_get_loader_suffixes_add_cb, &p, NULL);

  return (suffs);
}

ERL_NIF_TERM nif_foreign_get_loader_suffixes(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  gchar **loader_suffixes;
  ERL_NIF_TERM list;
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;

  start = enif_monotonic_time(ERL_NIF_USEC);

  loader_suffixes = vips_foreign_get_loader_suffixes();

  if (!loader_suffixes) {
    error("Failed to fetch loader suffixes. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to fetch loader_suffixes");
    goto exit;
  }

  list = enif_make_list(env, 0);
  for (int i = 0; loader_suffixes[i] != NULL; i++) {
    length = strlen(loader_suffixes[i]);
    temp = enif_make_new_binary(env, length, &bin);
    memcpy(temp, loader_suffixes[i], length);

    list = enif_make_list_cell(env, bin, list);
  }
  g_strfreev(loader_suffixes);

  ret = make_ok(env, list);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}
