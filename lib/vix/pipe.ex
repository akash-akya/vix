defmodule Vix.Pipe do
  use GenServer
  require Logger

  alias Vix.Nif
  alias __MODULE__

  @moduledoc false

  defstruct [:mode, :read_fd, :write_fd, :write, :read, :source, :target, :error]

  defmodule Pending do
    @moduledoc false

    defstruct bin: [], size: nil, client_pid: nil
  end

  defmodule Error do
    defexception [:message]
  end

  @default_buffer_size 65535

  def new_vips_target do
    {:ok, readable_pipe} = start_link(:read)
    target = GenServer.call(readable_pipe, :target, :infinity)
    {readable_pipe, target}
  end

  def new_vips_source do
    {:ok, writable_pipe} = start_link(:write)
    source = GenServer.call(writable_pipe, :source, :infinity)
    {writable_pipe, source}
  end

  def read(process, max_size \\ @default_buffer_size)
      when is_integer(max_size) and max_size > 0 do
        IO.puts "Reading"
    case GenServer.call(process, {:read, max_size}, :infinity) do
      :eof -> :eof
      {:ok, result} -> {:ok, result}
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  def write(pipe, iodata) do
    case GenServer.call(pipe, {:write, IO.iodata_to_binary(iodata)}, :infinity) do
      {:error, reason} -> raise ArgumentError, message: reason
      other -> other
    end
  end

  def error(pipe, reason) do
    GenServer.call(pipe, {:error, reason}, :infinity)
  end

  def start_link(mode) do
    GenServer.start(__MODULE__, mode)
  end

  def stop(pipe) do
    GenServer.stop(pipe)
  end

  # GenServer

  def init(mode) do
    {:ok, nil, {:continue, mode}}
  end

  def handle_continue(:write, _) do
    case Nif.nif_source_new() do
      {:ok, {write_fd, source}} ->
        state = %__MODULE__{mode: :write, write_fd: write_fd, source: source, write: %Pending{}}
        {:noreply, state}

      {:error, reason} ->
        {:stop, reason, nil}
    end
  end

  def handle_continue(:read, _) do
    case Nif.nif_target_new() do
      {:ok, {read_fd, target}} ->
        state = %__MODULE__{mode: :read, read_fd: read_fd, target: target, read: %Pending{}}
        {:noreply, state}

      {:error, reason} ->
        {:stop, reason, nil}
    end
  end

  def handle_call({:read, size}, from, %__MODULE__{mode: :read} = state) do
    cond do
      state.read.client_pid ->
        GenServer.reply(from, {:error, :pending_read})
        {:noreply, state}

      true ->
        pending = %Pending{size: size, client_pid: from}
        do_read(%Pipe{state | read: pending})
    end
  end

  def handle_call({:read, _size}, from, %__MODULE__{mode: :error, error: reason}) do
    GenServer.reply(from, {:error, reason})
  end

  def handle_call({:write, binary}, from, %__MODULE__{mode: :write} = state) do
    cond do
      !is_binary(binary) ->
        {:reply, {:error, :not_binary}, state}

      state.write.client_pid ->
        {:reply, {:error, :pending_write}, state}

      true ->
        pending = %Pending{bin: binary, client_pid: from}
        do_write(%__MODULE__{state | write: pending})
    end
  end

  def handle_call({:write, _size}, from, %__MODULE__{mode: :error, error: reason}) do
    GenServer.reply(from, {:error, reason})
  end

  def handle_call(:source, _from, %__MODULE__{mode: :write, source: source} = state) do
    {:reply, source, %__MODULE__{state | source: nil}}
  end

  def handle_call(:target, _from, %__MODULE__{mode: :read, target: target} = state) do
    {:reply, target, %__MODULE__{state | target: nil}}
  end

  def handle_call({:error, reason}, _from, %__MODULE__{mode: :write, source: source} = state) do
    {:reply, source, %{state | mode: :error, error: reason}}
  end

  def handle_call({:error, reason}, _from, %__MODULE__{mode: :read, target: target} = state) do
    {:reply, target, %{state | mode: :error, error: reason}}
  end

  def handle_info({:select, _write_resource, _ref, :ready_output}, state) do
    do_write(state)
  end

  def handle_info({:select, _read_resource, _ref, :ready_input}, state) do
    do_read(state)
  end

  defmacrop eof, do: {:ok, <<>>}
  defmacrop eagain, do: {:error, :eagain}

  defp do_read(%Pipe{mode: :read, read: pending} = state) do
    case Nif.nif_read(state.read_fd, pending.size) do
      eof() ->
        reply_action(state, :read, :eof)

      {:ok, binary} ->
        reply_action(state, :read, {:ok, binary})

      eagain() ->
        noreply_action(state)

      {:error, errno} ->
        reply_action(state, :read, {:error, errno})
    end
  end

  defp do_read(%Pipe{mode: :error, error: reason} = state) do
    reply_action(state, :error, {:error, reason})
  end

  defp do_write(%Pipe{mode: :write, write: %Pending{bin: <<>>}} = state) do
    reply_action(state, :write, :ok)
  end

  defp do_write(%Pipe{mode: :write, write: pending} = state) do
    bin_size = byte_size(pending.bin)

    case Nif.nif_write(state.write_fd, pending.bin) do
      {:ok, size} when size < bin_size ->
        binary = binary_part(pending.bin, size, bin_size - size)
        noreply_action(%{state | write: %Pending{pending | bin: binary}})

      {:ok, _size} ->
        reply_action(state, :write, :ok)

      eagain() ->
        noreply_action(state)

      {:error, errno} ->
        reply_action(state, :write, {:error, errno})
    end
  end

  defp reply_action(state, action, ret) do
    pending = Map.fetch!(state, action)
    :ok = GenServer.reply(pending.client_pid, ret)

    {:noreply, Map.put(state, action, %Pending{})}
  end

  defp noreply_action(state) do
    {:noreply, state}
  end
end
