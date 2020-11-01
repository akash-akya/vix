defmodule Vix.Nif do
  @moduledoc false
  @on_load :load_nifs

  def load_nifs do
    nif_path = :filename.join(:code.priv_dir(:vix), "vix")
    :erlang.load_nif(nif_path, 0)
  end

  def nif_image_new_from_file(_src), do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_image_write_to_file(_vips_image, _dst),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsOperation
  def nif_vips_operation_call(_vips_operation_name, _input),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_operation_get_arguments(_operation_name),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_vips_operation_list(),
    do: :erlang.nif_error(:nif_library_not_loaded)

  # VipsBoxed
  def nif_int_array(_int_list),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def nif_double_array(_double_list),
    do: :erlang.nif_error(:nif_library_not_loaded)
end
