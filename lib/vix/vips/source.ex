defmodule Vix.Vips.Source do
  @moduledoc """
  *NOT supported yet*
  """

  alias Vix.Type

  @behaviour Type
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
  def to_nif_term(_value, _data), do: raise("VipsSource is not implemented yet")

  @impl Type
  def to_erl_term(_value), do: raise("VipsSource is not implemented yet")

  # server
  use GenServer

  alias Vix.Nif

  def new_from_file(path) do
    {:ok, pid} = start_link(path)
    source = GenServer.call(pid, :source)
    {:ok, source}
  end

  def start_link(path) do
    GenServer.start(__MODULE__, [path])
  end

  @impl true
  def init(path) do
    {:ok, source} = Nif.nif_vips_source_new()
    {:ok, %{path: path, source: source}, {:continue, nil}}
  end

  @impl true
  def handle_continue(nil, state) do
    file = File.open!(state.path, [:read, :binary, :raw])
    {:noreply, Map.put(state, :handle, file)}
  end

  @impl true
  def handle_call(:source, _from, state) do
    {:reply, state.source, state}
  end

  @impl true
  def handle_info(:close, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:read, length, result}, state) do
    {:ok, data} = :file.read(state.handle, length)
    # IO.puts("--> writing #{length} - #{IO.iodata_length(data)}")
    :ok = Nif.nif_vips_conn_write_result(data, result)
    {:noreply, state}
  end
end
