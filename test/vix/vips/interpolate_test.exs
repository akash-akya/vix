defmodule Vix.Vips.InterpolateTest do
  use ExUnit.Case
  alias Vix.Vips.Interpolate

  test "new interpolate" do
    assert {:ok, %Interpolate{ref: ref}} = Interpolate.new("nearest")

    {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(ref)
    assert Vix.Nif.nif_g_type_name(gtype) == {:ok, "VipsInterpolateNearest"}
  end
end
