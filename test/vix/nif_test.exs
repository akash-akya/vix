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

  test "target read fd closes when owner exits" do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, {read_fd, _target}} = Nif.nif_target_new()
        send(parent, {:target_read_fd, read_fd})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:target_read_fd, read_fd}, 1_000

    ref = Process.monitor(owner)
    send(owner, :stop)

    assert_receive {:DOWN, ^ref, :process, ^owner, :normal}
    assert {:error, "Bad file descriptor"} = Nif.nif_read(read_fd, 1)
  end

  test "target read fd closes when owner exits after waiting for input" do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, {read_fd, _target}} = Nif.nif_target_new()
        send(parent, {:target_read_fd, read_fd})

        receive do
          :select ->
            send(parent, {:select_result, Nif.nif_read(read_fd, 1)})
        end

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:target_read_fd, read_fd}, 1_000

    send(owner, :select)
    assert_receive {:select_result, {:error, :eagain}}, 1_000

    ref = Process.monitor(owner)
    send(owner, :stop)

    assert_receive {:DOWN, ^ref, :process, ^owner, :normal}
    assert {:error, "Bad file descriptor"} = Nif.nif_read(read_fd, 1)
  end
end
