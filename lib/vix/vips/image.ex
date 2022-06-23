defmodule Vix.Vips.Image do
  defstruct [:ref]

  alias __MODULE__

  @moduledoc """
  Functions for reading and writing images as well as
  accessing and updating image metadata.

  The `Access` behaviour is implemented to allow
  acccess to image bands. For example `image[1]`. Note that
  due to the nature of images, `pop/2` and `put_and_udpate/3`
  are not supported.

  """

  alias Vix.Type
  alias Vix.Nif
  alias Vix.Vips.MutableImage

  require Logger

  defmodule Error do
    defexception [:message]
  end

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

  # Implements the Access behaviour for Vix.Vips.Image to allow
  # acccess to image bands. For example `image[1]`. Note that
  # due to the nature of images, `pop/2` and `put_and_udpate/3`
  # are not supported.

  @behaviour Access

  @impl Access
  def fetch(image, band) when is_integer(band) do
    case Vix.Vips.Operation.extract_band(image, band) do
      {:ok, band} -> {:ok, band}
      {:error, _reason} -> :error
    end
  end

  @impl Access
  def get_and_update(_image, _key, _fun) do
    raise "get_and_update/3 for Vix.Vips.Image is not supported."
  end

  @impl Access
  def pop(_image, _band, _default \\ nil) do
    raise "pop/3 for Vix.Vips.Image is not supported."
  end

  @doc """
  Opens `path` for reading, returns an instance of `t:Vix.Vips.Image.t/0`

  It can load files in many image formats, including VIPS, TIFF, PNG,
  JPEG, FITS, Matlab, OpenEXR, CSV, WebP, Radiance, RAW, PPM and
  others.

  Load options may be appended to filename as "[name=value,...]". For
  example:

  ```elixir
  Image.new_from_file("fred.jpg[shrink=2]")
  ```
  Will open "fred.jpg", downsampling by a factor of two.

  The full set of options available depend upon the load operation
  that will be executed. Try something like:

  ```shell
  $ vips jpegload
  ```

  at the command-line to see a summary of the available options for
  the JPEG loader.

  If you want more control over the loader, Use specifc format loader
  from `Vix.Vips.Operation`. For example for jpeg use
  `Vix.Vips.Operation.jpegload/2`

  Loading is fast: only enough of the image is loaded to be able to
  fill out the header. Pixels will only be decompressed when they are
  needed.
  """
  @spec new_from_file(String.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_file(path) do
    path = Path.expand(path)

    Nif.nif_image_new_from_file(normalize_string(path))
    |> wrap_type()
  end

  @doc """
  Create a new image based on an existing image with each pixel set to `value`

  Creates a new image with width, height, format, interpretation,
  resolution and offset taken from the input image, but with each band
  set from `value`.
  """
  @spec new_from_image(__MODULE__.t(), [float()]) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_image(%Image{ref: vips_image}, value) do
    float_value = Enum.map(value, &Vix.GObject.Double.normalize/1)

    Nif.nif_image_new_from_image(vips_image, float_value)
    |> wrap_type()
  end

  @doc """
  Create a new image from formatted binary

  Create a new image from formatted binary `bin`. Binary should be an
  image encoded in a format such as JPEG. It tries to recognize the
  format by checking the binary.

  If you already know the image format of `bin` then you can just use
  corresponding loader operation function directly from
  `Vix.Vips.Operation` instead. For example to load jpeg, you can use
  `Vix.Vips.Operation.jpegload_buffer/2`

  `bin` should be formatted binary (ie. JPEG, PNG etc). For loading
  unformatted binary (raw pixel data) see `new_from_binary/5`.

  Optional param `opts` is passed to the image loader. Options
  available depend on the file format. You can find all options
  available like this:

  ```sh
  $ vips jpegload_buffer
  ```

  Not all loaders support load from buffer, but at least JPEG, PNG and
  TIFF images will work.
  """
  @spec new_from_buffer(binary(), keyword()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_buffer(bin, opts \\ []) do
    with {:ok, loader} <- Vix.Vips.Foreign.find_load_buffer(bin),
         {:ok, {ref, _optional}} <- Vix.Vips.OperationHelper.operation_call(loader, [bin], opts) do
      {:ok, wrap_type(ref)}
    end
  end

  @doc """
  Create a new image from raw pixel data

  Creates an image by wrapping passed raw pixel data. This function
  does not copy the passed binary, instead it just creates a reference
  to the binary term (zero-copy). So this function is very efficient.

  This function is useful when you are getting raw pixel data from
  some other library like
  [`eVision`](https://github.com/cocoa-xu/evision) or
  [`Nx`](https://github.com/elixir-nx/) and want to perform some
  operation on it using Vix.

  Binary should be sequence of pixel data, for example: RGBRGBRGB. and
  order should be left-to-right, top-to-bottom.

  `bands` should be number values which represent the each pixel. For
  example: if each pixel is RGB then `bands` will be 3. If each pixel
  is RGBA then `bands` will be 4.  `band_format` refers to type of
  each band. Usually it will be `:VIPS_FORMAT_UCHAR`.

  `bin` should be raw pixel data binary. For loading
  formatted binary (JPEG, PNG) see `new_from_buffer/2`.

  ##  Endianness

  Byte order of the data *must* be in native endianness. This matters
  if you are generating or manipulating binary by using bitstring
  syntax. By default bitstring treat binary byte order as `big` endian
  which might *not* be native. Always use `native` specifier to
  ensure. See [Elixir
  docs](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#%3C%3C%3E%3E/1-endianness)
  for more details.

  """
  @spec new_from_binary(
          binary(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          Vix.Vips.Operation.vips_band_format()
        ) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_binary(bin, width, height, bands, band_format)
      when width > 0 and height > 0 and bands > 0 do
    band_format = Vix.Vips.Enum.VipsBandFormat.to_nif_term(band_format, nil)

    Nif.nif_image_new_from_binary(bin, width, height, bands, band_format)
    |> wrap_type()
  end

  @doc """
  Create a new image from Enumerable.

  > #### Caution {: .warning}
  > This function is experimental and might cause crashes, use with caution

  Returns an image which will lazily pull data from passed
  Enumerable. `enum` should be stream of bytes of an encoded image
  such as JPEG. This functions recognizes the image format and
  metadata by reading starting bytes and wraps passed Enumerable as an
  image. Remaining bytes are read on-demand.

  Useful when working with big images. Where you don't want to load
  complete input image data to memory.

  ```elixir
  {:ok, image} =
    File.stream!("puppies.jpg", [], 1024) # or read from s3, web-request
    |> Image.new_from_enum()

  :ok = Image.write_to_file(image, "puppies.png")
  ```

  Optional param `opts` string is passed to the image loader. It is a string
  of the format "[name=value,...]".

  ```elixir
  Image.new_from_enum(stream, "[shrink=2]")
  ```

  Will read the stream with downsampling by a factor of two.

  The full set of options available depend upon the image format. You
  can find all options available at the command-line. To see a summary
  of the available options for the JPEG loader:

  ```shell
  $ vips jpegload_source
  ```

  """
  @spec new_from_enum(Enumerable.t(), String.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new_from_enum(enum, opts \\ "") do
    parent = self()

    pid =
      spawn_link(fn ->
        {pipe, source} = Vix.SourcePipe.new()
        send(parent, {self(), source})

        Enum.each(enum, fn iodata ->
          bin =
            try do
              IO.iodata_to_binary(iodata)
            rescue
              ArgumentError ->
                Logger.warn("argument must be stream of iodata")
                Vix.SourcePipe.stop(pipe)
                exit(:normal)
            end

          :ok = Vix.SourcePipe.write(pipe, bin)
        end)

        Vix.SourcePipe.stop(pipe)
      end)

    receive do
      {^pid, source} ->
        Nif.nif_image_new_from_source(source, opts)
        |> wrap_type()
    end
  end

  @doc """
  Creates a Stream from Image.

  > #### Caution {: .warning}
  > This function is experimental and might cause crashes, use with caution

  Returns a Stream which will lazily pull data from passed image.

  Useful when working with big images. Where you don't want to keep
  complete output image in memory.


  ```elixir
  {:ok, image} = Image.new_from_file("puppies.jpg")

  :ok =
    Image.write_to_stream(image, ".png")
    |> Stream.into(File.stream!("puppies.png")) # or write to S3, web-request
    |> Stream.run()
  ```

  Second param `suffix` determines the format of the output
  stream. Save options may be appended to the suffix as
  "[name=value,...]".

  ```elixir
  Image.write_to_stream(vips_image, ".jpg[Q=90]")
  ```

  Options are specific to save operation. You can find out all
  available options for the save operation at command line. For
  example:

  ```shell
  $ vips jpegsave_target
  ```

  """
  @spec write_to_stream(__MODULE__.t(), String.t()) :: Enumerable.t()
  def write_to_stream(%Image{ref: vips_image}, suffix) do
    Stream.resource(
      fn ->
        {:ok, pipe} = Vix.TargetPipe.new(vips_image, suffix)
        pipe
      end,
      fn pipe ->
        ret = Vix.TargetPipe.read(pipe)

        case ret do
          :eof ->
            {:halt, pipe}

          {:ok, bin} ->
            {[bin], pipe}

          {:error, reason} ->
            raise Error, reason
        end
      end,
      fn pipe ->
        Vix.TargetPipe.stop(pipe)
      end
    )
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

  Save options may be encoded in the filename. For example:

  ```elixir
  Image.write_to_file(vips_image, "fred.jpg[Q=90]")
  ```

  A saver is selected based on image extension in `path`. The full set
  of save options depend on the selected saver. Try something like:

  ```shell
  $ vips jpegsave
  ```
  at the command-line to see all the available options for JPEG save.

  If you want more control over the saver, Use specifc format saver
  from `Vix.Vips.Operation`. For example for jpeg use
  `Vix.Vips.Operation.jpegsave/2`

  """
  @spec write_to_file(__MODULE__.t(), String.t()) :: :ok | {:error, term()}
  def write_to_file(%Image{ref: vips_image}, path) do
    Nif.nif_image_write_to_file(vips_image, normalize_string(path))
  end

  @doc """
  Returns `vips_image` as binary based on the format specified by `suffix`.

  This function is similar to `write_to_file` but instead of writing
  the output to the file, it returns it as a binary.

  Currently only TIFF, JPEG and PNG formats are supported.

  Save options may be encoded in the filename. For example:

  ```elixir
  Image.write_to_buffer(vips_image, ".jpg[Q=90]")
  ```

  The full set of save options depend on the selected saver. You can
  get list of available options for the saver

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
  Returns raw pixel data of the image as `Vix.Tensor`

  VIPS images are three-dimensional arrays, the dimensions being
  width, height and bands.

  Each dimension can be up to 2 ** 31 pixels (or band elements).
  An image has a format, meaning the machine number type used to
  represent each value. VIPS supports 10 formats, from 8-bit unsigned
  integer up to 128-bit double complex.

  In VIPS, images are uninterpreted arrays, meaning that from
  the point of view of most operations, they are just large
  collections of numbers. There's no difference between an RGBA
  (RGB with alpha) image and a CMYK image, for example, they are
  both just four-band images.

  This function is intended to support interoperability of image
  data between different libraries.  Since the array is created as
  a NIF resource it will be correctly garbage collected when
  the last reference falls out of scope.

  Libvips might run all the operations to produce the pixel data
  depending on the caching mechanism and how image is built.

  ##  Endianness

  Returned binary term will be in native endianess. By default
  bitstring treats byte order as `big` endian which might *not* be
  native. Always use `native` specifier to ensure. See [Elixir
  docs](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#%3C%3C%3E%3E/1-endianness)
  for more details.

  """
  @spec write_to_tensor(__MODULE__.t()) :: {:ok, Vix.Tensor.t()} | {:error, term()}
  def write_to_tensor(%Image{} = image) do
    with {:ok, binary} <- write_to_binary(image) do
      {:ok, Vix.Tensor.binary_to_tensor(binary, byte_size(binary), image)}
    end
  end

  @doc """
  Returns raw pixel data of the image as binary term

  Please check `write_to_tensor` for more details. This function just
  returns the data instead of the `Vix.Tensor` struct.

  Prefer using `write_to_tensor` instead of this function. This is
  only useful if you already know the details about the returned
  binary blob. Such as height, width and bands.
  """
  @spec write_to_binary(__MODULE__.t()) :: {:ok, binary()} | {:error, term()}
  def write_to_binary(%Image{ref: vips_image}) do
    Nif.nif_image_write_to_binary(vips_image)
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
  Return a boolean indicating if an image has an alpha band.

  Example

  ```elixir
    {:ok, im} = Image.new_from_file("puppies.jpg")

    has_alpha? = Image.has_alpha?(im)
  ```
  """
  @spec has_alpha?(__MODULE__.t()) :: boolean | no_return()
  def has_alpha?(%Image{ref: vips_image}) do
    case Nif.nif_image_hasalpha(vips_image) do
      {:ok, value} ->
        value

      {:error, reason} ->
        raise reason
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
        ~w/width height bands xres yres xoffset yoffset filename mode scale offset page-height n-pages orientation interpretation coding format/ do
    func_name = name |> String.replace("-", "_") |> String.to_atom()

    @doc """
    Get "#{name}" of the image

    > #### More details {: .tip}
    >
    > See [libvips docs](https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-#{name}) for more details regarding `#{func_name}` function

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
