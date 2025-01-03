defmodule Vix.SourcePipe do
  use GenServer
  require Logger

  alias Vix.Nif
  alias __MODULE__

  @moduledoc false

  defstruct [:fd, :pending, :source]

  defmodule Pending do
    @moduledoc false
    defstruct bin: [], client_pid: nil
  end

  @spec new() :: {pid, Vix.Vips.Source.t()}
  def new do
    {:ok, pipe} = GenServer.start_link(__MODULE__, nil)
    source = GenServer.call(pipe, :source, :infinity)
    {pipe, source}
  end

  def write(pipe, bin) do
    GenServer.call(pipe, {:write, bin}, :infinity)
  end

  def stop(pipe) do
    GenServer.stop(pipe)
  end

  # Server

  def init(_) do
    {:ok, nil, {:continue, nil}}
  end

  def handle_continue(nil, _) do
    case Nif.nif_source_new() do
      {:ok, {fd, source}} ->
        source_pipe = %SourcePipe{
          fd: fd,
          pending: %Pending{},
          source: %Vix.Vips.Source{ref: source}
        }

        {:noreply, source_pipe}

      {:error, reason} ->
        {:stop, reason, nil}
    end
  end

  def handle_call(:source, _from, %SourcePipe{source: source} = state) do
    {:reply, source, state}
  end

  def handle_call({:write, binary}, from, %SourcePipe{pending: %Pending{client_pid: nil}} = state) do
    do_write(%SourcePipe{state | pending: %Pending{bin: binary, client_pid: from}})
  end

  def handle_call({:write, _binary}, _from, state) do
    {:reply, {:error, :pending_write}, state}
  end

  def handle_info({:select, _write_resource, _ref, :ready_output}, state) do
    do_write(state)
  end

  defmacrop eagain, do: {:error, :eagain}

  defp do_write(%SourcePipe{pending: %Pending{bin: <<>>}} = state) do
    reply_action(state, :ok)
  end

  defp do_write(%SourcePipe{pending: pending} = state) do
    bin_size = byte_size(pending.bin)

    case Nif.nif_write(state.fd, pending.bin) do
      {:ok, size} when size < bin_size ->
        binary = binary_part(pending.bin, size, bin_size - size)
        noreply_action(%{state | pending: %Pending{pending | bin: binary}})

      {:ok, _size} ->
        reply_action(state, :ok)

      eagain() ->
        noreply_action(state)

      {:error, errno} ->
        reply_action(state, {:error, errno})
    end
  end

  defp reply_action(%SourcePipe{pending: pending} = state, ret) do
    if pending.client_pid do
      :ok = GenServer.reply(pending.client_pid, ret)
    end

    {:noreply, %SourcePipe{state | pending: %Pending{}}}
  end

  defp noreply_action(state) do
    {:noreply, state}
  end
end
