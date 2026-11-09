defmodule Vix.TargetPipe do
  use GenServer

  alias Vix.Nif
  alias Vix.Vips.Operation.Helper
  alias Vix.Vips.Target
  alias __MODULE__

  @moduledoc false

  @type t() :: struct

  # `pending` is the `{from, size}` of a read that is waiting for data
  defstruct [:pipe, :save_ref, :save_error, :pending, save_done: false]

  @default_buffer_size 65_536

  @spec new(Vix.Vips.Image.t(), String.t(), keyword) :: GenServer.on_start()
  def new(image, suffix, opts) do
    GenServer.start_link(__MODULE__, {image, suffix, opts})
  end

  def read(process, max_size \\ @default_buffer_size)
      when is_integer(max_size) and max_size > 0 do
    GenServer.call(process, {:read, max_size}, :infinity)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server

  def init(save) do
    # stop when the reader exits, even normally, so the save does not wait forever
    Process.flag(:trap_exit, true)
    {:ok, nil, {:continue, save}}
  end

  def handle_continue({image, suffix, opts}, _) do
    case Nif.nif_target_new() do
      {:ok, {pipe, target}} ->
        ref = make_ref()
        # the target is not kept, so the pipe closes when the save ends
        error = start_save(ref, image, %Target{ref: target}, suffix, opts)
        {:noreply, %TargetPipe{pipe: pipe, save_ref: ref, save_error: error}}

      {:error, reason} ->
        {:stop, reason, nil}
    end
  end

  def handle_call({:read, size}, from, %TargetPipe{pending: nil} = state) do
    do_read(%TargetPipe{state | pending: {from, size}})
  end

  def handle_call({:read, _size}, _from, state) do
    {:reply, {:error, :pending_read}, state}
  end

  def handle_info(:vix_pipe_ready, state) do
    do_read(state)
  end

  def handle_info({ref, result}, %TargetPipe{save_ref: ref} = state) do
    do_read(%TargetPipe{state | save_error: save_error(result), save_done: true})
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  # The save runs on a thread, which sends `{ref, result}`. Returns the error
  # if it could not be started
  defp start_save(ref, image, target, suffix, []) do
    :ok = Nif.nif_image_to_target_async(ref, image.ref, target.ref, suffix)
    nil
  end

  defp start_save(ref, image, target, suffix, opts) do
    with {:ok, saver} <- Vix.Vips.Foreign.find_save_target(suffix),
         :ok <- Helper.async_operation_call(ref, saver, [image, target], opts) do
      nil
    end
  rescue
    # an option value of the wrong type
    error -> {:error, Exception.message(error)}
  end

  defp save_error({:error, reason}), do: {:error, Helper.operation_error(reason)}
  defp save_error({:vix_raise, reason}), do: {:error, inspect(reason)}
  defp save_error(_ok), do: nil

  defp do_read(%TargetPipe{pending: nil} = state) do
    {:noreply, state}
  end

  defp do_read(%TargetPipe{save_error: {:error, _reason} = error} = state) do
    reply(state, error)
  end

  defp do_read(%TargetPipe{pending: {_from, size}} = state) do
    case Nif.nif_read(state.pipe, size) do
      # a failed save can close the stream before its error arrives
      {:ok, <<>>} when state.save_done -> reply(state, :eof)
      {:ok, <<>>} -> {:noreply, state}
      {:ok, binary} -> reply(state, {:ok, binary})
      {:error, :eagain} -> {:noreply, state}
      {:error, reason} -> reply(state, {:error, reason})
    end
  end

  defp reply(%TargetPipe{pending: {from, _size}} = state, ret) do
    :ok = GenServer.reply(from, ret)
    {:noreply, %TargetPipe{state | pending: nil}}
  end
end
