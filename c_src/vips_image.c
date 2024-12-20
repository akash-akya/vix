#include <glib-object.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "g_object/g_value.h"
#include "utils.h"
#include "vips_image.h"

const int MAX_HEADER_NAME_LENGTH = 100;

static ERL_NIF_TERM vips_image_header_read_error(ErlNifEnv *env,
                                                 const char *name,
                                                 const char *type) {
  error("Failed to read image metadata %s of type %s. error: %s", name, type,
        vips_error_buffer());
  vips_error_clear();
  return make_error(env, "Failed to read image metadata");
}

static void free_erl_env(VipsImage *image, ErlNifEnv *env) {
  (void)image;
  debug("Free ErlNifEnv");
  enif_free_env(env);
  return;
}

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  char src[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!get_binary(env, argv[0], src, VIPS_PATH_MAX)) {
    ret = raise_badarg(env, "Failed to get file name");
    goto exit;
  }

  image = vips_image_new_from_file(src, NULL);

  if (!image) {
    error("Failed to read image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to read image");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_from_image(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VipsImage *image;
  VipsImage *copy;
  ErlNifTime start;
  ERL_NIF_TERM list, head;
  double *array;
  guint size;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  list = argv[1];

  if (!enif_get_list_length(env, list, &size)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  array = g_new(double, size);

  for (guint i = 0; i < size; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      ret = make_error(env, "Failed to get list entry");
      goto free_and_exit;
    }

    if (!enif_get_double(env, head, &array[i])) {
      ret = make_error(env, "Failed to get double");
      goto free_and_exit;
    }
  }

  copy = vips_image_new_from_image(image, array, size);

  if (!copy) {
    error("Failed to create new image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to create new image");
    goto free_and_exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)copy));

free_and_exit:
  g_free(array);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_copy_memory(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsImage *image;
  VipsImage *copy;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  copy = vips_image_copy_memory(image);

  if (!copy) {
    error("Failed to memory copy image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to memory copy image");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)copy));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  char dst[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], dst, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get destination path");
    goto exit;
  }

  if (vips_image_write_to_file(image, dst, NULL)) {
    error("Failed to write VipsImage to file. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write VipsImage to file");
    goto exit;
  }

  ret = ATOM_OK;

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_write_to_buffer(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  char suffix[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;
  ERL_NIF_TERM bin_term;
  void *temp;
  void *bin;
  size_t size;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], suffix, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get suffix");
    goto exit;
  }

  if (vips_image_write_to_buffer(image, suffix, &temp, &size, NULL)) {
    error("Failed to write VipsImage to buffer. error: %s",
          vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write VipsImage to buffer");
    goto exit;
  }

  bin = enif_make_new_binary(env, size, &bin_term);
  memcpy(bin, temp, size);
  g_free(temp);

  ret = make_ok(env, bin_term);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  image = vips_image_new();

  if (!image) {
    error("Failed to create VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create VipsImage");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  char format[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!get_binary(env, argv[0], format, VIPS_PATH_MAX)) {
    ret = raise_badarg(env, "Failed to get format");
    goto exit;
  }

  image = vips_image_new_temp_file(format);

  if (!image) {
    error("Failed to create VipsImage. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create VipsImage");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_matrix_from_array(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 5);

  VipsImage *image;
  int width, height;
  double scale, offset;
  double *array;
  ERL_NIF_TERM list, head, ret;
  guint size;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_int(env, argv[0], &width)) {
    error("failed to get width");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_int(env, argv[1], &height)) {
    error("failed to get height");
    ret = enif_make_badarg(env);
    goto exit;
  }

  list = argv[2];

  if (!enif_get_list_length(env, list, &size)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_double(env, argv[3], &scale)) {
    error("Failed to get scale");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_double(env, argv[4], &offset)) {
    error("Failed to get offset");
    ret = enif_make_badarg(env);
    goto exit;
  }

  array = g_new(double, size);

  for (guint i = 0; i < size; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      ret = make_error(env, "Failed to get list entry");
      goto free_and_exit;
    }

    if (!enif_get_double(env, head, &array[i])) {
      ret = make_error(env, "Failed to get double");
      goto free_and_exit;
    }
  }

  image = vips_image_new_matrix_from_array(width, height, array, size);

  if (!image) {
    error("Failed to read image. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed create matrix from array");
    goto free_and_exit;
  }

  vips_image_set_double(image, "scale", scale);

  vips_image_set_double(image, "offset", offset);

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

free_and_exit:
  g_free(array);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_get_fields(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsImage *image;
  ERL_NIF_TERM ret;
  ErlNifTime start;
  gchar **fields;
  ERL_NIF_TERM list;
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  fields = vips_image_get_fields(image);

  list = enif_make_list(env, 0);
  for (int i = 0; fields && fields[i] != NULL; i++) {
    length = strlen(fields[i]);
    temp = enif_make_new_binary(env, length, &bin);
    memcpy(temp, fields[i], length);

    list = enif_make_list_cell(env, bin, list);
  }
  g_strfreev(fields);

  ret = make_ok(env, list);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_get_header(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VipsImage *image;
  char header_name[MAX_HEADER_NAME_LENGTH];
  GType type;
  ERL_NIF_TERM ret;
  ERL_NIF_TERM type_name;
  ErlNifTime start;
  GValue gvalue = {0};
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], header_name, MAX_HEADER_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get header name");
    goto exit;
  }

  type = vips_image_get_typeof(image, header_name);

  if (type == 0) {
    ret = make_error(env, "No such field");
    goto exit;
  }

  if (vips_image_get(image, header_name, &gvalue)) {
    g_value_unset(&gvalue);
    error("Failed to get GValue. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to get GValue");
    goto exit;
  }

  res = g_value_to_erl_term(env, gvalue);

  if (res.is_success) {
    type_name = make_binary(env, g_type_name(type));
    ret = make_ok(env, enif_make_tuple2(env, type_name, res.result));
  } else {
    ret = enif_make_tuple2(env, ATOM_ERROR, res.result);
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_update_metadata(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 3);

  VipsImage *image;
  char name[MAX_HEADER_NAME_LENGTH];
  GType type;
  ERL_NIF_TERM ret;
  ErlNifTime start;
  GValue gvalue = {0};
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], name, MAX_HEADER_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get name");
    goto exit;
  }

  type = vips_image_get_typeof(image, name);

  if (type == 0) {
    ret = make_error(env, "No such field");
    goto exit;
  }

  res = erl_term_to_g_value(env, type, argv[2], &gvalue);

  if (!res.is_success) {
    ret = enif_make_tuple2(env, ATOM_ERROR, res.result);
    goto exit;
  }

  vips_image_set(image, name, &gvalue);
  g_value_unset(&gvalue);

  if (res.is_success) {
    ret = ATOM_OK;
  } else {
    ret = enif_make_tuple2(env, ATOM_ERROR, res.result);
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_set_metadata(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 4);

  VipsImage *image;
  char name[MAX_HEADER_NAME_LENGTH];
  char gtype_name[MAX_G_TYPE_NAME_LENGTH];
  GType type;
  ERL_NIF_TERM ret;
  ErlNifTime start;
  GValue gvalue = {0};
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], name, MAX_HEADER_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get header name");
    goto exit;
  }

  if (!get_binary(env, argv[2], gtype_name, MAX_G_TYPE_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get gtype name");
    goto exit;
  }

  type = g_type_from_name(gtype_name);
  if (type == 0) {
    ret = make_error(env, "GType for the given name not found");
    goto exit;
  }

  res = erl_term_to_g_value(env, type, argv[3], &gvalue);

  if (!res.is_success) {
    ret = enif_make_tuple2(env, ATOM_ERROR, res.result);
    goto exit;
  }

  vips_image_set(image, name, &gvalue);
  g_value_unset(&gvalue);

  if (res.is_success) {
    ret = ATOM_OK;
  } else {
    ret = enif_make_tuple2(env, ATOM_ERROR, res.result);
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_remove_metadata(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VipsImage *image;
  char name[MAX_HEADER_NAME_LENGTH];
  ERL_NIF_TERM ret;
  ErlNifTime start;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], name, MAX_HEADER_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get name");
    goto exit;
  }

  if (vips_image_remove(image, name)) {
    ret = ATOM_OK;
  } else {
    ret = make_error(env, "No such metadata found");
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_get_as_string(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VipsImage *image;
  ERL_NIF_TERM ret;
  ErlNifTime start;
  char header_name[MAX_HEADER_NAME_LENGTH];
  GType type;
  char *value;
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!get_binary(env, argv[1], header_name, MAX_HEADER_NAME_LENGTH)) {
    ret = make_error(env, "Failed to get header name");
    goto exit;
  }

  type = vips_image_get_typeof(image, header_name);

  if (type == 0) {
    ret = make_error(env, "No such field");
    goto exit;
  }

  if (vips_image_get_as_string(image, header_name, &value) != 0) {
    ret = vips_image_header_read_error(env, header_name, "string");
    goto exit;
  }

  length = strlen(value);
  temp = enif_make_new_binary(env, strlen(value), &bin);
  memcpy(temp, value, length);
  g_free(value);

  ret = make_ok(env, bin);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_hasalpha(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (vips_image_hasalpha(image)) {
    ret = make_ok(env, ATOM_TRUE);
  } else {
    ret = make_ok(env, ATOM_FALSE);
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_from_binary(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 5);

  VipsImage *image;
  ERL_NIF_TERM ret, bin_term;
  ErlNifTime start;
  ErlNifEnv *new_env;
  ErlNifBinary bin;
  int width, height, bands, band_format;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_is_binary(env, argv[0])) {
    error("failed to get binary from erl term");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_int(env, argv[1], &width)) {
    error("failed to get width");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_int(env, argv[2], &height)) {
    error("failed to get height");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_int(env, argv[3], &bands)) {
    error("failed to get bands");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (!enif_get_int(env, argv[4], &band_format)) {
    error("failed to get band_format");
    ret = enif_make_badarg(env);
    goto exit;
  }

  new_env = enif_alloc_env();
  bin_term = enif_make_copy(new_env, argv[0]);

  if (!enif_inspect_binary(new_env, bin_term, &bin)) {
    error("failed to get binary from erl term");
    ret = enif_make_badarg(env);
    goto free_and_exit;
  }

  image = vips_image_new_from_memory(bin.data, bin.size, width, height, bands,
                                     band_format);

  if (!image) {
    error("Failed to create image from memory. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to create image from memory");
    goto free_and_exit;
  }

  g_signal_connect(image, "close", G_CALLBACK(free_erl_env), new_env);

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));
  goto exit;

free_and_exit:
  enif_free_env(new_env);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_new_from_source(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VipsImage *image;
  VipsSource *source;
  ERL_NIF_TERM ret;
  ErlNifTime start;
  char opts[VIPS_PATH_MAX];

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&source)) {
    ret = make_error(env, "Failed to get VipsSource");
    goto exit;
  }

  if (!get_binary(env, argv[1], opts, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get opts");
    goto exit;
  }

  image = vips_image_new_from_source(source, opts, NULL);
  if (!image) {
    error("Failed to create image from fd. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to create image from VipsSource");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)image));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_to_target(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 3);

  VipsImage *image;
  VipsTarget *target;
  ERL_NIF_TERM ret;
  ErlNifTime start;
  char suffix[VIPS_PATH_MAX];

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (!erl_term_to_g_object(env, argv[1], (GObject **)&target)) {
    ret = make_error(env, "Failed to get VipsTarget");
    goto exit;
  }

  if (!get_binary(env, argv[2], suffix, VIPS_PATH_MAX)) {
    ret = make_error(env, "Failed to get suffix");
    goto exit;
  }

  if (vips_image_write_to_target(image, suffix, target, NULL)) {
    error("Failed to create image from fd. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write to target");
    goto exit;
  }

#if (VIPS_MAJOR_VERSION < 8) ||                                                \
    (VIPS_MAJOR_VERSION == 8 && VIPS_MINOR_VERSION < 13)
  vips_target_finish(target);
  ret = ATOM_OK;
#else
  if (vips_target_end(target) != 0) {
    error("Failed to end target. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to end target");
  } else {
    ret = ATOM_OK;
  }
#endif

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_write_to_binary(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;
  void *bin;
  size_t size;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  bin = vips_image_write_to_memory(image, &size);

  if (!bin) {
    error("Failed to write VipsImage to memory. error: %s",
          vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write VipsImage to memory");
    goto exit;
  }

  ret = make_ok(env, to_binary_term(env, bin, size));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

// Optimized version of fetching raw pixels for a region
ERL_NIF_TERM nif_image_write_area_to_binary(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM list, head, ret;
  void *bin;
  size_t size;
  guint list_length;
  int params[6] = {0, 0, 0, 0, 0, 0};
  int left, top, width, height, band_start, band_count;
  VipsImage **t = NULL;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  list = argv[1];

  if (!enif_get_list_length(env, list, &list_length)) {
    error("Failed to get list length");
    ret = enif_make_badarg(env);
    goto exit;
  }

  if (list_length != 6) {
    error("Must pass 6 integer params");
    ret = enif_make_badarg(env);
    goto exit;
  }

  for (guint i = 0; i < 6; i++) {
    if (!enif_get_list_cell(env, list, &head, &list)) {
      ret = make_error(env, "Failed to get list entry");
      goto exit;
    }

    if (!enif_get_int(env, head, &params[i])) {
      ret = make_error(env, "Failed to get int");
      goto exit;
    }
  }

  left = params[0];
  top = params[1];
  width = params[2];
  height = params[3];
  band_start = params[4];
  band_count = params[5];

  if (left == -1)
    left = 0;

  if (top == -1)
    top = 0;

  if (width == -1)
    width = vips_image_get_width(image);

  if (height == -1)
    height = vips_image_get_height(image);

  if (band_start == -1)
    band_start = 0;

  if (band_count == -1)
    band_count = vips_image_get_bands(image);

  // vips operations checks boundary, this is just to get better error reporting
  if (left + width > vips_image_get_width(image) ||
      top + height > vips_image_get_height(image) || left < 0 || top < 0 ||
      width <= 0 || height <= 0 ||
      band_start + band_count > vips_image_get_bands(image) || band_start < 0 ||
      band_count <= 0) {
    error("Bad extract area, left: %d, top: %d, width: %d, height: %d, "
          "band_start: %d, band_count: %d",
          left, top, width, height, band_start, band_count);
    vips_error_clear();
    ret =
        make_error(env, "Bad extract area. Ensure params are not out of bound");
    goto exit;
  }

  t = VIPS_ARRAY(NULL, 2, VipsImage *);

  if (vips_crop(image, &t[0], left, top, width, height, NULL)) {
    error("Failed to extract region. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to extract region");
    goto exit_free_temp_arr;
  }

  if (vips_extract_band(t[0], &t[1], band_start, "n", band_count, NULL)) {
    error("Failed to extract bands. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to extract bands");
    goto exit_free_temp_first;
  }

  bin = vips_image_write_to_memory(t[1], &size);

  if (!bin) {
    error("Failed to write extracted region to memory. error: %s",
          vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to write extracted region to memory");
    goto exit_free_temp_both;
  }

  ret = make_ok(
      env, enif_make_tuple5(env, to_binary_term(env, bin, size),
                            enif_make_int(env, vips_image_get_width(t[1])),
                            enif_make_int(env, vips_image_get_height(t[1])),
                            enif_make_int(env, vips_image_get_bands(t[1])),
                            enif_make_int(env, vips_image_get_format(t[1]))));

exit_free_temp_both:
  g_object_unref(t[1]);

exit_free_temp_first:
  g_object_unref(t[0]);

exit_free_temp_arr:
  g_free(t);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}
