defmodule VixTest do
  use ExUnit.Case
  doctest Vix

  test "greets the world" do
    assert Vix.hello() == :world
  end
end
