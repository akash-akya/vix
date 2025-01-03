defmodule Vix.Vips.Foreign do
  @moduledoc false

  alias Vix.Nif

  @type operation_name :: String.t()

  @spec find_load_buffer(binary) :: {:ok, operation_name} | {:error, String.t()}
  def find_load_buffer(bin) do
    Nif.nif_foreign_find_load_buffer(bin)
  end

  @spec find_save_buffer(String.t()) :: {:ok, operation_name} | {:error, String.t()}
  def find_save_buffer(suffix) do
    Nif.nif_foreign_find_save_buffer(suffix)
  end

  @doc """
  Returns Vips operation name which can load the passed file
  """
  @spec find_load(String.t()) :: {:ok, operation_name} | {:error, String.t()}
  def find_load(filename) do
    Nif.nif_foreign_find_load(filename)
  end

  @doc """
  Returns Vips operation name which can save an image to passed format
  """
  @spec find_save(String.t()) :: {:ok, operation_name} | {:error, String.t()}
  def find_save(filename) do
    Nif.nif_foreign_find_save(filename)
  end

  @spec find_load_source(Vix.Vips.Source.t()) :: {:ok, operation_name} | {:error, String.t()}
  def find_load_source(%Vix.Vips.Source{ref: vips_source}) do
    Nif.nif_foreign_find_load_source(vips_source)
  end

  @spec find_save_target(String.t()) :: {:ok, operation_name} | {:error, String.t()}
  def find_save_target(suffix) do
    Nif.nif_foreign_find_save_target(suffix)
  end

  def get_suffixes do
    with {:ok, suffixes} <- Nif.nif_foreign_get_suffixes() do
      {:ok, Enum.uniq(suffixes)}
    end
  end

  def get_loader_suffixes do
    with {:ok, suffixes} <- Nif.nif_foreign_get_loader_suffixes() do
      {:ok, Enum.uniq(suffixes)}
    end
  end
end
