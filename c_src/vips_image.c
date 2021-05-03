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

static int get_ref_string(ErlNifEnv *env, VipsImage *image, const char *name,
                          ERL_NIF_TERM *value) {
  const char *str;
  unsigned char *temp;
  ssize_t length;

  if (vips_image_get_string(image, name, &str)) {
    error("Failed to get string. error: %s", vips_error_buffer());
    vips_error_clear();
    *value = make_error(env, "Failed to get string");
    return -1;
  }

  length = strlen(str);
  temp = enif_make_new_binary(env, length, value);
  memcpy(temp, str, length);

  return 0;
}

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

  char src[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (enif_get_string(env, argv[0], src, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0) {
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

ERL_NIF_TERM nif_image_copy_memory(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 1);

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
  assert_argc(argc, 2);

  char dst[VIPS_PATH_MAX];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (enif_get_string(env, argv[1], dst, VIPS_PATH_MAX, ERL_NIF_LATIN1) < 0) {
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
  assert_argc(argc, 2);

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

  if (enif_get_string(env, argv[1], suffix, VIPS_PATH_MAX, ERL_NIF_LATIN1) <
      0) {
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
  assert_argc(argc, 0);

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
  assert_argc(argc, 1);

  char format[100];
  VipsImage *image;
  ErlNifTime start;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (enif_get_string(env, argv[0], format, VIPS_PATH_MAX, ERL_NIF_LATIN1) <
      0) {
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
  assert_argc(argc, 5);

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
  assert_argc(argc, 1);

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
  assert_argc(argc, 2);

  VipsImage *image;
  char header_name[MAX_HEADER_NAME_LENGTH];
  GType type;
  ERL_NIF_TERM ret;
  ERL_NIF_TERM value;
  ErlNifTime start;
  GValue gvalue = {0};
  VixResult res;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!erl_term_to_g_object(env, argv[0], (GObject **)&image)) {
    ret = make_error(env, "Failed to get VipsImage");
    goto exit;
  }

  if (enif_get_string(env, argv[1], header_name, MAX_HEADER_NAME_LENGTH,
                      ERL_NIF_LATIN1) < 0) {
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

    if (type == VIPS_TYPE_REF_STRING) {
      if (get_ref_string(env, image, header_name, &value))
        ret = enif_make_tuple2(env, ATOM_ERROR, value);
      else
        ret = make_ok(env, value);
    } else {
      ret = make_ok(env, res.result);
    }

  } else {
    ret = enif_make_tuple2(env, ATOM_ERROR, res.result);
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_image_get_as_string(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  assert_argc(argc, 2);

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

  if (enif_get_string(env, argv[1], header_name, MAX_HEADER_NAME_LENGTH,
                      ERL_NIF_LATIN1) < 0) {
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
