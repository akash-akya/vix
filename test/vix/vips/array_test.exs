defmodule Vix.Vips.ArrayTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Array

  describe "Int" do
    test "to_nif_term" do
      obj = Array.Int.to_nif_term([1, 2, 3, 4], nil)

      {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(obj)
      assert Vix.Nif.nif_g_type_name(gtype) == {:ok, "VipsArrayInt"}
    end

    test "to_erl_term" do
      obj = Array.Int.to_nif_term([1, 2, 3, 4], nil)
      assert [1, 2, 3, 4] == Array.Int.to_erl_term(obj)
    end
  end

  describe "Double" do
    test "to_nif_term" do
      obj = Array.Double.to_nif_term([1, 2, 3, 4.1], nil)

      {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(obj)
      assert Vix.Nif.nif_g_type_name(gtype) == {:ok, "VipsArrayDouble"}
    end

    test "to_erl_term" do
      obj = Array.Double.to_nif_term([1, 2.46, 0.2, 400.00001], nil)
      # values are casted to double
      assert [1.0, 2.46, 0.2, 400.00001] == Array.Double.to_erl_term(obj)
    end
  end

  describe "Enum.VipsInterpretation" do
    test "to_nif_term" do
      obj =
        Array.Enum.VipsBlendMode.to_nif_term(
          [:VIPS_BLEND_MODE_IN, :VIPS_BLEND_MODE_DEST, :VIPS_BLEND_MODE_MULTIPLY],
          nil
        )

      {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(obj)
      assert Vix.Nif.nif_g_type_name(gtype) == {:ok, "VipsArrayInt"}
    end

    test "to_erl_term" do
      obj = Array.Int.to_nif_term([1, 2, 3], nil)

      assert [:VIPS_BLEND_MODE_SOURCE, :VIPS_BLEND_MODE_OVER, :VIPS_BLEND_MODE_IN] ==
               Array.Enum.VipsBlendMode.to_erl_term(obj)
    end
  end
end
