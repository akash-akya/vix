defmodule Eips.Nif do
  @moduledoc false
  @on_load :load_nifs

  def load_nifs do
    nif_path = :filename.join(:code.priv_dir(:eips), "eips")
    nif_path = :filename.join(:code.priv_dir(:eips), "eips")
    :erlang.load_nif(nif_path, 0)
  end

  def invert(_src, _dst), do: :erlang.nif_error(:nif_library_not_loaded)

  def gintro(), do: :erlang.nif_error(:nif_library_not_loaded)

  def inspect_op(_op), do: :erlang.nif_error(:nif_library_not_loaded)

  def vop_dump(_vips_object), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_create_op(_op_name), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_get_op_arguments(_vips_operation), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_new_from_file(_src), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_operation_set_property(_vips_operation, _name, _g_type, _g_object),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_object_to_g_object(_vips_object), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_object_to_vips_object(_vips_object), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_object_to_vips_image(_vips_object), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_operation_call(_vips_operation), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_operation_get_property(_vips_operation, _name, _g_type),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_operation_call_with_args(_vips_operation_name, _input, _output),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_file(_vips_image, _dst),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_type_find(_nickname),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_object_type(_g_object),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_object_type_name(_g_object),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_g_type_name(_g_object),
    do: :erlang.nif_error(:nif_library_not_loaded)
end
