defmodule Vix.Vips.BlobTest do
  use ExUnit.Case
  alias Vix.Vips.Blob

  test "to_nif_term" do
    blob = Blob.to_nif_term(<<1, 2, 3, 4>>, nil)

    {:ok, gtype} = Vix.Nif.nif_g_type_from_instance(blob)
    assert Vix.Nif.nif_g_type_name(gtype) == {:ok, "VipsBlob"}
  end

  test "to_erl_term" do
    blob = Blob.to_nif_term(<<1, 2, 3, 4>>, nil)
    assert <<1, 2, 3, 4>> == Blob.to_erl_term(blob)
  end
end
