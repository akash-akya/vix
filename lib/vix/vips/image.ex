defmodule Vix.Vips.Image do
  defstruct [:ref]

  alias __MODULE__

  @moduledoc """
  Vips Image
  """

  alias Vix.Type
  alias Vix.Nif
  alias Vix.Vips.MutableImage

  @behaviour Type

  @typedoc """
  Represents an instance of VipsImage
  """
  @type t() :: %Image{ref: reference()}

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def to_nif_term(image, _data) do
    case image do
      %Image{ref: ref} ->
        ref

      value ->
        raise ArgumentError, message: "expected Vix.Vips.Image. given: #{inspect(value)}"
    end
  end

  @impl Type
  def to_erl_term(ref), do: %Image{ref: ref}

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

  If you want more control over the loader, Use specifc format loader from `Vix.Vips.Operation`. For example for jpeg use `Vix.Vips.Operation.jpegload/2`

  Loading is fast: only enough of the image is loaded to be able to fill out the header. Pixels will only be decompressed when they are needed.
  """
  @spec new_from_file(String.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_file(path) do
    path = Path.expand(path)

    Nif.nif_image_new_from_file(normalize_string(path))
    |> wrap_type()
  end

  @doc """
  Creates a new image with width, height, format, interpretation, resolution and offset taken from the input image, but with each band set from `value`.
  """
  @spec new_from_image(__MODULE__.t(), [float()]) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_image(%Image{ref: vips_image}, value) do
    float_value = Enum.map(value, &Vix.GObject.Double.normalize/1)

    Nif.nif_image_new_from_image(vips_image, float_value)
    |> wrap_type()
  end

  # Copy an image to a memory area.
  # If image is already a memory buffer, just ref and return. If it's
  # a file on disc or a partial, allocate memory and copy the image to
  # it. Intented to be used with draw operations when they are
  # properly supported
  @doc false
  @spec copy_memory(__MODULE__.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def copy_memory(%Image{ref: vips_image}) do
    Nif.nif_image_copy_memory(vips_image)
    |> wrap_type()
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

  If you want more control over the saver, Use specifc format saver from `Vix.Vips.Operation`. For example for jpeg use `Vix.Vips.Operation.jpegsave/2`
  """
  @spec write_to_file(__MODULE__.t(), String.t()) :: :ok | {:error, term()}
  def write_to_file(%Image{ref: vips_image}, path) do
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
  def write_to_buffer(%Image{ref: vips_image}, suffix) do
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
  @spec new_temp_file(String.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_temp_file(format) do
    Nif.nif_image_new_temp_file(normalize_string(format))
    |> wrap_type()
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
  @spec new_matrix_from_array(integer, integer, list(list), keyword()) ::
          {:ok, __MODULE__.t()} | {:error, term()}
  def new_matrix_from_array(width, height, list, optional \\ []) do
    scale = to_double(optional[:scale], 1)
    offset = to_double(optional[:offset], 0)

    Nif.nif_image_new_matrix_from_array(width, height, flatten_list(list), scale, offset)
    |> wrap_type()
  end

  @doc """
  Mutate an image in-place. You have to pass a function which takes MutableImage as argument. Inside the callback function, you can call functions which modify the image, such as setting or removing metadata. See `Vix.Vips.MutableImage`

  Return value of the callback is ignored.

  Call returns updated image.

  Example

  ```elixir
    {:ok, im} = Image.new_from_file("puppies.jpg")

    {:ok, new_im} =
      Image.mutate(im, fn mut_image ->
        :ok = MutableImage.update(mut_image, "orientation", 0)
        :ok = MutableImage.set(mut_image, "new-field", :gint, 0)
      end)
  ```
  """
  @spec mutate(__MODULE__.t(), (Vix.Vips.MutableImage.t() -> any())) ::
          {:ok, __MODULE__.t()} | {:error, term()}
  def mutate(%Image{} = image, callback) do
    {:ok, mut_image} = MutableImage.new(image)

    try do
      callback.(mut_image)
      MutableImage.to_image(mut_image)
    after
      MutableImage.stop(mut_image)
    end
  end

  @doc """
  Get all image header field names.

  See https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-fields for more details
  """
  @spec header_field_names(__MODULE__.t()) :: {:ok, [String.t()]} | {:error, term()}
  def header_field_names(%Image{ref: vips_image}) do
    Nif.nif_image_get_fields(vips_image)
  end

  @doc """
  Get image header value.

  This is a generic function to get header value.

  Casts the value to appropriate type. Returned value can be integer, float, string, binary, list. Use `Vix.Vips.Image.header_value_as_string/2` to get string representation of any header value.

  ```elixir
  {:ok, width} = Image.header_value(vips_image, "width")
  ```
  """
  @spec header_value(__MODULE__.t(), String.t()) ::
          {:ok, integer() | float() | String.t() | binary() | list()} | {:error, term()}
  def header_value(%Image{ref: vips_image}, name) do
    value = Nif.nif_image_get_header(vips_image, normalize_string(name))

    case value do
      {:ok, {type, value}} ->
        {:ok, Vix.Type.to_erl_term(type, value)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get image header value as string.

  This is generic method to get string representation of a header value. If value is VipsBlob, then it returns base64 encoded data.

  See: https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-as-string
  """
  @spec header_value_as_string(__MODULE__.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def header_value_as_string(%Image{ref: vips_image}, name) do
    Nif.nif_image_get_as_string(vips_image, normalize_string(name))
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

  defp wrap_type({:ok, ref}), do: {:ok, %Image{ref: ref}}
  defp wrap_type(value), do: value
end
