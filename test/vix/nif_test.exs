defmodule Vix.NifTest do
  use ExUnit.Case, async: true

  alias Vix.Nif

  import Vix.Support.Images

  test "nif_image_new_from_file" do
    path = img_path("puppies.jpg")
    {:ok, im} = Nif.nif_image_new_from_file(path)
    assert Nif.nif_g_object_type_name(im) == "VipsImage"
  end

  test "nif_image_write_area_to_binary" do
    path = img_path("puppies.jpg")
    {:ok, im} = Nif.nif_image_new_from_file(path)

    assert {:ok, {binary, 10 = width, 30 = height, 2 = bands, 0}} =
             Nif.nif_image_write_area_to_binary(im, [0, 2, 10, 30, 0, 2])

    assert IO.iodata_length(binary) == width * height * bands
  end

  test "read fd closes at OS level when owner exits with pending select" do
    {owner, raw_write_fd} = owner_with_pending_select(:read)

    stop_owner(owner)

    assert_pipe_has_no_readers(raw_write_fd)
  end

  test "write fd closes at OS level when owner exits with pending select" do
    {owner, raw_read_fd} = owner_with_pending_select(:write)

    stop_owner(owner)

    assert_pipe_has_no_writers(raw_read_fd)
  end

  defp owner_with_pending_select(mode) do
    parent = self()

    owner =
      spawn(fn ->
        {resource_fd, peer_fd} = open_pipe(mode)
        send(parent, {self(), :peer_fd, peer_fd})
        send(parent, {self(), :select_result, wait_for_select(mode, resource_fd)})

        receive do
          :stop -> resource_fd
        end
      end)

    assert_receive {^owner, :peer_fd, peer_fd}, 1_000
    assert_receive {^owner, :select_result, :ok}, 1_000

    {owner, peer_fd}
  end

  defp stop_owner(owner) do
    ref = Process.monitor(owner)
    send(owner, :stop)
    assert_receive {:DOWN, ^ref, :process, ^owner, :normal}
  end

  defp open_pipe(:read) do
    {:ok, {read_fd, write_fd}} = Nif.nif_pipe_open(:read)
    {read_fd, write_fd}
  end

  defp open_pipe(:write) do
    {:ok, {read_fd, write_fd}} = Nif.nif_pipe_open(:write)
    {write_fd, read_fd}
  end

  defp wait_for_select(:read, read_fd) do
    case Nif.nif_read(read_fd, 1) do
      {:error, :eagain} -> :ok
      other -> {:error, other}
    end
  end

  defp wait_for_select(:write, write_fd), do: wait_for_write_select(write_fd)

  defp wait_for_write_select(write_fd) do
    chunk = :binary.copy("x", 65_536)
    wait_for_write_select(write_fd, chunk, 100)
  end

  defp wait_for_write_select(_write_fd, _chunk, 0), do: {:error, :pipe_did_not_fill}

  defp wait_for_write_select(write_fd, chunk, attempts) do
    case Nif.nif_write(write_fd, chunk) do
      {:ok, size} when size < byte_size(chunk) ->
        :ok

      {:ok, _size} ->
        wait_for_write_select(write_fd, chunk, attempts - 1)

      {:error, :eagain} ->
        :ok

      other ->
        {:error, other}
    end
  end

  defp assert_pipe_has_no_readers(raw_write_fd) do
    with_raw_fd(raw_write_fd, [:write, :raw, :binary], fn write_fd ->
      assert_eventually_epipe(write_fd, 20)
    end)
  end

  defp assert_eventually_epipe(write_fd, 0) do
    assert {:error, :epipe} = :prim_file.write(write_fd, "x")
  end

  defp assert_eventually_epipe(write_fd, attempts) do
    case :prim_file.write(write_fd, "x") do
      {:error, :epipe} ->
        :ok

      :ok ->
        Process.sleep(10)
        assert_eventually_epipe(write_fd, attempts - 1)
    end
  end

  defp assert_pipe_has_no_writers(raw_read_fd) do
    # The raw read fd is blocking; time out if the writer was leaked.
    assert :eof =
             Task.async(fn -> read_raw_fd_until_eof(raw_read_fd) end)
             |> Task.await(1_000)
  end

  defp read_raw_fd_until_eof(raw_read_fd) do
    with_raw_fd(raw_read_fd, [:read, :raw, :binary], &read_until_eof/1)
  end

  defp read_until_eof(read_fd) do
    case :prim_file.read(read_fd, 65_536) do
      :eof -> :eof
      {:ok, _binary} -> read_until_eof(read_fd)
      other -> other
    end
  end

  defp with_raw_fd(raw_fd, modes, fun) do
    {:ok, fd} = :prim_file.file_desc_to_ref(raw_fd, modes)

    try do
      fun.(fd)
    after
      :prim_file.close(fd)
    end
  end
end
