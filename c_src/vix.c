#include <glib-object.h>
#include <stdio.h>
#include <vips/vips.h>

#include "utils.h"

#include "g_object/g_boxed.h"
#include "g_object/g_object.h"
#include "g_object/g_param_spec.h"
#include "g_object/g_type.h"
#include "pipe.h"
#include "vips_boxed.h"
#include "vips_foreign.h"
#include "vips_image.h"
#include "vips_interpolate.h"
#include "vips_operation.h"

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info) {
  if (VIPS_INIT("vix")) {
    error("Failed to initialize Vips");
    return 1;
  }

  ERL_NIF_TERM logger_level;
  ERL_NIF_TERM logger_level_key = enif_make_atom(env, "nif_logger_level");

  if (!enif_get_map_value(env, load_info, logger_level_key, &logger_level)) {
    error("Failed to fetch logger level config from map");
    return 1;
  }

  char log_level[20] = {0};
  if (enif_get_atom(env, logger_level, log_level, 19, ERL_NIF_LATIN1) < 1) {
    error("Failed to fetch logger level atom value");
    return 1;
  }

#ifdef DEBUG
  vips_leak_set(true);
  // when checking for leaks disable cache
  vips_cache_set_max(0);
#endif

  if (utils_init(env, log_level))
    return 1;

  if (nif_g_object_init(env))
    return 1;

  if (nif_g_param_spec_init(env))
    return 1;

  if (nif_g_boxed_init(env))
    return 1;

  if (nif_g_type_init(env))
    return 1;

  if (nif_vips_operation_init(env))
    return 1;

  if (nif_pipe_init(env))
    return 1;

  return 0;
}

static ErlNifFunc nif_funcs[] = {
    /* GObject */
    {"nif_g_object_type_name", 1, nif_g_object_type_name, 0},
    {"nif_g_object_unref", 1, nif_g_object_unref, ERL_NIF_DIRTY_JOB_CPU_BOUND},

    /* GType */
    {"nif_g_type_from_instance", 1, nif_g_type_from_instance, 0},
    {"nif_g_type_name", 1, nif_g_type_name, 0},

    /* VipsInterpolate */
    {"nif_interpolate_new", 1, nif_interpolate_new, 0},

    /* VipsImage */
    {"nif_image_new_from_file", 1, nif_image_new_from_file,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_new_from_image", 2, nif_image_new_from_image,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_copy_memory", 1, nif_image_copy_memory,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_write_to_file", 2, nif_image_write_to_file,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_write_to_buffer", 2, nif_image_write_to_buffer,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_new", 0, nif_image_new, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_new_temp_file", 1, nif_image_new_temp_file,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_new_matrix_from_array", 5, nif_image_new_matrix_from_array, 0},
    {"nif_image_get_fields", 1, nif_image_get_fields, 0},
    {"nif_image_get_header", 2, nif_image_get_header, 0},
    {"nif_image_get_as_string", 2, nif_image_get_as_string, 0},
    {"nif_image_hasalpha", 1, nif_image_hasalpha, 0},
    {"nif_image_new_from_source", 2, nif_image_new_from_source,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_to_target", 3, nif_image_to_target, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_new_from_binary", 5, nif_image_new_from_binary,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_image_write_to_binary", 1, nif_image_write_to_binary,
     ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_image_write_area_to_binary", 2, nif_image_write_area_to_binary,
     ERL_NIF_DIRTY_JOB_CPU_BOUND},

    /* VipsImage UNSAFE */
    {"nif_image_update_metadata", 3, nif_image_update_metadata, 0},
    {"nif_image_set_metadata", 4, nif_image_set_metadata, 0},
    {"nif_image_remove_metadata", 2, nif_image_remove_metadata, 0},

    /* VipsOperation */
    /* should these be ERL_NIF_DIRTY_JOB_IO_BOUND? */
    {"nif_vips_operation_call", 2, nif_vips_operation_call,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"nif_vips_operation_get_arguments", 1, nif_vips_operation_get_arguments,
     ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_vips_operation_list", 0, nif_vips_operation_list,
     ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_vips_enum_list", 0, nif_vips_enum_list, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_vips_flag_list", 0, nif_vips_flag_list, ERL_NIF_DIRTY_JOB_CPU_BOUND},

    /* Vips */
    {"nif_vips_cache_set_max", 1, nif_vips_cache_set_max, 0},
    {"nif_vips_cache_get_max", 0, nif_vips_cache_get_max, 0},
    {"nif_vips_concurrency_set", 1, nif_vips_concurrency_set, 0},
    {"nif_vips_concurrency_get", 0, nif_vips_concurrency_get, 0},
    {"nif_vips_cache_set_max_files", 1, nif_vips_cache_set_max_files, 0},
    {"nif_vips_cache_get_max_files", 0, nif_vips_cache_get_max_files, 0},
    {"nif_vips_cache_set_max_mem", 1, nif_vips_cache_set_max_mem, 0},
    {"nif_vips_cache_get_max_mem", 0, nif_vips_cache_get_max_mem, 0},
    {"nif_vips_leak_set", 1, nif_vips_leak_set, 0},
    {"nif_vips_tracked_get_mem", 0, nif_vips_tracked_get_mem, 0},
    {"nif_vips_tracked_get_mem_highwater", 0, nif_vips_tracked_get_mem, 0},
    {"nif_vips_version", 0, nif_vips_version, 0},
    {"nif_vips_shutdown", 0, nif_vips_shutdown, 0},
    {"nif_vips_nickname_find", 1, nif_vips_nickname_find, 0},

    /* VipsBoxed */
    {"nif_int_array", 1, nif_int_array, 0},
    {"nif_image_array", 1, nif_image_array, 0},
    {"nif_double_array", 1, nif_double_array, 0},
    {"nif_vips_blob", 1, nif_vips_blob, 0},
    {"nif_vips_ref_string", 1, nif_vips_ref_string, 0},
    {"nif_vips_int_array_to_erl_list", 1, nif_vips_int_array_to_erl_list, 0},
    {"nif_vips_double_array_to_erl_list", 1, nif_vips_double_array_to_erl_list,
     0},
    {"nif_vips_image_array_to_erl_list", 1, nif_vips_image_array_to_erl_list,
     0},
    {"nif_vips_blob_to_erl_binary", 1, nif_vips_blob_to_erl_binary, 0},
    {"nif_vips_ref_string_to_erl_binary", 1, nif_vips_ref_string_to_erl_binary,
     0},
    {"nif_g_boxed_unref", 1, nif_g_boxed_unref, ERL_NIF_DIRTY_JOB_CPU_BOUND},

    /* VipsForeign */
    {"nif_foreign_find_load", 1, nif_foreign_find_load, 0},
    {"nif_foreign_find_save", 1, nif_foreign_find_save, 0},
    {"nif_foreign_find_load_buffer", 1, nif_foreign_find_load_buffer,
     ERL_NIF_DIRTY_JOB_IO_BOUND},
    // it might read bytes form the file
    {"nif_foreign_find_save_buffer", 1, nif_foreign_find_save_buffer, 0},
    {"nif_foreign_find_load_source", 1, nif_foreign_find_load_source,
     ERL_NIF_DIRTY_JOB_IO_BOUND}, // it might read bytes from source
    {"nif_foreign_find_save_target", 1, nif_foreign_find_save_target, 0},
    {"nif_foreign_get_suffixes", 0, nif_foreign_get_suffixes, 0},
    {"nif_foreign_get_loader_suffixes", 0, nif_foreign_get_loader_suffixes, 0},

    /* Syscalls */
    {"nif_pipe_open", 1, nif_pipe_open, 0},
    {"nif_write", 2, nif_write, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_read", 2, nif_read, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_source_new", 0, nif_source_new, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"nif_target_new", 0, nif_target_new, ERL_NIF_DIRTY_JOB_CPU_BOUND}};

ERL_NIF_INIT(Elixir.Vix.Nif, nif_funcs, &on_load, NULL, NULL, NULL)
