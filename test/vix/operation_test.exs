defmodule Vix.OperationTest do
  use ExUnit.Case
  alias Vix.Vips.Image
  alias Vix.Operation

  @sample "puppies.jpg"

  setup do
    Temp.track!()
    :ok
  end

  test "invert" do
    {:ok, im} = Image.new_from_file(path(@sample))
    out = Operation.invert(im)

    out_path = Temp.path!(suffix: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    expected = expected("invert", @sample)
    assert_files_equal(expected, out_path)
  end

  defp assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  defp path(name) do
    Path.join(__DIR__, "../support/#{name}")
  end

  defp expected(action, name) do
    Path.join(__DIR__, "../support/#{action}_#{name}")
  end
end
