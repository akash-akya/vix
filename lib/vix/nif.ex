defmodule Vix.Nif do
  @moduledoc false
  @on_load :load_nifs

  def load_nifs do
    nif_path = :filename.join(:code.priv_dir(:vix), "vix")
    :erlang.load_nif(nif_path, 0)
  end

  # GObject
  def nif_g_object_type_name(_obj), do: :erlang.nif_error(:nif_library_not_loaded)

  # GType
  def nif_g_type_from_instance(_instance), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_type_name(_type), do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsImage
  def nif_image_new_from_file(_src), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_from_source(_source), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_file(_vips_image, _dst),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_temp_file(_format),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_matrix_from_array(_height, _width, _list, _scale, _offset),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_file_thread(_vips_image, _dst),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsOperation
  def nif_vips_operation_call(_vips_operation_name, _input),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_operation_get_arguments(_operation_name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_operation_list(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_enum_list(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_flag_list(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_set_max(_max),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_get_max(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_concurrency_set(_concurrency),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_concurrency_get(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_set_max_files(_max_files),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_get_max_files(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_set_max_mem(_max_mem),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_cache_get_max_mem(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_version(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_shutdown(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsBoxed
  def nif_int_array(_int_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_array(_image_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_double_array(_double_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_int_array_to_erl_list(_vips_int_array),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_double_array_to_erl_list(_vips_double_array),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_image_array_to_erl_list(_vips_image_array),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsConnection
  def nif_vips_source_new(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_conn_write_result(_bin, _result),
    do: :erlang.nif_error(:nif_library_not_loaded)
end
