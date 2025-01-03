defmodule Vix.Vips.Image do
  @moduledoc """
  Functions for reading and writing images as well as
  accessing and updating image metadata.

  ## Access syntax (slicing)

  Vix images implement Elixir's access syntax. This allows developers
  to slice images and easily access sub-dimensions and values.

  ### Integer
  Access accepts integers. Integers will extract an image band using parameter as index:

      #=> {:ok, i} = Image.new_from_file("./test/images/puppies.jpg")
      {:ok, %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153539>}}
      #=> i[0]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153540>}

  If a negative index is given, it accesses the band from the back:

      #=> i[-1]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153540>}

  Out of bound access will throw an `ArgumentError` exception:

      #=> i[-4]
      ** (ArgumentError) Invalid band requested. Found -4

  ### Range

  Access also accepts ranges. Ranges in Elixir are inclusive:

      #=> i[0..1]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153641>}

  Ranges can receive negative positions and they will read from
  the back. In such cases, the range step must be explicitly given
  (on Elixir 1.12 and later) and the right-side of the range must
  be equal or greater than the left-side:

      #=> i[0..-1//1]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153703>}

  To slice across multiple dimensions, you can wrap the ranges in a list.
  The list will be of the form `[with_slice, height_slice, band_slice]`.

      # Returns an image that slices a 10x10 pixel square
      # from the top left of the image with three bands
      #=> i[[0..9, 0..9, 0..3]]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153738>}

  If number of dimensions are less than 3 then remaining dimensions
  are returned in full

      # If `i` size is 100x100 with 3 bands
      #=> i[[0..9, 0..9]] # equivalent to `i[[0..9, 0..9, 0..2]]`
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153740>}

      #=> i[[0..9]] # equivalent to `i[[0..9, 0..99, 0..2]]`
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153703>}

  Slices can include negative ranges in which case the indexes
  are calculated from the right and bottom of the image.

      # Slices the bottom right 10x10 pixels of the image
      # and returns all bands.
      #=> i[[-10..-1, -10..-1]]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153742>}

  Slice can mix integers and ranges

      # Slices the bottom right 10x1 pixels of the image
      # and returns all bands.
      #=> i[[-10..-1, -1]]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153742>}

  ### Keyword List

  Access also accepts keyword list. Where key can be any of `width`,
  `height`, `band`.  and value must be an `integer`, `range`. This is
  useful for complex scenarios when you want omit dimensions arbitrary
  dimensions.

      # Slices an image with height 10 with max width and all bands
      #=> i[[height: 0..10]]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153742>}

      # Slices an image with single band 1
      #=> i[[band: 1]]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153742>}

      # Slices the bottom right 10x10 pixels of the image
      # and returns all bands.
      #=> i[[width: -10..-1, height: -10..-1]]
      %Vix.Vips.Image{ref: #Reference<0.2448791511.2685009949.153742>}
  """

  defstruct [:ref]

  alias __MODULE__
  alias Vix.Nif
  alias Vix.Type
  alias Vix.Vips.MutableImage
  alias Vix.Vips.Operation

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
  # access to image bands. For example `image[1]`. Note that
  # due to the nature of images, `pop/2` and `put_and_update/3`
  # are not supported.

  @behaviour Access

  @impl Access

  # Extract band when the band number is positive or zero
  def fetch(image, band) when is_integer(band) and band >= 0 do
    case Operation.extract_band(image, band) do
      {:ok, band} -> {:ok, band}
      {:error, _reason} -> raise ArgumentError, "Invalid band requested. Found #{inspect(band)}"
    end
  end

  # Extract band when the band number is negative
  def fetch(image, band) when is_integer(band) and band < 0 do
    case bands(image) + band do
      band when band >= 0 -> fetch(image, band)
      _other -> raise ArgumentError, "Invalid band requested. Found #{inspect(band)}"
    end
  end

  def fetch(image, %Range{} = range) do
    if single_step_range?(range) do
      fetch_range(image, range)
    else
      raise ArgumentError, "Range arguments must have a step of 1. Found #{inspect(range)}"
    end
  end

  # Slicing the image
  def fetch(image, args) when is_list(args) do
    with {:ok, args} <- normalize_access_args(args),
         {:ok, left, width} <- validate_dimension(args[:width], width(image)),
         {:ok, top, height} <- validate_dimension(args[:height], height(image)),
         {:ok, first_band, bands} <- validate_dimension(args[:band], bands(image)) do
      extracted_image =
        image
        |> extract_area!(left, top, width, height)
        |> extract_band!(first_band, n: bands)

      {:ok, extracted_image}
    else
      {:error, _} ->
        raise ArgumentError, "Argument must be list of integers or ranges or keyword list"
    end
  end

  @impl Access
  def get_and_update(_image, _key, _fun) do
    raise ArgumentError, "get_and_update/3 for Vix.Vips.Image is not supported."
  end

  @impl Access
  def pop(_image, _band) do
    raise ArgumentError, "pop/3 for Vix.Vips.Image is not supported."
  end

  # Extract a range of bands
  defp fetch_range(image, %Range{first: first, last: last}) when first >= 0 and last >= first do
    case Operation.extract_band(image, first, n: last - first + 1) do
      {:ok, band} -> {:ok, band}
      {:error, _reason} -> raise Error, "Invalid band range #{inspect(first..last)}"
    end
  end

  defp fetch_range(image, %Range{first: first, last: last}) when first >= 0 and last < 0 do
    case bands(image) + last do
      last when last >= 0 -> fetch(image, first..last)
      _other -> raise ArgumentError, "Resolved invalid band range #{first..last}}"
    end
  end

  defp fetch_range(image, %Range{first: first, last: last}) when last < 0 and first < last do
    bands = bands(image)
    last = bands + last

    if last > 0 do
      fetch(image, (bands + first)..last)
    else
      raise ArgumentError, "Resolved invalid range #{(bands + first)..last}"
    end
  end

  defp fetch_range(_image, %Range{} = range) do
    raise ArgumentError, "Invalid range #{inspect(range)}"
  end

  # For nil use maximum value
  defp validate_dimension(nil, limit), do: {:ok, 0, limit}

  # For integer treat it as single band
  defp validate_dimension(index, limit) when is_integer(index) do
    index = if index < 0, do: limit + index, else: index

    if index < limit do
      {:ok, index, 1}
    else
      raise ArgumentError,
            "Invalid dimension #{inspect(index)}. Dimension must be between 0 and #{inspect(index - 1)}"
    end
  end

  # For positive ranges start from the left and top
  defp validate_dimension(%Range{} = range, width) do
    if single_step_range?(range) do
      validate_range_dimension(range, width)
    else
      raise ArgumentError, "Range arguments must have a step of 1. Found #{inspect(range)}"
    end
  end

  # For positive ranges start from the left and top
  defp validate_range_dimension(%Range{first: first, last: last}, width)
       when first >= 0 and last > first and last < width do
    {:ok, first, last - first + 1}
  end

  # For negative ranges start from the right and bottom
  defp validate_range_dimension(%Range{first: first, last: last}, limit)
       when first < 0 and last < 0 and last > first and abs(first) < limit do
    {:ok, limit + first, limit + last - (limit + first) + 1}
  end

  # Positive start to a negative end
  defp validate_range_dimension(%Range{first: first, last: last}, limit)
       when first >= 0 and last < 0 and abs(last) <= limit do
    {:ok, first, limit + last - first + 1}
  end

  defp validate_range_dimension(range, _limit) do
    raise ArgumentError, "Invalid range #{inspect(range)}"
  end

  # We can do this as a guard in later Elixir versions but
  # Vix is intended to run on a wide range of Elixir versions.

  defp single_step_range?(%Range{} = range) do
    Map.get(range, :step) == 1 || !Map.has_key?(range, :step)
  end

  @spec extract_area!(
          Image.t(),
          non_neg_integer,
          non_neg_integer,
          non_neg_integer,
          non_neg_integer
        ) :: Image.t() | no_return
  defp extract_area!(image, left, top, width, height) do
    case Operation.extract_area(image, left, top, width, height) do
      {:ok, image} -> image
      {:error, _} = _error -> raise Error, "Requested area could not be extracted"
    end
  end

  @spec extract_band!(Image.t(), non_neg_integer, keyword) :: Image.t() | no_return
  defp extract_band!(area, first_band, options) do
    case Operation.extract_band(area, first_band, options) do
      {:ok, image} -> image
      {:error, _} = _error -> raise Error, "Requested band(s) could not be extracted"
    end
  end

  @doc """
  Builds an Image

  ## Options

  * `interpretation` : must be a valid vips_interpretation or `:auto`. When value is
    `:auto` it will be set based on the number of bands in the `background`. Defaults to `:auto`

  * `format` : must be a valid vips_format or `:auto`. When value is `:auto` it will
     be set to a format just large enough to hold all the values. Ex, if any of the
     value is a float then format will be `:VIPS_FORMAT_DOUBLE`

  ## Examples

  ```elixir
  iex> {:ok, %Image{ref: _} = img} = Image.build_image(1, 2, [10])
  iex> Image.to_list(img)
  {:ok, [[[10]], [[10]]]}
  iex> Image.shape(img)
  {1, 2, 1}
  ```

  Correctly sets interpretation
  ```elixir
  iex> {:ok, img} = Image.build_image(1, 2, [10])
  iex> Image.interpretation(img)
  :VIPS_INTERPRETATION_B_W
  iex> {:ok, img} = Image.build_image(10, 10, [10, 10, 10])
  iex> Image.interpretation(img)
  :VIPS_INTERPRETATION_RGB
  iex> {:ok, img} = Image.build_image(10, 10, [10, 10, 10, 10])
  iex> Image.interpretation(img)
  :VIPS_INTERPRETATION_sRGB
  iex> {:ok, img} = Image.build_image(10, 10, [10, 10, 10, 10], interpretation: :VIPS_INTERPRETATION_MULTIBAND)
  iex> Image.interpretation(img)
  :VIPS_INTERPRETATION_MULTIBAND
  ```

  Correctly sets format
  ```elixir
  iex> {:ok, img} = Image.build_image(1, 2, [10, 9, 220])
  iex> Image.format(img)
  :VIPS_FORMAT_UCHAR
  iex> {:ok, img} = Image.build_image(10, 10, [10, -120, 200])
  iex> Image.format(img)
  :VIPS_FORMAT_SHORT
  iex> {:ok, img} = Image.build_image(10, 10, [10, -120, 1.0])
  iex> Image.format(img)
  :VIPS_FORMAT_DOUBLE
  iex> {:ok, img} = Image.build_image(10, 10, [10, -40000, 39])
  iex> Image.format(img)
  :VIPS_FORMAT_INT
  iex> {:ok, img} = Image.build_image(10, 10, [10, -80, 10], format: :VIPS_FORMAT_CHAR)
  iex> Image.format(img)
  :VIPS_FORMAT_CHAR
  ```


  """
  @spec build_image(
          pos_integer,
          pos_integer,
          [number],
          opts :: [
            interpretation: Vix.Vips.Operation.vips_interpretation() | :auto,
            format: Vix.Vips.Operation.vips_band_format() | :auto
          ]
        ) :: {:ok, t()} | {:error, term()}
  def build_image(width, height, background \\ [0, 0, 0], opts \\ []) do
    opts = handle_build_image_opts(opts, background, interpretation: :auto, format: :auto)
    # cast values to float, `linear` accept only floats
    background = Enum.map(background, &(&1 * 1.0))

    with {:ok, blank_pixel} <- Operation.black(1, 1, bands: length(background)),
         {:ok, pixel} <- Operation.linear(blank_pixel, [1.0], background),
         {:ok, pixel} <- Operation.cast(pixel, opts[:format]),
         {:ok, img} <- Operation.embed(pixel, 0, 0, width, height, extend: :VIPS_EXTEND_COPY) do
      Operation.copy(img, interpretation: opts[:interpretation])
    end
  end

  @doc """
  Builds an Image

  Same as `build_image/3` but raises error instead of returning it.

  ## Examples

  ```elixir
  iex> img = Image.build_image!(1, 2, [10])
  iex> Image.to_list(img)
  {:ok, [[[10]], [[10]]]}
  iex> Image.shape(img)
  {1, 2, 1}
  ```

  See `build_image/3` for more detailed examples.
  """
  @spec build_image!(pos_integer, pos_integer, [number]) :: t() | no_return
  def build_image!(width, height, background \\ [0, 0, 0]) do
    case build_image(width, height, background) do
      {:ok, img} -> img
      {:error, reason} -> raise Error, message: inspect(reason)
    end
  end

  @doc """
  Opens `path` for reading, returns an instance of `t:Vix.Vips.Image.t/0`

  It can load files in many image formats, including VIPS, TIFF, PNG,
  JPEG, FITS, Matlab, OpenEXR, CSV, WebP, Radiance, RAW, PPM and
  others.

  Optional param `opts` is passed to the image loader. Available
  options depends on the file format. You can find all options
  available for a format under operation function in
  [Operation](./search.html?q=load+-buffer+-filename+-profile) module.

  For example, you can find all of the options supported by
  JPEG under `Vix.Vips.Operation.jpegload/2` function documentation.

  ```elixir
  Image.new_from_file("fred.jpg", shrink: 2)
  ```

  Opens "fred.jpg", downsampling by a factor of two.

  > #### Loading is fast {: .info}
  > Only enough of the image is loaded to the memory to be able to
  > fill out the header. Pixels will only be decompressed when they are
  > needed.

  If you want more control over the loader, Use the specific format loader
  from `Vix.Vips.Operation`. For example for jpeg use
  `Vix.Vips.Operation.jpegload/2`
  """
  @spec new_from_file(String.t(), keyword) :: {:ok, t()} | {:error, term()}

  @doc since: "0.31.0"
  def new_from_file(path, opts) do
    with {:ok, path} <- normalize_path(path),
         {:ok, loader} <- Vix.Vips.Foreign.find_load(path),
         {:ok, {ref, _optional}} <- Operation.Helper.operation_call(loader, [path], opts) do
      {:ok, wrap_type(ref)}
    end
  end

  # TODO: deprecate accepting suffix options
  def new_from_file(path) do
    path = normalize_string(Path.expand(path))

    Nif.nif_image_new_from_file(path)
    |> wrap_type()
  end

  @doc """
  Create a new image based on an existing image with each pixel set to `value`

  Creates a new image with width, height, format, interpretation,
  resolution and offset taken from the input image, but with each band
  set from `value`.
  """
  @spec new_from_image(t(), [number()]) :: {:ok, t()} | {:error, term()}
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
  @spec new_from_buffer(binary(), keyword()) :: {:ok, t()} | {:error, term()}
  def new_from_buffer(bin, opts \\ []) do
    with {:ok, loader} <- Vix.Vips.Foreign.find_load_buffer(bin),
         {:ok, {ref, _optional}} <- Operation.Helper.operation_call(loader, [bin], opts) do
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
        ) :: {:ok, t()} | {:error, term()}
  def new_from_binary(bin, width, height, bands, band_format)
      when width > 0 and height > 0 and bands > 0 do
    band_format = Vix.Vips.Enum.VipsBandFormat.to_nif_term(band_format, nil)

    Nif.nif_image_new_from_binary(bin, width, height, bands, band_format)
    |> wrap_type()
  end

  @doc """
  Create a new image from Enumerable.

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
  @spec new_from_enum(Enumerable.t(), String.t()) :: {:ok, t()} | {:error, term()}
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
                log_warn("argument must be stream of iodata")
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
  @spec write_to_stream(t(), String.t()) :: Enumerable.t()
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

  @doc """
  Converts an Image to a nested list.

  Returns a nested list of the shape `height x width x band`.
  For example for an image with height 10, width 5, and 3 bands
  returned value will be a list of length 10 (height), with each
  element will be a list of length 5 (height), and each
  element inside that will be a list of length 3 (bands).


  > #### Caution {: .warning}
  > This is meant to be used for very small images such as histograms, and
  > matrix. Depending on the image size it can generate and return a large
  > list leading to performance issues.


  ```elixir
  histogram =
    Vix.Vips.Operation.black!(10, 50)
    |> Vix.Vips.Operation.hist_find!()

  list = Vix.Vips.Image.to_list(histogram)
  ```
  """
  @spec to_list(t()) :: {:ok, list(list(list(number())))} | {:error, term}
  def to_list(%Image{} = image) do
    with {:ok, binary} <- write_to_binary(image) do
      width = width(image)
      bands = bands(image)

      list =
        binary_to_list(binary, format(image))
        |> Enum.chunk_every(bands)
        |> Enum.chunk_every(width)

      {:ok, list}
    end
  end

  @doc """
  Same as `to_list!/1` but raises error instead of returning it.
  """
  @spec to_list!(Image.t()) :: list(list(list(number()))) | no_return
  def to_list!(%Image{} = image) do
    case to_list(image) do
      {:ok, list} -> list
      {:error, reason} -> raise Error, reason
    end
  end

  @doc """
  Returns list of supported extension for *saving* the image.

  Supported suffix can be used to save image in a particular format.
  See `write_to_file/2`.

  Note that the image format supported for saving the image and the
  format supported for loading image might be different. For example
  SVG format can be loaded but can not be saved.
  """
  @spec supported_saver_suffixes :: {:ok, [String.t()]} | {:error, term}
  def supported_saver_suffixes, do: Vix.Vips.Foreign.get_suffixes()

  # This function should *NOT* be used to get list of formats vix can load.
  # libvips reads the file header to decide the loader to use.
  # see: https://github.com/libvips/ruby-vips/issues/186#issuecomment-466763897
  @doc false
  @spec supported_loader_suffixes :: {:ok, [String.t()]} | {:error, term}
  def supported_loader_suffixes, do: Vix.Vips.Foreign.get_loader_suffixes()

  # Copy an image to a memory area.
  # If image is already a memory buffer, just ref and return. If it's
  # a file on disc or a partial, allocate memory and copy the image to
  # it. Intended to be used with draw operations when they are
  # properly supported
  @doc false
  @spec copy_memory(t()) :: {:ok, t()} | {:error, term()}
  def copy_memory(%Image{ref: vips_image}) do
    Nif.nif_image_copy_memory(vips_image)
    |> wrap_type()
  end

  @doc """
  Write `t:Vix.Vips.Image.t/0` to a file.

  The image format is selected based on image extension in `path`.

  Optional param `opts` is passed to the image saver. Available
  options depends on the file format. You can find all options
  available for a format under operation function in
  [Operation](./search.html?q=save+-buffer+-filename+-profile) module.

  For example, you can find all of the options supported by JPEG saver
  undre `Vix.Vips.Operation.jpegsave/3` function documentation.

  ```elixir
  # save with Quality set to 90
  Image.write_to_file(vips_image, "fred.jpg", Q: 90)
  ```

  If you want more control over the saver, Use specific format saver
  from `Vix.Vips.Operation`. For example for jpeg use
  `Vix.Vips.Operation.jpegsave/2`

  """
  @spec write_to_file(t(), String.t(), keyword) :: :ok | {:error, term()}

  @doc since: "0.32.0"
  def write_to_file(%Image{ref: _} = image, path, opts) do
    path = normalize_string(Path.expand(path))

    case Vix.Vips.Foreign.find_save(path) do
      {:ok, saver} ->
        Operation.Helper.operation_call(saver, [image, path], opts)

      error ->
        error
    end
  end

  def write_to_file(%Image{ref: vips_image}, path) do
    path = normalize_string(Path.expand(path))
    Nif.nif_image_write_to_file(vips_image, path)
  end

  @doc """
  Returns `t:Vix.Vips.Image.t/0` as a binary based on the format specified by `suffix`.

  This function is similar to `write_to_file` but instead of writing
  the output to the file, it returns it as a binary.

  Optional param `opts` is passed to the image saver. Available
  options depends on the file format. You can find all options
  available for a format under operation function in
  [Operation](./search.html?q=save+buffer+-filename+-profile) module.

  For example, you can find all of the options supported by JPEG saver
  undre `Vix.Vips.Operation.jpegsave_buffer/2` function documentation.

  ```elixir
  # returns image in JPEG format as binary with Q factor set 90
  Image.write_to_buffer(img, ".jpg", [Q: 90])
  ```

  If you want more control over the saver, Use specific format saver
  from `Vix.Vips.Operation`. For example for jpeg use
  `Vix.Vips.Operation.jpegsave_buffer/2`
  """
  @spec write_to_buffer(t(), String.t(), keyword) :: {:ok, binary()} | {:error, term()}

  @doc since: "0.32.0"
  def write_to_buffer(%Image{ref: _} = image, suffix, opts) do
    case Vix.Vips.Foreign.find_save_buffer(normalize_string(suffix)) do
      {:ok, saver} ->
        Operation.Helper.operation_call(saver, [image], opts)

      error ->
        error
    end
  end

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

  Returned binary term will be in native endianness. By default
  bitstring treats byte order as `big` endian which might *not* be
  native. Always use `native` specifier to ensure. See [Elixir
  docs](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#%3C%3C%3E%3E/1-endianness)
  for more details.

  """
  @spec write_to_tensor(t()) :: {:ok, Vix.Tensor.t()} | {:error, term()}
  def write_to_tensor(%Image{} = image) do
    with {:ok, binary} <- write_to_binary(image) do
      tensor = %Vix.Tensor{
        data: binary,
        shape: {height(image), width(image), bands(image)},
        names: [:height, :width, :bands],
        type: Vix.Tensor.type(image)
      }

      {:ok, tensor}
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
  @spec write_to_binary(t()) :: {:ok, binary()} | {:error, term()}
  def write_to_binary(image) do
    case write_area_to_binary(image) do
      {:ok, %{binary: binary}} -> {:ok, binary}
      error -> error
    end
  end

  @doc """
  Returns the pixel value for the passed position

  Pixel value is a list of numbers. Size of the list depends on the
  number of bands in the image and number type will depend on the
  band format (see: `t:Vix.Vips.Operation.vips_band_format/0`).

  For example for RGBA image with unsigned char band format the
  return value will be a list of integer of size 4.

  This function is similar to `Vix.Vips.Operation.getpoint/3`,
  getpoint always returns the value as `float` but get_pixel returns
  based on the image band format.

  > #### Caution {: .warning}
  > Loop through lot of pixels using `get_pixel` can be expensive.
  > Use `extract_area` or Access syntax (slicing) instead

  """
  @spec get_pixel(t(), x :: non_neg_integer, y :: non_neg_integer) ::
          {:ok, [term]} | {:error, term()}
  def get_pixel(image, x, y) do
    unless x >= 0 and y >= 0 do
      raise ArgumentError, "Pixel position must be non-negative"
    end

    case write_area_to_binary(image, left: x, top: y, width: 1, height: 1) do
      {:ok, %{binary: binary, width: 1, height: 1, band_format: format}} ->
        {:ok, binary_to_list(binary, format)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Same as `get_pixel/3`. Returns the pixel value on success or raise the error.
  """
  @spec get_pixel!(t(), x :: non_neg_integer, y :: non_neg_integer) :: [term] | no_return
  def get_pixel!(image, x, y) do
    case get_pixel(image, x, y) do
      {:ok, list} -> list
      {:error, reason} when is_binary(reason) -> raise Error, reason
      {:error, reason} -> raise Error, inspect(reason)
    end
  end

  @spec write_area_to_binary(t(), params :: keyword) :: {:ok, map} | {:error, term()}
  defp write_area_to_binary(%Image{ref: vips_image}, params \\ []) do
    params =
      Enum.map(~w(left top width height band_start band_count)a, fn key ->
        params[key] || -1
      end)

    case Nif.nif_image_write_area_to_binary(vips_image, params) do
      {:ok, {binary, width, height, bands, band_format}} ->
        {:ok,
         %{
           binary: binary,
           width: width,
           height: height,
           bands: bands,
           band_format: Vix.Vips.Enum.VipsBandFormat.to_erl_term(band_format)
         }}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Make a VipsImage which, when written to, will create a temporary file on disc.

  The file will be automatically deleted when the image is destroyed. format is something like `"%s.v"` for a vips file.

  The file is created in the temporary directory. This is set with the environment variable TMPDIR. If this is not set, then on Unix systems, vips will default to `/tmp`. On Windows, vips uses `GetTempPath()` to find the temporary directory.

  ```elixir
  vips_image = Image.new_temp_file("%s.v")
  ```
  """
  @spec new_temp_file(String.t()) :: {:ok, t()} | {:error, term()}
  def new_temp_file(format) do
    Nif.nif_image_new_temp_file(normalize_string(format))
    |> wrap_type()
  end

  @doc """
  Make a VipsImage from 2D list.

  This is a convenience function makes an image which is a matrix: a one-band VIPS_FORMAT_DOUBLE image held in memory. Useful for vips operations such as `conv`.

  ```elixir
  {:ok, mask} = Image.new_matrix_from_array(3, 3, [[0, 1, 0], [1, 1, 1], [0, 1, 0]])
  ```

  ## Optional
  * scale - Default: 1
  * offset - Default: 0
  """
  @spec new_matrix_from_array(integer, integer, list(list), keyword()) ::
          {:ok, t()} | {:error, term()}
  def new_matrix_from_array(width, height, list, optional \\ []) do
    scale = to_double(optional[:scale], 1)
    offset = to_double(optional[:offset], 0)
    list = flatten_to_double_list(list)

    Nif.nif_image_new_matrix_from_array(width, height, list, scale, offset)
    |> wrap_type()
  end

  @doc """
  Make a VipsImage from 1D or 2D list.

  If list is a single dimension then an image of height 1 will be with list
  content as values.

  If list is 2D then 2D image will be created.

  Output image will always be a one band image with `double` format.

  ```elixir
  # 1D list
  {:ok, img2} = Image.new_from_list([0, 1, 0])

  # 2D list
  {:ok, img} = Image.new_from_list([[0, 1, 0], [1, 1, 1], [0, 1, 0]])
  ```

  ## Optional

  * scale - Default: 1
  * offset - Default: 0
  """
  @spec new_from_list(list([number]) | [number] | Range.t(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def new_from_list(list, optional \\ []) do
    with {:ok, {width, height, list}} <- validate_matrix_list(list) do
      scale = to_double(optional[:scale], 1)
      offset = to_double(optional[:offset], 0)

      Nif.nif_image_new_matrix_from_array(width, height, list, scale, offset)
      |> wrap_type()
    end
  end

  @doc """
  Mutate an image in-place. You have to pass a function which takes MutableImage as argument. Inside the callback function, you can call functions which modify the image, such as setting or removing metadata. See `Vix.Vips.MutableImage`

  Return value of the callback must be one of:

  * The mutated image passed to the callback or
  * `:ok` or
  * `{:ok, some_result}`

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
  @spec mutate(t(), (Vix.Vips.MutableImage.t() -> any())) ::
          {:ok, t()} | {:ok, {t(), any()}} | {:error, term()}
  def mutate(%Image{} = image, callback) do
    {:ok, %{pid: pid} = mut_image} = MutableImage.new(image)

    try do
      case callback.(mut_image) do
        %MutableImage{pid: ^pid} ->
          MutableImage.to_image(mut_image)

        :ok ->
          MutableImage.to_image(mut_image)

        {:ok, result} ->
          {:ok, image} = MutableImage.to_image(mut_image)
          {:ok, {image, result}}
      end
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
  @spec has_alpha?(t()) :: boolean | no_return()
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
  @spec header_field_names(t()) :: {:ok, [String.t()]} | {:error, term()}
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
  @spec header_value(t(), String.t()) ::
          {:ok, integer() | float() | String.t() | binary() | list() | atom()} | {:error, term()}
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
  @spec header_value_as_string(t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def header_value_as_string(%Image{ref: vips_image}, name) do
    Nif.nif_image_get_as_string(vips_image, normalize_string(name))
  end

  for {name, spec} <- %{
        "width" => quote(do: pos_integer()),
        "height" => quote(do: pos_integer()),
        "bands" => quote(do: pos_integer()),
        "xres" => quote(do: float()),
        "yres" => quote(do: float()),
        "xoffset" => quote(do: integer()),
        "yoffset" => quote(do: integer()),
        "filename" => quote(do: String.t()),
        "mode" => quote(do: String.t()),
        "scale" => quote(do: float()),
        "offset" => quote(do: float()),
        "page-height" => quote(do: integer()),
        "n-pages" => quote(do: integer()),
        "orientation" => quote(do: integer()),
        "interpretation" => quote(do: Vix.Vips.Operation.vips_interpretation()),
        "coding" => quote(do: Vix.Vips.Operation.vips_coding()),
        "format" => quote(do: Vix.Vips.Operation.vips_band_format())
      } do
    func_name = name |> String.replace("-", "_") |> String.to_atom()

    @doc """
    Get "#{name}" of the image

    > #### More details {: .tip}
    >
    > See [libvips docs](https://libvips.github.io/libvips/API/current/libvips-header.html#vips-image-get-#{name}) for more details regarding `#{func_name}` function

    """
    @spec unquote(func_name)(__MODULE__.t()) :: unquote(spec) | no_return()
    def unquote(func_name)(image) do
      case header_value(image, unquote(name)) do
        {:ok, value} -> value
        {:error, error} -> raise to_string(error)
      end
    end
  end

  @doc """
  Get all image header data as map. Headers includes metadata such as image height, width, bands.

  If a header does not exists then value for that header will be set to `nil`.

  See https://libvips.github.io/libvips/API/current/libvips-header.html for more details.
  """
  @spec headers(t()) :: %{
          width: pos_integer() | nil,
          height: pos_integer() | nil,
          bands: pos_integer() | nil,
          xres: float() | nil,
          yres: float() | nil,
          xoffset: integer() | nil,
          yoffset: integer() | nil,
          filename: String.t() | nil,
          mode: String.t() | nil,
          scale: float() | nil,
          offset: float() | nil,
          "page-height": integer() | nil,
          "n-pages": integer() | nil,
          orientation: integer() | nil,
          interpretation: Vix.Vips.Operation.vips_interpretation() | nil,
          coding: Vix.Vips.Operation.vips_coding() | nil,
          format: Vix.Vips.Operation.vips_band_format() | nil
        }
  def headers(image) do
    [
      :width,
      :height,
      :bands,
      :xres,
      :yres,
      :xoffset,
      :yoffset,
      :filename,
      :mode,
      :scale,
      :offset,
      :"page-height",
      :"n-pages",
      :orientation,
      :interpretation,
      :coding,
      :format
    ]
    |> Map.new(fn field ->
      case header_value(image, to_string(field)) do
        {:ok, value} -> {field, value}
        {:error, _} -> {field, nil}
      end
    end)
  end

  @doc """
  Returns 3 element tuple representing `{width, height, number_of_bands}`

  ## Examples

  ```elixir
  iex> img = Image.build_image!(100, 200, [1, 2, 3])
  iex> Image.shape(img)
  {100, 200, 3}
  ```
  """
  @spec shape(Image.t()) :: {pos_integer, pos_integer, pos_integer}
  def shape(%Image{} = image) do
    {Image.width(image), Image.height(image), Image.bands(image)}
  end

  defp normalize_string(str) when is_binary(str), do: str

  defp normalize_string(str) when is_list(str), do: to_string(str)

  defp normalize_list(%Range{} = range), do: Enum.to_list(range)

  defp normalize_list(list) when is_list(list) do
    Enum.map(list, &normalize_list/1)
  end

  defp normalize_list(term), do: term

  defp to_double(v) when is_integer(v), do: v * 1.0
  defp to_double(v) when is_float(v), do: v

  defp to_double(nil, default), do: to_double(default)
  defp to_double(v, _default), do: to_double(v)

  defp wrap_type({:ok, ref}), do: {:ok, %Image{ref: ref}}
  defp wrap_type(value), do: value

  defp normalize_access_args(args) do
    cond do
      Keyword.keyword?(args) ->
        {:ok, Keyword.take(args, ~w(width height band)a)}

      length(args) <= 3 && Enum.all?(args, &(is_integer(&1) || match?(%Range{}, &1))) ->
        {:ok, Enum.zip(~w(width height band)a, args)}

      true ->
        {:error, :invalid_list}
    end
  end

  @spec validate_matrix_list([[number]] | [number] | Range.t()) ::
          {:ok, {width :: non_neg_integer(), height :: non_neg_integer(), [number]}}
          | {:error, term}
  defp validate_matrix_list(list) do
    list = normalize_list(list)

    result =
      cond do
        !is_list(list) ->
          {:error, "argument is not a list"}

        length(list) > 0 && is_list(hd(list)) ->
          height = length(list)
          width = length(hd(list))

          cond do
            !Enum.all?(list, &is_list/1) ->
              {:error, "not a 2D list"}

            !Enum.all?(list, &(length(&1) == width)) ->
              {:error, "list is not rectangular"}

            true ->
              {:ok, {width, height, flatten_to_double_list(list)}}
          end

        true ->
          {:ok, {length(list), 1, cast_to_double_list(list)}}
      end

    with {:ok, {width, height, list}} <- result,
         :ok <- validate_list_dimension(width, height, list),
         :ok <- validate_list_contents(list) do
      {:ok, {width, height, list}}
    end
  end

  defp validate_list_dimension(width, height, list) do
    if length(list) == width * height do
      :ok
    else
      {:error, "bad list dimensions"}
    end
  end

  defp validate_list_contents(list) do
    if Enum.all?(list, &is_number/1) do
      :ok
    else
      {:error, "not all list elements are number"}
    end
  end

  defp cast_to_double_list(list) do
    Enum.map(list, &to_double/1)
  end

  defp flatten_to_double_list(list) do
    Enum.flat_map(list, &cast_to_double_list(&1))
  end

  # Support for rendering images in Livebook

  if Code.ensure_loaded?(Kino.Render) do
    defimpl Kino.Render do
      alias Vix.Vips.Image

      def to_livebook(image) do
        {:ok, buf} = Image.write_to_buffer(image, ".png")

        Kino.Layout.grid([Kino.Image.new(buf, "image/png"), image_info(image)])
        |> Kino.Render.to_livebook()
      end

      defp image_info(image) do
        height = Image.height(image)
        width = Image.width(image)

        filename =
          case Image.header_value(image, "filename") do
            {:ok, filename} -> Path.basename(filename)
            {:error, _} -> ""
          end

        """
        <span style="color: #61758a; background-color: #e1e8f0; border-radius: .5rem; padding: .1rem;">
          <code style="padding: .5rem; vertical-align: middle; line-height: 1.25rem;">
            #{filename},  #{width}x#{height} #{format(image)},  #{Image.bands(image)} bands,  #{interpretation(image)}
          </code>
        </span>
        """
        |> Kino.HTML.new()
      end

      # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
      defp format(image) do
        case Image.format(image) do
          :VIPS_FORMAT_UCHAR -> "8-bit unsigned integer"
          :VIPS_FORMAT_CHAR -> "8-bit signed integer"
          :VIPS_FORMAT_USHORT -> "16-bit unsigned integer"
          :VIPS_FORMAT_SHORT -> "16-bit signed integer"
          :VIPS_FORMAT_UINT -> "32-bit unsigned integer"
          :VIPS_FORMAT_INT -> "32-bit signed integer"
          :VIPS_FORMAT_FLOAT -> "32-bit float"
          :VIPS_FORMAT_COMPLEX -> "64-bit complex"
          :VIPS_FORMAT_DOUBLE -> "64-bit float"
          :VIPS_FORMAT_DPCOMPLEX -> "128-bit complex"
        end
      end

      # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
      defp interpretation(image) do
        case Image.interpretation(image) do
          :VIPS_INTERPRETATION_MULTIBAND -> "multiband"
          :VIPS_INTERPRETATION_B_W -> "mono"
          :VIPS_INTERPRETATION_HISTOGRAM -> "histogram"
          :VIPS_INTERPRETATION_XYZ -> "XYZ"
          :VIPS_INTERPRETATION_LAB -> "Lab"
          :VIPS_INTERPRETATION_CMYK -> "CMYK"
          :VIPS_INTERPRETATION_LABQ -> "LabQ"
          :VIPS_INTERPRETATION_RGB -> "RGB"
          :VIPS_INTERPRETATION_CMC -> "CMC"
          :VIPS_INTERPRETATION_UCS -> "UCS"
          :VIPS_INTERPRETATION_LCH -> "LCh"
          :VIPS_INTERPRETATION_LABS -> "LabS"
          :VIPS_INTERPRETATION_sRGB -> "sRGB"
          :VIPS_INTERPRETATION_YXY -> "Yxy"
          :VIPS_INTERPRETATION_FOURIER -> "Fourier"
          :VIPS_INTERPRETATION_RGB16 -> "RGB16"
          :VIPS_INTERPRETATION_GREY16 -> "GREY16"
          :VIPS_INTERPRETATION_MATRIX -> "Matrix"
          :VIPS_INTERPRETATION_HSV -> "HSV"
          :VIPS_INTERPRETATION_ARRAY -> "Array"
          :VIPS_INTERPRETATION_scRGB -> "scRGB"
          interpretation -> String.trim_leading(to_string(interpretation), "VIPS_INTERPRETATION_")
        end
      end
    end
  end

  @spec binary_to_list(binary(), Vix.Vips.Enum.VipsBandFormat.t()) :: [number()]
  defp binary_to_list(binary, :VIPS_FORMAT_UCHAR) do
    for <<band::native-unsigned-integer-8 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_CHAR) do
    for <<band::native-signed-integer-8 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_USHORT) do
    for <<band::native-unsigned-integer-16 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_SHORT) do
    for <<band::native-signed-integer-16 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_UINT) do
    for <<band::native-unsigned-native-integer-32 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_INT) do
    for <<band::native-signed-integer-32 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_FLOAT) do
    for <<band::native-float-32 <- binary>>, do: band
  end

  defp binary_to_list(binary, :VIPS_FORMAT_DOUBLE) do
    for <<band::native-float-64 <- binary>>, do: band
  end

  if Kernel.macro_exported?(Logger, :warning, 1) do
    defp log_warn(msg), do: Logger.warning(msg)
  else
    defp log_warn(msg), do: Logger.warn(msg)
  end

  @spec normalize_path(String.t()) :: {:ok, String.t()} | {:error, :invalid_path}
  defp normalize_path(path) do
    path =
      path
      |> Path.expand()
      |> normalize_string()

    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :invalid_path}
    end
  end

  @spec handle_build_image_opts(keyword, [number], keyword) :: %{
          interpretation: Vix.Vips.Operation.vips_interpretation(),
          format: Vix.Vips.Operation.vips_band_format()
        }
  defp handle_build_image_opts(opts, background, defaults) do
    opts = Keyword.validate!(opts, defaults)
    bands = length(background)

    if bands == 0 do
      raise ArgumentError, "background must not be empty"
    end

    interpretation =
      if opts[:interpretation] == :auto do
        guess_interpretation(bands)
      else
        opts[:interpretation]
      end

    format =
      if opts[:format] == :auto do
        guess_format(background)
      else
        opts[:format]
      end

    %{interpretation: interpretation, format: format}
  end

  @spec guess_interpretation(pos_integer) :: Vix.Vips.Operation.vips_interpretation()
  defp guess_interpretation(bands) do
    cond do
      bands == 4 -> :VIPS_INTERPRETATION_sRGB
      bands == 3 -> :VIPS_INTERPRETATION_RGB
      bands == 1 -> :VIPS_INTERPRETATION_B_W
      true -> :VIPS_INTERPRETATION_MULTIBAND
    end
  end

  @spec guess_format([number]) :: Vix.Vips.Operation.vips_band_format()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp guess_format(background) do
    types = Enum.map(background, &guess_num_type/1)

    max_sizes =
      types
      |> Enum.group_by(fn {type, _} -> type end, fn {_, size} -> size end)
      |> Map.new(fn {type, sizes} -> {type, Enum.max(sizes)} end)

    max_signed = max_sizes[:s]
    max_unsigned = max_sizes[:u]
    max_float = max_sizes[:f]

    cond do
      max_float -> {:f, max_float}
      !max_signed && !max_unsigned -> raise ArgumentError
      max_signed && !max_unsigned -> {:s, max_signed}
      !max_signed && max_unsigned -> {:u, max_unsigned}
      max_signed > max_unsigned -> {:s, max_signed}
      # ex: [-100, 250] the size should be `{:s, 16}`
      max_signed <= max_unsigned -> {:s, max_signed * 2}
    end
    |> type_to_vips_band_format()
  end

  @typep allowed_types ::
           {:u, 8 | 16 | 32}
           | {:s, 8 | 16 | 32}
           | {:f, 64}

  @spec guess_num_type(number) :: allowed_types
  defp guess_num_type(num) do
    cond do
      is_integer(num) && num >= 0 ->
        {:u, bsize(num)}

      is_integer(num) ->
        {:s, bsize(num)}

      is_float(num) ->
        # currently we treat all float values as 64bit
        {:f, 64}
    end
  end

  @spec type_to_vips_band_format(allowed_types) :: Vix.Vips.Operation.vips_band_format()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp type_to_vips_band_format(type) do
    case type do
      {:u, 8} ->
        :VIPS_FORMAT_UCHAR

      {:s, 8} ->
        :VIPS_FORMAT_CHAR

      {:u, 16} ->
        :VIPS_FORMAT_USHORT

      {:s, 16} ->
        :VIPS_FORMAT_SHORT

      {:u, 32} ->
        :VIPS_FORMAT_UINT

      {:s, 32} ->
        :VIPS_FORMAT_INT

      {:f, 32} ->
        :VIPS_FORMAT_FLOAT

      {:f, 64} ->
        :VIPS_FORMAT_DOUBLE

      {_, _} = type ->
        raise ArgumentError, "#{type} is not supported"
    end
  end

  @spec bsize(integer) :: 8 | 16 | 32
  defp bsize(int) do
    # negative values there will be additional
    # prefix char `-` which should take care of signed-bit
    size = Integer.to_string(int, 2) |> byte_size()

    cond do
      size <= 8 -> 8
      size <= 16 -> 16
      size <= 32 -> 32
      true -> raise ArgumentError, "integer size must be <= 32bit"
    end
  end
end
