defmodule Vix.Vips.Operation.HelperTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image
  alias Vix.Vips.Operation.Helper

  import Vix.Support.Images

  test "operation_call" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, out} =
             Helper.operation_call(
               "gravity",
               [im, :VIPS_COMPASS_DIRECTION_CENTRE, 650, 500],
               extend: :VIPS_EXTEND_COPY
             )

    out_path = Briefly.create!(extname: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("gravity_puppies.jpg"), out_path)
  end
end
