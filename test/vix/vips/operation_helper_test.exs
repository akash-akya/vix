defmodule Vix.Vips.OperationHelperTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image
  alias Vix.Vips.OperationHelper

  import Vix.Support.Images

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "operation_call", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, out} =
             OperationHelper.operation_call(
               "gravity",
               [im, :VIPS_COMPASS_DIRECTION_CENTRE, 650, 500],
               extend: :VIPS_EXTEND_COPY
             )

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("gravity_puppies.jpg"), out_path)
  end
end
