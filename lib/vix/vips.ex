defmodule Vix.Vips do
  @moduledoc """
  Module for Vix.Vips.
  """

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
  Get the number of operations in the cache.
  """
  @spec cache_get_size() :: integer()
  def cache_get_size do
    Nif.nif_vips_cache_get_size()
  end

  @doc """
  Sets the number of worker threads that vips should use when running a VipsThreadPool.

  The special value 0 means "default". In this case, the number of threads is set by the environment variable VIPS_CONCURRENCY, or if that is not set, the number of threads available on the host machine.
  """
  @spec concurrency_set(integer()) :: :ok
  def concurrency_set(concurrency) do
    Nif.nif_vips_concurrency_set(concurrency)
  end

  @doc """
  Returns the number of worker threads that vips should use when running a VipsThreadPool.

  The final value is clipped to the range 1 - 1024.
  """
  @spec concurrency_get() :: integer()
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
  Turn on or off vips leak checking
  """
  @spec set_vips_leak_checking(boolean()) :: :ok
  def set_vips_leak_checking(bool) when is_boolean(bool) do
    Nif.nif_vips_leak_set(if bool, do: 1, else: 0)
  end

  @doc """
  Returns the number of bytes currently allocated by libvips.

  Libvips uses this figure to decide when to start dropping cache.
  """
  @spec tracked_get_mem() :: integer()
  def tracked_get_mem do
    Nif.nif_vips_tracked_get_mem()
  end

  @doc """
  Returns the largest number of bytes simultaneously allocated via libvips.

  Handy for estimating max memory requirements for a program.
  """
  @spec tracked_get_mem_highwater() :: integer()
  def tracked_get_mem_highwater do
    Nif.nif_vips_tracked_get_mem_highwater()
  end

  @doc """
  Returns the number of active allocations tracked by libvips.
  """
  @spec tracked_get_allocs() :: integer()
  def tracked_get_allocs do
    Nif.nif_vips_tracked_get_allocs()
  end

  @doc """
  Returns the number of open files tracked by libvips.
  """
  @spec tracked_get_files() :: integer()
  def tracked_get_files do
    Nif.nif_vips_tracked_get_files()
  end

  @doc """
  Blocks or unblocks all operations libvips marks as untrusted.

  Untrusted operations, mostly loaders such as SVG and CSV, have not been
  tested against malicious input, and their docs in `Vix.Vips.Operation` say
  so. Block them before processing untrusted images. Setting the
  `VIPS_BLOCK_UNTRUSTED` environment variable has the same effect.

  Requires libvips 8.13 or later.
  """
  @spec block_untrusted_set(boolean()) :: :ok | {:error, String.t()}
  def block_untrusted_set(state) when is_boolean(state) do
    Nif.nif_vips_block_untrusted_set(state)
  end

  @doc """
  Blocks or unblocks an operation and all operations derived from it.

  `name` is an operation nickname, such as `"jpegload"`, or a class name,
  such as `"VipsForeignLoad"`. To allow only some loaders, use
  `allow_loaders/1`.

  Requires libvips 8.13 or later.
  """
  @spec operation_block_set(String.t(), boolean()) :: :ok | {:error, String.t()}
  def operation_block_set(name, state) when is_binary(name) and is_boolean(state) do
    Nif.nif_vips_operation_block_set(name, state)
  end

  @doc """
  Blocks all loaders except the ones for the given formats.

  libvips picks a loader by the file content, not the suffix, so this limits
  the formats that can be loaded. Each call replaces the previous one. Loads
  running during the call may fail, so call it at startup.

      :ok = Vix.Vips.allow_loaders([:jpeg, :png, :webp])

  See `loader_formats/0` for the available formats. To unblock all loaders,
  call `operation_block_set("VipsForeignLoad", false)`.

  Requires libvips 8.13 or later.
  """
  @spec allow_loaders([atom()]) :: :ok | {:error, String.t()}
  def allow_loaders(formats) when is_list(formats) do
    loaders = loaders()

    case formats -- Enum.map(loaders, & &1.format) do
      [] -> block_loaders_except(loaders, formats)
      unknown -> {:error, "Unknown loader formats: #{inspect(unknown)}"}
    end
  end

  defp block_loaders_except(loaders, formats) do
    with :ok <- operation_block_set("VipsForeignLoad", true) do
      loaders
      |> Enum.filter(&(&1.format in formats))
      |> Enum.each(&(:ok = operation_block_set(&1.nickname, false)))
    end
  end

  @doc """
  Returns the loader formats and their file suffixes.

      Vix.Vips.loader_formats()
      #=> %{jpeg: [".jfif", ".jpe", ".jpeg", ".jpg"], heif: [".avif", ".heic", ".heif"], ...}
  """
  @spec loader_formats() :: %{atom() => [String.t()]}
  def loader_formats do
    loaders()
    |> Enum.group_by(& &1.format, & &1.suffixes)
    |> Map.new(fn {format, suffixes} -> {format, suffixes |> List.flatten() |> Enum.sort()} end)
  end

  defp loaders do
    Enum.map(Nif.nif_foreign_get_loaders(), fn {nickname, suffixes} ->
      %{format: loader_format(nickname), nickname: nickname, suffixes: suffixes}
    end)
  end

  # loader nicknames are `<format>load`, `<format>load_buffer` and `<format>load_source`
  defp loader_format(nickname) do
    [format, _] = String.split(nickname, "load", parts: 2)
    String.to_atom(format)
  end

  @doc """
  Returns the nicknames of the blocked operations.
  """
  @spec blocked_operations() :: [String.t()]
  def blocked_operations do
    for {name, flags} <- Nif.nif_vips_operation_list(), :blocked in flags, do: name
  end

  @doc """
  Get installed vips version
  """
  @spec version() :: String.t()
  def version do
    {major, minor, micro} = Nif.nif_vips_version()
    "#{major}.#{minor}.#{micro}"
  end
end
