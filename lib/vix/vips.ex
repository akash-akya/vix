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
  Get installed vips version
  """
  @spec version() :: String.t()
  def version do
    {major, minor, micro} = Nif.nif_vips_version()
    "#{major}.#{minor}.#{micro}"
  end
end
