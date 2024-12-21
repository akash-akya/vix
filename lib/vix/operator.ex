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

  # we are doing this instead of defining a separate type because it
  # makes documentation more readable without redirection
  @arg_typespec [
                  quote(do: [number]),
                  quote(do: number),
                  quote(do: Image.t())
                ]
                |> Enum.reduce(&{:|, [], [&1, &2]})

  import Kernel, except: [+: 2, -: 2, *: 2, /: 2, **: 2, <: 2, >: 2, >=: 2, <=: 2, ==: 2, !=: 2]

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Kernel,
        except: [+: 2, -: 2, *: 2, /: 2, **: 2, <: 2, >: 2, >=: 2, <=: 2, ==: 2, !=: 2]

      import Vix.Operator
    end
  end

  ### Arithmetic Operators

  @basic_arithmetic_format_doc """
  ### Output Image Band Format

  * If both arguments are Images then they are cast up to the smallest common format. In other words, the output type is just large enough to hold the whole range of possible values.

  * If any of the argument is a number then output type is float for integer input, double for double input, complex for complex input and double complex for double complex input.
  """

  @pow_format_doc """
  It detects division by zero, setting those pixels to zero in the output, without any error or warning.

  ### Output Image Band Format

  * If both arguments are Images then they are cast up to the smallest common format. In other words, the output type is just large enough to hold the whole range of possible values.

  * If any of the argument is a number then output type is float except when input image is double, in which case out is also double.
  """

  [
    %{name: :addition, operator: :+, desc: @basic_arithmetic_format_doc},
    %{name: :subtraction, operator: :-, desc: @basic_arithmetic_format_doc},
    %{name: :multiplication, operator: :*, desc: @basic_arithmetic_format_doc},
    %{name: :division, operator: :/, desc: @basic_arithmetic_format_doc},
    %{name: :power, operator: :**, desc: @pow_format_doc}
  ]
  |> Enum.each(fn %{name: name, operator: op, desc: desc} ->
    @doc """
    Perform #{name} operation between Images, numbers and list of numbers (pixel).

    * if argument is a number or a list of only one number, then the same number is used
      for all of the image bands.
    * if array size matches image bands, then each array element is matched to
      with the respective band.
    * if array size is more than image bands and image only contains one band
      then the output will be a multi band with as many bands as there are elements in
      the array
    * if both arguments are Images, then operation will be performed by matching each
      pixels

    #{desc}

    When none of the argument is an image then delegates to `Kernel.#{op}/2`
    """
    @spec unquote(op)(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
    @spec unquote(op)(number, number) :: number()
    def unquote(op)(a, b) do
      if image?(a) || image?(b) do
        unquote(name)(a, b)
      else
        Kernel.unquote(op)(a, b)
      end
    end
  end)

  @spec addition(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
  defp addition(a, b) do
    operation(
      a,
      b,
      &Operation.add!(&1, &2),
      &Operation.linear!(&1, [1.0], &2),
      &Operation.linear!(&2, [1.0], &1)
    )
  end

  @spec multiplication(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
  defp multiplication(a, b) do
    operation(
      a,
      b,
      &Operation.multiply!(&1, &2),
      &Operation.linear!(&1, &2, [+0.0]),
      &Operation.linear!(&2, &1, [+0.0])
    )
  end

  @spec subtraction(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
  defp subtraction(a, b) do
    operation(
      a,
      b,
      &Operation.subtract!(&1, &2),
      fn img, list ->
        neg_list = Enum.map(list, &(-&1))
        Operation.linear!(img, [1.0], neg_list)
      end,
      # a - b = (b * -1) + a
      &Operation.linear!(&2, [-1.0], &1)
    )
  end

  @spec division(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
  defp division(a, b) do
    operation(
      a,
      b,
      &Operation.divide!(&1, &2),
      fn img, list ->
        inv_list = Enum.map(list, &(1 / &1))
        Operation.linear!(img, inv_list, [+0.0])
      end,
      fn list, img ->
        # a / b = (b^-1) * a = (1 / b) * a
        img
        |> Operation.math2_const!(:VIPS_OPERATION_MATH2_POW, [-1.0])
        |> Operation.linear!(list, [+0.0])
      end
    )
  end

  @spec power(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
  defp power(a, b) do
    operation(
      a,
      b,
      &Operation.math2!(&1, &2, :VIPS_OPERATION_MATH2_POW),
      &Operation.math2_const!(&1, :VIPS_OPERATION_MATH2_POW, &2),
      &Operation.math2_const!(&2, :VIPS_OPERATION_MATH2_WOP, &1)
    )
  end

  ### Relational Operators

  [
    %{
      name: :less_than,
      operator: :<,
      sym: :VIPS_OPERATION_RELATIONAL_LESS,
      inv_sym: :VIPS_OPERATION_RELATIONAL_MOREEQ,
      examples: """
      Comparing two images

      ```elixir
      iex> Image.build_image!(10, 10, [4, 5, 6]) < Image.build_image!(10, 10, [5, 6, 7])
      true
      iex> Image.build_image!(10, 10, [4, 5, 6]) < Image.build_image!(10, 10, [4, 5, 6])
      false
      iex> Image.build_image!(10, 10, [1, 2, 3]) < Image.build_image!(10, 10, [6])
      true
      iex> Image.build_image!(10, 10, [7]) < Image.build_image!(10, 10, [6])
      false
      ```

      Comparing an Image with a number

      ```elixir
      # when we compare with a number we compare all values
      iex> Image.build_image!(10, 10, [4, 4, 4]) < 5
      true
      iex> Image.build_image!(10, 10, [4]) < 2
      false
      # comparing different types
      iex> Image.build_image!(10, 10, [4]) < 5.0
      true
      # when we compare with a list we compare respective bands
      iex> Image.build_image!(10, 10, [4, 5, 6]) < [5, 6, 7]
      true
      ```

      Comparison works other way as well

      ```elixir
      iex> 4.0 < Image.build_image!(10, 10, [5])
      true
      iex> [4, 5, 6] < Image.build_image!(10, 10, [5, 6,7 ])
      true
      ```

      Fallback to `Kernel/2`

      ```elixir
      iex> 4 < 5
      true
      ```
      """
    },
    %{
      name: :less_than_equal,
      operator: :<=,
      sym: :VIPS_OPERATION_RELATIONAL_LESSEQ,
      inv_sym: :VIPS_OPERATION_RELATIONAL_MORE,
      examples: """
      Comparing two images

      ```elixir
      iex> Image.build_image!(10, 10, [4, 5, 6]) <= Image.build_image!(10, 10, [5, 6, 7])
      true
      iex> Image.build_image!(10, 10, [4, 5, 6]) <= Image.build_image!(10, 10, [4, 5, 6])
      true
      iex> Image.build_image!(10, 10, [1, 2, 3]) <= Image.build_image!(10, 10, [6])
      true
      iex> Image.build_image!(10, 10, [7]) <= Image.build_image!(10, 10, [6])
      false
      ```

      Comparing an Image with a number

      ```elixir
      # when we compare with a number we compare all values
      iex> Image.build_image!(10, 10, [4, 4, 4]) <= 5
      true
      iex> Image.build_image!(10, 10, [4]) <= 2
      false
      # comparing different types
      iex> Image.build_image!(10, 10, [4]) <= 5.0
      true
      # when we compare with a list we compare respective bands
      iex> Image.build_image!(10, 10, [4, 5, 6]) <= [5, 6, 7]
      true
      ```

      Comparison works other way as well

      ```elixir
      iex> 4.0 <= Image.build_image!(10, 10, [5])
      true
      iex> [4, 5, 6] <= Image.build_image!(10, 10, [5, 6,7 ])
      true
      ```

      Fallback to `Kernel/2`

      ```elixir
      iex> 4 <= 5
      true
      ```
      """
    },
    %{
      name: :greater_than,
      operator: :>,
      sym: :VIPS_OPERATION_RELATIONAL_MORE,
      inv_sym: :VIPS_OPERATION_RELATIONAL_LESSEQ,
      examples: """
      Comparing two images

      ```elixir
      iex> Image.build_image!(10, 10, [5, 6, 7]) > Image.build_image!(10, 10, [4, 5, 6])
      true
      iex> Image.build_image!(10, 10, [4, 5, 6]) > Image.build_image!(10, 10, [4, 5, 6])
      false
      iex> Image.build_image!(10, 10, [2, 3, 4]) > Image.build_image!(10, 10, [1])
      true
      iex> Image.build_image!(10, 10, [6]) > Image.build_image!(10, 10, [7])
      false
      ```

      Comparing an Image with a number

      ```elixir
      # when we compare with a number we compare all values
      iex> Image.build_image!(10, 10, [5, 5, 5]) > 4
      true
      iex> Image.build_image!(10, 10, [1]) > 2
      false
      # comparing different types
      iex> Image.build_image!(10, 10, [5]) > 4.0
      true
      # when we compare with a list we compare respective bands
      iex> Image.build_image!(10, 10, [5, 6, 7]) > [4, 5, 6]
      true
      ```

      Comparison works other way as well

      ```elixir
      iex> 5.0 > Image.build_image!(10, 10, [4])
      true
      iex> [5, 6, 7] > Image.build_image!(10, 10, [4, 5, 6])
      true
      ```

      Fallback to `Kernel/2`

      ```elixir
      iex> 5 > 4
      true
      ```
      """
    },
    %{
      name: :greater_than_equal,
      operator: :>=,
      sym: :VIPS_OPERATION_RELATIONAL_MOREEQ,
      inv_sym: :VIPS_OPERATION_RELATIONAL_LESS,
      examples: """
      Comparing two images

      ```elixir
      iex> Image.build_image!(10, 10, [5, 6, 7]) >= Image.build_image!(10, 10, [4, 5, 6])
      true
      iex> Image.build_image!(10, 10, [4, 5, 6]) >= Image.build_image!(10, 10, [4, 5, 6])
      true
      iex> Image.build_image!(10, 10, [2, 3, 4]) >= Image.build_image!(10, 10, [1])
      true
      iex> Image.build_image!(10, 10, [6]) >= Image.build_image!(10, 10, [7])
      false
      ```

      Comparing an Image with a number

      ```elixir
      # when we compare with a number we compare all values
      iex> Image.build_image!(10, 10, [5, 5, 5]) >= 4
      true
      iex> Image.build_image!(10, 10, [1]) >= 2
      false
      # comparing different types
      iex> Image.build_image!(10, 10, [5]) >= 4.0
      true
      # when we compare with a list we compare respective bands
      iex> Image.build_image!(10, 10, [5, 6, 7]) >= [4, 5, 6]
      true
      ```

      Comparison works other way as well

      ```elixir
      iex> 5.0 >= Image.build_image!(10, 10, [4])
      true
      iex> [5, 6, 7] >= Image.build_image!(10, 10, [4, 5, 6])
      true
      ```

      Fallback to `Kernel/2`

      ```elixir
      iex> 5 >= 4
      true
      ```
      """
    },
    %{
      name: :equal,
      operator: :==,
      sym: :VIPS_OPERATION_RELATIONAL_EQUAL,
      inv_sym: :VIPS_OPERATION_RELATIONAL_EQUAL,
      examples: """
      Comparing two images

      ```elixir
      iex> Image.build_image!(10, 10, [4, 5, 6]) == Image.build_image!(10, 10, [4, 5, 6])
      true
      iex> Image.build_image!(10, 10, [5]) == Image.build_image!(10, 10, [6])
      false
      ```

      Comparing an Image with a number

      ```elixir
      # when we compare with a number we compare all values
      iex> Image.build_image!(10, 10, [4, 4, 4]) == 4
      true
      iex> Image.build_image!(10, 10, [4]) == 5
      false
      # comparing different types
      iex> Image.build_image!(10, 10, [4]) == 4.0
      true
      # when we compare with a list we compare respective bands
      iex> Image.build_image!(10, 10, [4, 5, 6]) == [4, 5, 6]
      true
      ```

      Comparison works other way as well

      ```elixir
      iex> 4 == Image.build_image!(10, 10, [4])
      true
      iex> [4, 5, 6] == Image.build_image!(10, 10, [4, 5, 6])
      true
      ```

      Fallback to `Kernel/2`

      ```elixir
      iex> 4 == 4
      true
      ```
      """
    },
    %{
      name: :not_equal,
      operator: :!=,
      sym: :VIPS_OPERATION_RELATIONAL_NOTEQ,
      inv_sym: :VIPS_OPERATION_RELATIONAL_NOTEQ,
      examples: """
      Comparing two images

      ```elixir
      iex> Image.build_image!(10, 10, [4, 5, 6]) != Image.build_image!(10, 10, [4, 5, 6])
      false
      iex> Image.build_image!(10, 10, [5]) != Image.build_image!(10, 10, [6])
      true
      ```

      Comparing an Image with a number

      ```elixir
      # when we compare with a number we compare all values
      iex> Image.build_image!(10, 10, [4, 4, 4]) != 4
      false
      iex> Image.build_image!(10, 10, [4]) != 5
      true
      # comparing different types
      iex> Image.build_image!(10, 10, [4]) != 4.0
      false
      iex> Image.build_image!(10, 10, [4]) != 1.0
      true
      # when we compare with a list we compare respective bands
      iex> Image.build_image!(10, 10, [4, 5, 6]) != [4, 5, 6]
      false
      ```

      Comparison works other way as well

      ```elixir
      iex> 4 != Image.build_image!(10, 10, [4])
      false
      iex> 5 != Image.build_image!(10, 10, [4])
      true
      iex> [4, 5, 6] != Image.build_image!(10, 10, [4, 5, 6])
      false
      ```

      Fallback to `Kernel/2`

      ```elixir
      iex> 4 != 5
      true
      ```
      """
    }
  ]
  |> Enum.each(fn %{name: name, operator: op, sym: sym, inv_sym: inv_sym, examples: examples} ->
    header = "#{String.replace(to_string(name), "_", "-")} (`#{op}`)"

    @doc """
    Perform #{header} comparison between Images and numbers.

    * if argument is a number or a list of only one number, then the same number is used
      for all image bands for the operation.
    * if array size matches image bands, then the respective number is used for the
      respective band
    * if array size is more than image bands and image only contains one band
      then the output will be a multi band image with each array element mapping
      to one band
    * if argument is an image, then `Operation.relational!(a, b, #{inspect(sym)})`
      operation will be performed to compare images.

    The two input images are cast up to the smallest common format before performing the comparison.

    Always returns a boolean. If you want bandwise comparison with output as Image, then
    check `Operation.relational!(a, b, #{inspect(sym)})`

    When none of the argument is an image then delegates to `Kernel.#{op}/2`

    ### Examples

    #{examples}
    """
    @spec unquote(op)(unquote(@arg_typespec), unquote(@arg_typespec)) :: boolean
    @spec unquote(op)(term, term) :: boolean()
    def unquote(op)(a, b) do
      unquote(name)(a, b)
    end

    defp unquote(name)(a, b) do
      if image?(a) || image?(b) do
        relational_operation(a, b, unquote(sym), unquote(inv_sym))
      else
        Kernel.unquote(op)(a, b)
      end
    end
  end)

  @spec relational_operation(unquote(@arg_typespec), unquote(@arg_typespec), atom, atom) ::
          term | no_return()
  defp relational_operation(a, b, op, inv_op) do
    operation(
      a,
      b,
      fn %Image{} = a, %Image{} = b ->
        Operation.relational!(a, b, op)
      end,
      fn %Image{} = a, b when is_list(b) ->
        Operation.relational_const!(a, op, b)
      end,
      fn a, %Image{} = b when is_list(a) ->
        Operation.relational_const!(b, inv_op, a)
      end
    )
    |> true?()
  end

  @spec operation(
          unquote(@arg_typespec),
          unquote(@arg_typespec),
          (Image.t(), Image.t() -> Image.t()),
          (Image.t(), [number] -> Image.t()),
          ([number], Image.t() -> Image.t())
        ) :: term | no_return()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp operation(a, b, img_img_cb, img_list_cb, list_img_cb) do
    cond do
      image?(a) && is_number(b) ->
        operation(a, [b], img_img_cb, img_list_cb, list_img_cb)

      is_number(a) && image?(b) ->
        operation([a], b, img_img_cb, img_list_cb, list_img_cb)

      image?(a) && image?(b) ->
        img_img_cb.(a, b)

      image?(a) && is_list(b) ->
        validate_number_list!(b)
        img_list_cb.(a, b)

      is_list(a) && image?(b) ->
        validate_number_list!(a)
        list_img_cb.(a, b)

      true ->
        raise ArgumentError
    end
  end

  @spec validate_number_list!([number]) :: :ok | no_return
  defp validate_number_list!(arg) do
    if not Enum.all?(arg, &is_number/1) do
      raise ArgumentError, "list elements must be a number, got: #{inspect(arg)}"
    end

    :ok
  end

  defp image?(%Image{}), do: true
  defp image?(_), do: false

  @spec true?(Image.t()) :: boolean
  defp true?(%Image{} = image) do
    {min, _additional_output} = Operation.min!(image, size: 1)
    min == 255.0
  end
end
