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
  def to_nif_term(value, _data), do: value

  @impl Type
  def to_erl_term(value), do: value

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
    path = Path.expand(path)
    Nif.nif_image_new_from_file(normalize_string(path))
  end

  @doc """
  Creates a new image with width, height, format, interpretation, resolution and offset taken from the input image, but with each band set from `value`.
  """
  @spec new_from_image(__MODULE__.t(), [float()]) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_image(vips_image, value) do
    float_value = Enum.map(value, &Vix.GObject.Double.normalize/1)
    Nif.nif_image_new_from_image(vips_image, float_value)
  end

  # Copy an image to a memory area.
  # If image is already a memory buffer, just ref and return. If it's
  # a file on disc or a partial, allocate memory and copy the image to
  # it. Intented to be used with draw operations when they are
  # properly supported
  @doc false
  @spec copy_memory(__MODULE__.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def copy_memory(vips_image) do
    Nif.nif_image_copy_memory(vips_image)
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

  @doc """
  Returns `vips_image` as binary based on the format specified by `suffix`. This function is similar to `write_to_file` but instead of writing the output to the file, it returns it as a binary.

  Currently only TIFF, JPEG and PNG formats are supported.

  Save options may be encoded in the filename or given as a hash. For example:

  ```elixir
  Image.write_to_buffer(vips_image, ".jpg[Q=90]")
  ```

  The full set of save options depend on the selected saver. You can get list of available options for the saver

  ```shell
  $ vips jpegsave
  ```
  """
  @spec write_to_buffer(__MODULE__.t(), String.t()) ::
          {:ok, binary()} | {:error, term()}
  def write_to_buffer(vips_image, suffix) do
    Nif.nif_image_write_to_buffer(vips_image, normalize_string(suffix))
  end

  @doc """
  Make a VipsImage which, when written to, will create a temporary file on disc.

  The file will be automatically deleted when the image is destroyed. format is something like `"%s.v"` for a vips file.

  The file is created in the temporary directory. This is set with the environment variable TMPDIR. If this is not set, then on Unix systems, vips will default to `/tmp`. On Windows, vips uses `GetTempPath()` to find the temporary directory.

  ```elixir
  vips_image = Image.new_temp_file("%s.v")
  ```
  """
  @spec new_temp_file(String.t()) :: :ok | {:error, term()}
  def new_temp_file(format) do
    Nif.nif_image_new_temp_file(normalize_string(format))
  end

  @doc """
  Make a VipsImage from list.

  This convenience function makes an image which is a matrix: a one-band VIPS_FORMAT_DOUBLE image held in memory. Useful for vips operations such as `conv`.

  ```elixir
  mask = Image.new_matrix_from_array(3, 3, [[0, 1, 0], [1, 1, 1], [0, 1, 0]])
  ```

  ## Optional
  * scale - Default: 1
  * offset - Default: 0
  """
  @spec new_matrix_from_array(integer, integer, list(list), keyword()) :: :ok | {:error, term()}
  def new_matrix_from_array(width, height, list, optional \\ []) do
    scale = to_double(optional[:scale], 1)
    offset = to_double(optional[:offset], 0)

    Nif.nif_image_new_matrix_from_array(width, height, flatten_list(list), scale, offset)
  end

  @doc """
  Get all image header field names.

  See https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-fields for more details
  """
  @spec header_field_names(__MODULE__.t()) :: {:ok, [String.t()]} | {:error, term()}
  def header_field_names(vips_image) do
    Nif.nif_image_get_fields(vips_image)
  end

  @doc """
  Get image header value.

  This is a generic function to get header value.

  Casts the value to appropriate type. Currently it only supports values of type integer, float, string and list of integer values. Use `Vix.Vips.Image.header_value_as_string/2` to get string representation of any header value.

  ```elixir
  {:ok, width} = Image.header_value(vips_image, "width")
  ```
  """
  @spec header_value(__MODULE__.t(), String.t()) ::
          {:ok, integer() | float() | String.t() | [integer()]} | {:error, term()}
  def header_value(vips_image, name) do
    Nif.nif_image_get_header(vips_image, normalize_string(name))
  end

  @doc """
  Get image header value as string.

  This is generic method to get string representation of a header value. If value is VipsBlob, then it returns base64 encoded data.

  See: https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-as-string
  """
  @spec header_value_as_string(__MODULE__.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def header_value_as_string(vips_image, name) do
    Nif.nif_image_get_as_string(vips_image, normalize_string(name))
  end

  @supported_suffix [".jpg", ".png"]

  @doc """
  **EXPERIMENTAL**

  Writes image to terminal using [iTerm2 proprietary escape sequence protocol](https://iterm2.com/documentation-images.html).

  Returns the input image similar to `IO.inspect/1`

  Note that currently this is not supported in the `iex`, this is intended to be used with patched Livebook.

  ## Optional
  * height - maximum height of the image. if image size is more than this, it will be scaled down to match this height keeping aspect ratio same. value should not be more than 500. Default: 300
  * label - label for the image. If not set - it will use `filename` header from the image metadata
  * suffix - image will be converted to this format for displaying. See `write_to_buffer` function suffix option. only supports `.jpg` and `.png` as of now. Default: `.jpg[Q=90]`
  """
  @spec display(__MODULE__.t(), keyword()) :: __MODULE__.t() | {:error, term()}
  def display(image, opts \\ []) do
    opts =
      Keyword.merge(
        [height: 300, suffix: ".jpg[Q=90]", label: "unnamed", io_device: :stdio],
        opts
      )

    max_height = min(500, opts[:height])

    ext =
      case Regex.named_captures(~r/^(?<ext>\.[a-zA-Z]+)/, opts[:suffix]) do
        %{"ext" => ext} when ext in @supported_suffix -> ext
        _ -> raise "Invalid suffix: #{inspect(opts[:suffix])}"
      end

    filename = opts[:label] <> ext

    height = height(image)

    scale =
      if height > max_height do
        max_height / height
      else
        1.0
      end

    {:ok, image_bin} =
      Vix.Vips.Operation.resize!(image, scale)
      |> write_to_buffer(ext)

    write_image_to_terminal(filename, image_bin, opts[:io_device])

    image
  end

  for name <-
        ~w/width height bands xres yres xoffset yoffset filename mode scale offset page_height n_pages orientation interpretation coding format/ do
    func_name = String.to_atom(name)

    @doc """
    Get #{name} of the the image

    see: https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-#{String.replace(name, "_", "-")}
    """
    @spec unquote(func_name)(__MODULE__.t()) :: term() | no_return()
    def unquote(func_name)(vips_image) do
      case header_value(vips_image, unquote(name)) do
        {:ok, value} -> value
        {:error, error} -> raise to_string(error)
      end
    end
  end

  # Proprietary escape sequences mainly used by iTerm2 and some other terminals.
  # see: https://iterm2.com/documentation-images.html
  @image_escape_sequence "\e]1337"

  defp write_image_to_terminal(filename, image_bin, io_device) do
    encoded = Base.encode64(image_bin)

    args =
      [name: Base.encode64(filename), size: byte_size(encoded), inline: 1]
      |> Enum.map(fn {name, value} -> "#{name}=#{value}" end)
      |> Enum.join(";")

    :ok = IO.write(io_device, [@image_escape_sequence, ";File=", args, ":", encoded, "\a"])
  end

  defp normalize_string(str) when is_binary(str), do: str

  defp normalize_string(str) when is_list(str), do: to_string(str)

  defp flatten_list(list) do
    Enum.flat_map(list, fn p ->
      Enum.map(p, &to_double/1)
    end)
  end

  defp to_double(v) when is_integer(v), do: v * 1.0
  defp to_double(v) when is_float(v), do: v

  defp to_double(nil, default), do: to_double(default)
  defp to_double(v, _default), do: to_double(v)
end
