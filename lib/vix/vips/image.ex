defmodule Vix.Vips.Image do
  @moduledoc """
  Vips Image
  """

  alias Vix.Type
  alias Vix.Nif

  @behaviour Type

  @typedoc """
  Represents an instance of libvips image
  """
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def cast(value, _data), do: value

  @doc """
  Opens `path` for reading, returns an instance of `t:Vix.Vips.Image.t/0`

  It can load files in many image formats, including VIPS, TIFF, PNG, JPEG, FITS, Matlab, OpenEXR, CSV, WebP, Radiance, RAW, PPM and others.

  Load options may be appended to filename as "[name=value,...]". For example:

  ```elixir
  Image.new_from_file("fred.jpg[shrink=2]")
  ```
  Will open "fred.jpg", downsampling by a factor of two.

  The full set of options available depend upon the load operation that will be executed. Try something like:

  ```shell
  $ vips jpegload
  ```
  at the command-line to see a summary of the available options for the JPEG loader.

  Loading is fast: only enough of the image is loaded to be able to fill out the header. Pixels will only be decompressed when they are needed.
  """
  @spec new_from_file(String.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_file(path) do
    Nif.nif_image_new_from_file(normalize_string(path))
  end

  @doc """
  Write `vips_image` to a file.

  Save options may be encoded in the filename or given as a hash. For example:

  ```elixir
  Image.write_to_file(vips_image, "fred.jpg[Q=90]")
  ```

  A saver is selected based on `path`. The full set of save options depend on the selected saver. Try something like:

  ```shell
  $ vips jpegsave
  ```
  at the command-line to see all the available options for JPEG save.
  """
  @spec write_to_file(__MODULE__.t(), String.t()) :: :ok | {:error, term()}
  def write_to_file(vips_image, path) do
    Nif.nif_image_write_to_file(vips_image, normalize_string(path))
  end

  defp normalize_string(str) when is_binary(str), do: to_charlist(str)

  defp normalize_string(str) when is_list(str), do: str
end
