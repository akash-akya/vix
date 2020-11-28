defmodule Vix.Vips.ArrayDoubleTest do
  use ExUnit.Case
  alias Vix.Vips.ArrayDouble

  test "to_nif_term" do
    obj = ArrayDouble.to_nif_term([1, 2, 3, 4.1], nil)

    {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(obj)
    assert Vix.Nif.nif_g_type_name(gtype) == {:ok, 'VipsArrayDouble'}
  end

  test "to_erl_term" do
    obj = ArrayDouble.to_nif_term([1, 2.46, 0.2, 400.00001], nil)
    # values are casted to double
    assert [1.0, 2.46, 0.2, 400.00001] == ArrayDouble.to_erl_term(obj)
  end
end
