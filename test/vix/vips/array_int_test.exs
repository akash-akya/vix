defmodule Vix.Vips.ArrayIntTest do
  use ExUnit.Case
  alias Vix.Vips.ArrayInt

  test "to_nif_term" do
    obj = ArrayInt.to_nif_term([1, 2, 3, 4], nil)

    {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(obj)
    assert Vix.Nif.nif_g_type_name(gtype) == {:ok, 'VipsArrayInt'}
  end
end
