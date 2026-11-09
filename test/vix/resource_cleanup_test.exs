defmodule Vix.ResourceCleanupTest do
  # Not async: it changes the global operation cache and reads global memory stats
  use ExUnit.Case, async: false

  alias Vix.Vips
  alias Vix.Vips.Image

  import Vix.Support.Images

  setup do
    # the operation cache would keep the image alive
    max = Vips.cache_get_max()
    Vips.cache_set_max(0)
    on_exit(fn -> Vips.cache_set_max(max) end)
  end

  test "frees an image when the last reference is dropped" do
    baseline = Vips.tracked_get_mem()
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        {:ok, img} = Image.new_from_file(img_path("puppies.jpg"))
        {:ok, _copy} = Image.copy_memory(img)
        send(parent, {:held, Vips.tracked_get_mem()})
      end)

    assert_receive {:held, held}
    assert held > baseline

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    assert eventually(fn -> Vips.tracked_get_mem() <= baseline end)
  end

  defp eventually(fun, attempts \\ 100) do
    cond do
      fun.() ->
        true

      attempts == 0 ->
        false

      true ->
        Process.sleep(10)
        eventually(fun, attempts - 1)
    end
  end
end
