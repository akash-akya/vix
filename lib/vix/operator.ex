defmodule Vix.Operator do
  @moduledoc """
  Provides implementation of basic math operators for Vix Image.

  Useful to improve the readability of complex Image processing
  operation pipelines.

  ```elixir
  def foo do
    use Vix.Operator

    black = Operation.black!(100, 100, bands: 3)
    white = Operation.invert!(black)

    white == white + black
    grey = black + 125  # same as [125]
    grey = black + [125] # same as [125, 125, 125], since the image contains 3 bands
    grey = black + [125, 125, 125]
  end
  ```
  """

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  import Kernel, except: [+: 2, -: 2, *: 2, /: 2]

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [+: 2, -: 2, *: 2, /: 2]
      import Vix.Operator
    end
  end

  @doc """
  Perform addition operation of an image and a number, an array or
  an another image.

  * if argument is a number or a list of only one number, then the same number is used
    for all image bands for the operation. Example `img + 255`, `img + [255]`
  * if array size matches image bands, then each array
    element is added to respective band. Example `red = Operation.black!(100, 100, bands: 3) + [125, 0, 0]`
  * if array size is more than image bands and image only contains one band
    then the output will be a multi band image with each array element mapping
    to one band
  * if argument is an image, then `Vix.Vips.Operation.add!/2` operation will
    be performed

  When none of the argument is an image then delegates to `Kernel.+/2`
  """
  @spec Image.t() + Image.t() :: Image.t()
  @spec Image.t() + number() :: Image.t()
  @spec number() + Image.t() :: Image.t()
  @spec Image.t() + [number()] :: Image.t()
  @spec [number()] + Image.t() :: Image.t()
  @spec number() + number() :: number()
  def a + b do
    add(a, b)
  end

  @doc """
  Perform multiplication operation of an image and a number, an array or
  an another image.

  * if argument is a number or a list of only one number, then the same number is used
    for all image bands for the operation. Example `img * 2`, `img + [2]`
  * if array size matches image bands, then each array
    element is added to respective band
  * if array size is more than image bands and image only contains one band
    then the output will be a multi band image with each array element mapping
    to one band
  * if argument is an image, then `Vix.Vips.Operation.multiply!/2` operation will
    be performed

  When none of the argument is an image then delegates to `Kernel.*/2`
  """
  @spec Image.t() * Image.t() :: Image.t()
  @spec Image.t() * number() :: Image.t()
  @spec number() * Image.t() :: Image.t()
  @spec Image.t() * [number()] :: Image.t()
  @spec [number()] * Image.t() :: Image.t()
  @spec number() * number() :: number()
  def a * b do
    mul(a, b)
  end

  @doc """
  Perform subtraction operation of an image and a number, an array or
  an another image.

  * if argument is a number or a list of only one number, then the same number is used
    for all image bands for the operation. Example `img - 125`, `img - [125]`
  * if array size matches image bands, then each array
    element is added to respective band
  * if array size is more than image bands and image only contains one band
    then the output will be a multi band image with each array element mapping
    to one band
  * if argument is an image, then `Vix.Vips.Operation.subtract!/2` operation will
    be performed

  When none of the argument is an image then delegates to `Kernel.-/2`
  """
  @spec Image.t() - Image.t() :: Image.t()
  @spec Image.t() - number() :: Image.t()
  @spec number() - Image.t() :: Image.t()
  @spec Image.t() - [number()] :: Image.t()
  @spec [number()] - Image.t() :: Image.t()
  @spec number() - number() :: number()
  def a - b do
    sub(a, b)
  end

  @doc """
  Perform division operation of an image and a number, an array or
  an another image.

  * if argument is a number or a list of only one number, then the same number is used
    for all image bands for the operation. Example `img / 2`, `img / [2]`
  * if array size matches image bands, then each array
    element is added to respective band
  * if array size is more than image bands and image only contains one band
    then the output will be a multi band image with each array element mapping
    to one band
  * if argument is an image, then `Vix.Vips.Operation.divide!/2` operation will
    be performed

  When none of the argument is an image then delegates to `Kernel.//2`
  """
  @spec Image.t() / Image.t() :: Image.t()
  @spec Image.t() / number() :: Image.t()
  @spec number() / Image.t() :: Image.t()
  @spec Image.t() / [number()] :: Image.t()
  @spec [number()] / Image.t() :: Image.t()
  @spec number() / number() :: number()
  def a / b do
    divide(a, b)
  end

  defmacrop when_number_list(arg, do: block) do
    quote do
      if Enum.all?(unquote(arg), &is_number/1) do
        unquote(block)
      else
        raise ArgumentError, "list elements must be a number, got: #{inspect(unquote(arg))}"
      end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp add(a, b) do
    cond do
      is_image(a) && is_image(b) ->
        Operation.add!(a, b)

      is_image(a) && is_number(b) ->
        add(a, [b])

      is_number(a) && is_image(b) ->
        add(b, [a])

      is_list(a) && is_image(b) ->
        add(b, a)

      is_image(a) && is_list(b) ->
        when_number_list b do
          Operation.linear!(a, [1], b)
        end

      true ->
        Kernel.+(a, b)
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp mul(a, b) do
    cond do
      is_image(a) && is_image(b) ->
        Operation.multiply!(a, b)

      is_image(a) && is_number(b) ->
        mul(a, [b])

      is_number(a) && is_image(b) ->
        mul(b, [a])

      is_list(a) && is_image(b) ->
        mul(b, a)

      is_image(a) && is_list(b) ->
        when_number_list b do
          Operation.linear!(a, b, [0])
        end

      true ->
        Kernel.*(a, b)
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp sub(a, b) do
    cond do
      is_image(a) && is_image(b) ->
        Operation.subtract!(a, b)

      is_image(a) && is_number(b) ->
        sub(a, [b])

      is_number(a) && is_image(b) ->
        sub([a], b)

      is_list(a) && is_image(b) ->
        when_number_list a do
          # a - b = (b * -1) + a
          Operation.linear!(b, [-1], a)
        end

      is_image(a) && is_list(b) ->
        when_number_list b do
          Operation.linear!(a, [1], Enum.map(b, &(-&1)))
        end

      true ->
        Kernel.-(a, b)
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp divide(a, b) do
    cond do
      is_image(a) && is_image(b) ->
        Operation.divide!(a, b)

      is_image(a) && is_number(b) ->
        divide(a, [b])

      is_number(a) && is_image(b) ->
        divide([a], b)

      is_list(a) && is_image(b) ->
        when_number_list a do
          # a / b = (b^-1) * a = (1 / b) * a
          b
          |> Operation.math2_const!(:VIPS_OPERATION_MATH2_POW, [-1])
          |> Operation.linear!(a, [0])
        end

      is_image(a) && is_list(b) ->
        when_number_list b do
          Operation.linear!(a, Enum.map(b, &(1 / &1)), [0])
        end

      true ->
        Kernel./(a, b)
    end
  end

  defp is_image(%Image{}), do: true
  defp is_image(_), do: false
end
