defmodule Vix.GObject.GParamSpec do
  @moduledoc false
  @type t :: %{}

  defstruct [:param_name, :desc, :spec_type, :value_type, :data, :priority, :flags, :type]

  alias __MODULE__

  def new(opt) do
    pspec = %GParamSpec{
      param_name: opt.name,
      desc: opt.desc,
      spec_type: to_string(opt.spec_type),
      value_type: to_string(opt.value_type),
      data: opt.data,
      priority: opt.priority,
      flags: opt.flags,
      type: nil
    }

    %GParamSpec{pspec | type: type(pspec)}
  end

  def type(%GParamSpec{spec_type: "GParamEnum", value_type: value_type}) do
    {:enum, value_type}
  end

  def type(%GParamSpec{spec_type: "GParamFlags", value_type: value_type}) do
    {:flags, value_type}
  end

  # for array of enum, libvips does not pass required information to
  # properly expose it to elixir world with correct spec and
  # validation. libvips marks array of enum as array of int.
  #
  # To address this we try to recognize common type of enums
  # explicitly and handle casting in elixir side.
  def type(%GParamSpec{param_name: "mode", desc: "Array of VipsBlendMode " <> _}) do
    {:vips_array, "Enum.VipsBlendMode"}
  end

  def type(%GParamSpec{value_type: "VipsArray" <> nested_type}) do
    {:vips_array, nested_type}
  end

  def type(%GParamSpec{value_type: "VipsImage", flags: flags}) do
    if :vips_argument_modify in flags do
      "MutableVipsImage"
    else
      "VipsImage"
    end
  end

  def type(%GParamSpec{value_type: value_type}) do
    value_type
  end
end
