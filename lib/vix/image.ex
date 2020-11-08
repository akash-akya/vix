defmodule Vix.Image do
  alias Vix.Nif

  def new_from_file(path) do
    Nif.nif_image_new_from_file(normalize_string(path))
  end

  def write_to_file(vips_image, path) do
    Nif.nif_image_write_to_file(vips_image, normalize_string(path))
  end

  defp normalize_string(str) when is_binary(str), do: to_charlist(str)

  defp normalize_string(str) when is_list(str), do: str
end
