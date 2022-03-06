defmodule Vix.TypeTest do
  use ExUnit.Case, async: true

  alias Vix.Type

  test "typespec" do
    assert {:integer, [], []} == Type.typespec("gint")
  end
end
