defmodule Vix.TargetPipe do
  use GenServer
  require Logger

  alias Vix.Nif
  alias __MODULE__

  @moduledoc false

  defstruct [:fd, :pending, :task_result, :task_pid]

  defmodule Pending do
    @moduledoc false
    defstruct size: nil, client_pid: nil
  end

  @default_buffer_size 65535

  def new(vips_image, suffix) do
    GenServer.start_link(__MODULE__, %{image: vips_image, suffix: suffix})
  end

  def read(process, max_size \\ @default_buffer_size)
      when is_integer(max_size) and max_size > 0 do
    GenServer.call(process, {:read, max_size}, :infinity)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server

  def init(%{image: image, suffix: suffix}) do
    Process.flag(:trap_exit, true)
    {:ok, nil, {:continue, %{image: image, suffix: suffix}}}
  end

  def handle_continue(%{image: image, suffix: suffix}, _) do
    case Nif.nif_target_new() do
      {:ok, {fd, target}} ->
        pid = start_task(image, target, suffix)
        {:noreply, %TargetPipe{fd: fd, task_pid: pid, pending: %Pending{}}}

      {:error, reason} ->
        {:stop, reason, nil}
    end
  end

  def handle_call({:read, size}, from, %TargetPipe{pending: %Pending{client_pid: nil}} = state) do
    do_read(%TargetPipe{state | pending: %Pending{size: size, client_pid: from}})
  end

  def handle_call({:read, _size}, _from, state) do
    {:reply, {:error, :pending_read}, state}
  end

  def handle_info({:select, _read_resource, _ref, :ready_input}, state) do
    do_read(state)
  end

  def handle_info({:EXIT, from, result}, %{task_pid: from} = state) do
    do_read(%TargetPipe{state | task_result: result, task_pid: nil})
  end

  defmacrop eof, do: {:ok, <<>>}
  defmacrop eagain, do: {:error, :eagain}

  defp do_read(%TargetPipe{task_result: {:error, _reason} = error} = state) do
    reply_action(state, error)
  end

  defp do_read(%TargetPipe{pending: %{size: size}} = state) do
    case Nif.nif_read(state.fd, size) do
      eof() ->
        reply_action(state, :eof)

      {:ok, binary} ->
        reply_action(state, {:ok, binary})

      eagain() ->
        noreply_action(state)

      {:error, errno} ->
        reply_action(state, {:error, errno})
    end
  end

  defp reply_action(%TargetPipe{pending: pending} = state, ret) do
    if pending.client_pid do
      :ok = GenServer.reply(pending.client_pid, ret)
    end

    {:noreply, %TargetPipe{state | pending: %Pending{}}}
  end

  defp noreply_action(state) do
    {:noreply, state}
  end

  defp start_task(image, target, suffix) do
    spawn_link(fn ->
      result = Nif.nif_image_to_target(image, target, suffix)
      Process.exit(self(), result)
    end)
  end
end
