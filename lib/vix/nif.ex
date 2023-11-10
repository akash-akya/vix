defmodule Vix.Nif do
  @moduledoc false
  @on_load :load_nifs

  def load_nifs do
    nif_path = :filename.join(:code.priv_dir(:vix), "vix")
    :erlang.load_nif(nif_path, 0)
  end

  # GObject
  def nif_g_object_type_name(_obj),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # GType
  def nif_g_type_from_instance(_instance),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_type_name(_type),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsInterpolate
  def nif_interpolate_new(_name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsImage
  def nif_image_new_from_file(_src),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_from_image(_vips_image, _value),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_copy_memory(_vips_image),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_file(_vips_image, _dst),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_buffer(_vips_image, _suffix),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_temp_file(_format),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_matrix_from_array(_height, _width, _list, _scale, _offset),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_get_fields(_vips_image),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_get_header(_vips_image, _name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_get_as_string(_vips_image, _name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_hasalpha(_vips_image),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_from_source(_vips_source, _opts),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_to_target(_vips_image, _vips_target, _suffix),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_from_binary(_binary, _width, _height, _bands, _band_format),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_binary(_vips_image),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsImage *UNSAFE*
  def nif_image_update_metadata(_vips_image, _name, _value),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_set_metadata(_vips_image, _name, _type_name, _value),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_remove_metadata(_vips_image, _name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsOperation
  def nif_vips_operation_call(_vips_operation_name, _input),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_operation_get_arguments(_operation_name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_operation_list,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_enum_list,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_flag_list,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_set_max(_max),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_get_max,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_concurrency_set(_concurrency),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_concurrency_get,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_set_max_files(_max_files),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_get_max_files,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_set_max_mem(_max_mem),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_get_max_mem,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_version,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_shutdown,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_nickname_find(_type_name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsBoxed
  def nif_int_array(_int_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_array(_image_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_double_array(_double_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_blob(_binary),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_ref_string(_binary),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_int_array_to_erl_list(_vips_int_array),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_double_array_to_erl_list(_vips_double_array),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_image_array_to_erl_list(_vips_image_array),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_blob_to_erl_binary(_vips_blob),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_ref_string_to_erl_binary(_vips_blob),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsForeign
  def nif_foreign_find_load_buffer(_binary),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_foreign_find_save_buffer(_suffix),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_foreign_find_load(_filename),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_foreign_find_save(_filename),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_foreign_get_suffixes,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_foreign_get_loader_suffixes,
    do: :erlang.nif_error(:nif_library_not_loaded)

  # OS Specific
  def nif_pipe_open(_mode),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_write(_fd, _bin),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_read(_fd, _max_size),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_source_new,
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_target_new,
    do: :erlang.nif_error(:nif_library_not_loaded)
end
