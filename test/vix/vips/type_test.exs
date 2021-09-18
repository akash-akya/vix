defmodule Vix.TypeTest do
  use ExUnit.Case
  alias Vix.Type

  test "typespec" do
    assert {:integer, [], []} == Type.typespec("gint")
  end

  test "supported?" do
    refute Type.supported?("VipsInterpolate")
  end
end
