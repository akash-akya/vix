defmodule Eips.Ops do
  defstruct [:op, :args]
  alias __MODULE__

  def image(path) do
    %Ops{op: :image, args: %{path: path}}
  end

  def invert(input, output) do
    %Ops{op: :invert, args: %{input: input, output: output}}
  end

  def draw_line(image, color, x1, y1, x2, y2) do
    %Ops{op: :draw_line, args: %{image: image, color: color, x1: x1, y1: y1, x2: x2, y2: y2}}
  end

  def merge(ref, sec, out, direction, dx, dy) do
    %Ops{op: :merge, args: %{ref: ref, sec: sec, out: out, direction: direction, dx: dx, dy: dy}}
  end

  def print(op) do
    IO.inspect(op)
  end
end
