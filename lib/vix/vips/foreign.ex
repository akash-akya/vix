defmodule Vix.Vips.Foreign do
  alias Vix.Nif
  @moduledoc false

  def find_load_buffer(bin) do
    Nif.nif_foreign_find_load_buffer(bin)
  end

  def find_save_buffer(suffix) do
    Nif.nif_foreign_find_save_buffer(suffix)
  end

  def find_load(filename) do
    Nif.nif_foreign_find_load(filename)
  end

  def find_save(filename) do
    Nif.nif_foreign_find_save(filename)
  end
end
