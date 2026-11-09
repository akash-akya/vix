defmodule Vix.NifTest do
  use ExUnit.Case, async: true

  alias Vix.Nif

  import Vix.Support.Images

  @precompiled_nif_mode (System.get_env("VIX_COMPILATION_MODE") ||
                           "PRECOMPILED_NIF_AND_LIBVIPS") == "PRECOMPILED_NIF_AND_LIBVIPS"

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

  if @precompiled_nif_mode do
    @tag skip: "requires NIF compiled from current source"
  end

  test "save stops when the reader exits" do
    parent = self()

    reader =
      spawn(fn ->
        {:ok, {_pipe, target}} = Nif.nif_target_new()
        send(parent, {:target, target})
        receive do: (:stop -> :ok)
      end)

    assert_receive {:target, target}
    {:ok, im} = Nif.nif_image_new_from_file(img_path("puppies.jpg"))

    # nobody reads, so the save waits once the pipe is full
    ref = make_ref()
    :ok = Nif.nif_image_to_target_async(ref, im, target, ".png[compression=0]")
    send(reader, :stop)

    assert_receive {^ref, {:error, _}}, 5_000
  end
end
