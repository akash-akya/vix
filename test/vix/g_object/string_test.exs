defmodule Vix.GObject.StringTest do
  use ExUnit.Case, async: true

  test "to_nif_term" do
    io_list = Vix.GObject.String.to_nif_term("sample", nil)
    assert IO.iodata_to_binary(io_list) == "sample\0"

    io_list = Vix.GObject.String.to_nif_term("ಉನಿಕೋಡ್", nil)
    assert IO.iodata_to_binary(io_list) == "ಉನಿಕೋಡ್\0"

    assert_raise ArgumentError, "expected UTF-8 binary string", fn ->
      Vix.GObject.String.to_nif_term(<<0xFF::16>>, nil)
    end
  end
end
