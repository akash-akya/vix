defmodule Vix.TypeTest do
  use ExUnit.Case
  alias Vix.Type
  alias Vix.GObject.GParamSpec

  test "typespec" do
    assert {:integer, [], []} ==
             Type.typespec(%GParamSpec{spec_type: "GParamSpecInt", value_type: "gint"})
  end

  test "supported?" do
    refute Type.supported?(%GParamSpec{spec_type: "GParamObject", value_type: "VipsInterpolate"})
  end
end
