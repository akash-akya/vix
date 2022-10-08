defmodule Vix.Vips do
  alias Vix.Nif

  @doc """
  Set the maximum number of operations we keep in cache.
  """
  @spec cache_set_max(integer()) :: :ok
  def cache_set_max(max) do
    Nif.nif_vips_cache_set_max(max)
  end

  @doc """
  Get the maximum number of operations we keep in cache.
  """
  @spec cache_get_max() :: integer()
  def cache_get_max do
    Nif.nif_vips_cache_get_max()
  end

  @doc """
  Sets the number of worker threads that vips should use when running a VipsThreadPool.

  The special value 0 means "default". In this case, the number of threads is set by the environment variable VIPS_CONCURRENCY, or if that is not set, the number of threads availble on the host machine.
  """
  @spec concurrency_set(integer()) :: :ok
  def concurrency_set(concurrency) do
    Nif.nif_vips_concurrency_set(concurrency)
  end

  @doc """
  Returns the number of worker threads that vips should use when running a VipsThreadPool.

  The final value is clipped to the range 1 - 1024.
  """
  @spec concurrency_get() :: {:ok, integer()}
  def concurrency_get do
    Nif.nif_vips_concurrency_get()
  end

  @doc """
  Set the maximum number of tracked files we allow before we start dropping cached operations.
  """
  @spec cache_set_max_files(integer()) :: :ok
  def cache_set_max_files(max_files) do
    Nif.nif_vips_cache_set_max_files(max_files)
  end

  @doc """
  Get the maximum number of tracked files we allow before we start dropping cached operations.

  libvips only tracks file descriptors it allocates, it can't track ones allocated by external libraries.
  """
  @spec cache_get_max_files() :: integer()
  def cache_get_max_files do
    Nif.nif_vips_cache_get_max_files()
  end

  @doc """
  Set the maximum amount of tracked memory we allow before we start dropping cached operations.

  libvips only tracks file descriptors it allocates, it can't track ones allocated by external libraries.
  """
  @spec cache_set_max_mem(integer()) :: :ok
  def cache_set_max_mem(max_mem) do
    Nif.nif_vips_cache_set_max_mem(max_mem)
  end

  @doc """
  Get the maximum amount of tracked memory we allow before we start dropping cached operations.
  """
  @spec cache_get_max_mem() :: integer()
  def cache_get_max_mem do
    Nif.nif_vips_cache_get_max_mem()
  end

  @doc """
  Get installed vips version
  """
  @spec version() :: String.t()
  def version do
    {major, minor, micro} = Nif.nif_vips_version()
    "#{major}.#{minor}.#{micro}"
  end

  # Support for rendering images in Livebook

  if Code.ensure_loaded?(Kino.Render) do
    defimpl Kino.Render, for: Vix.Vips.Image do
      def to_livebook(image) do
        attributes = attributes_from_image(image)
        {:ok, encoded} = Vix.Vips.Image.write_to_buffer(image, ".png")
        image = Kino.Image.new(encoded, :png)
        tabs = Kino.Layout.tabs("Attributes": attributes, "Image": image)
        Kino.Render.to_livebook(tabs)
      end

      def attributes_from_image(image) do
        data = [
          {"Width", Vix.Vips.Image.width(image)},
          {"Height", Vix.Vips.Image.height(image)},
          {"Bands", Vix.Vips.Image.bands(image)},
          {"Interpretation", Vix.Vips.Image.interpretation(image)},
          {"Format", Vix.Vips.Image.format(image)},
          {"Filename", Vix.Vips.Image.filename(image)},
          {"Orientation", Vix.Vips.Image.orientation(image)},
          {"Has alpha band?", Vix.Vips.Image.has_alpha?(image)}
        ]
        |> Enum.map(fn {k, v} -> [{"Attribute", k}, {"Value", v}] end)

        Kino.DataTable.new(data, name: "Image Metadata")
      end
    end
  end
end
