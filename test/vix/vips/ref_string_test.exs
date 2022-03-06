defmodule Vix.Vips.RefStringTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.RefString

  test "to_nif_term" do
    string = RefString.to_nif_term("vix is awesome!", nil)

    {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(string)
    assert Vix.Nif.nif_g_type_name(gtype) == {:ok, "VipsRefString"}

    assert_raise ArgumentError, fn ->
      RefString.to_nif_term(<<255>>, nil)
    end
  end

  test "to_erl_term" do
    string = RefString.to_nif_term("vix is awesome!", nil)
    assert "vix is awesome!" == RefString.to_erl_term(string)
  end
end
