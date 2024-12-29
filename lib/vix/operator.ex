defmodule Vix.Operator do
  @moduledoc """

  Provides an intuitive and readable interface for performing image processing operations by overriding common mathematical and relational operators.

  This module simplifies complex image processing pipelines by allowing you to use familiar operators, such as `+`, `-`, `*`, `/`, and comparison operators (`==`, `>=`, etc.), directly with images, numbers, and lists of numbers (pixels). It also includes utility functions for logical operations and validation, like `all?/2`.

  ### Key Features

  - **Bitwise Operations**: Perform Bitwise Boolean operations such as `&&`, `||`, and `xor` between images and numbers.
  - **Arithmetic Operations**: Use operators such as `+`, `-`, `*`, `/`, and `**` to perform pixel-wise operations between images, numbers, or lists of numbers.
  - **Comparison Operations**: Compare pixel values using operators like `==`, `!=`, `<`, `<=`, `>`, and `>=`, returning the result as a new image.
  - **Logical Validation**: Check pixel values for truthiness (e.g., `255` for true, `0` for false) using `all?/2`.

  ### Example Usage

  ```elixir
  defmodule Example do
   alias Vix.Vips.Operation

   def demo_operations do
     # Import only the required operators for readability and clarity
     use Vix.Operator, only: [+: 2, -: 2, *: 2, /: 2, ==: 2, all?: 2]

     # Create a black image (100x100, 3 bands)
     black = Image.build_image!(100, 100, [0, 0, 0])

     # Add constant values to pixels
     grey1 = black + 125
     grey2 = black + [125, 125, 125]

     # Pixel-wise addition: [255, 255, 255] + [0, 0, 0]
     result_image = white + grey1

     # Create a white image
     white = Image.build_image!(100, 100, [255, 255, 255])

     result = (black + 255) == white
     true = all?(result, true)
   end
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

  import Kernel,
    except: [
      +: 2,
      -: 2,
      *: 2,
      /: 2,
      **: 2,
      <: 2,
      >: 2,
      >=: 2,
      <=: 2,
      ==: 2,
      !=: 2,
      &&: 2,
      ||: 2
    ]

  @doc false
  defmacro __using__(opts) do
    overriden_operators = [
      +: 2,
      -: 2,
      *: 2,
      /: 2,
      **: 2,
      <: 2,
      >: 2,
      >=: 2,
      <=: 2,
      ==: 2,
      !=: 2,
      &&: 2,
      ||: 2
    ]

    vix_specific_operators = [xor: 2, all?: 2]

    [only: only] =
      opts
      |> Keyword.validate!(only: overriden_operators ++ vix_specific_operators)
      |> Enum.sort()

    quote do
      import Kernel, except: unquote(only)
      import Vix.Operator, only: unquote(only)
    end
  end

  defmodule Helper do
    @moduledoc false

    @spec readable_name(atom) :: String.t()
    def readable_name(op_function) do
      op_function
      |> to_string()
      |> String.split("-")
      |> Enum.map_join(" ", &String.capitalize/1)
    end

    @spec operator_exported?(atom, pos_integer) :: boolean
    def operator_exported?(op, arity) do
      macro_exported?(Kernel, op, arity) or function_exported?(Kernel, op, arity)
    end
  end

  alias Vix.Operator.Helper

  @doc """
  Checks if all of the values are "true" (255) or "false" (0).
  Useful together with relational operators.

  ### Examples

  Check if two images are equal

  ```elixir
  iex> all?(Image.build_image!(10, 20, [255, 255, 255]), true)
  true
  iex> img = (Image.build_image!(10, 20, [50, 100, 150]) == Image.build_image!(10, 20, [50, 100, 150]))
  iex> all?(img, true)
  true
  iex> img = (Image.build_image!(10, 20, [100, 150, 200]) < Image.build_image!(10, 20, [50, 100, 150]))
  iex> all?(img, true)
  false
  iex> all?(img, false)
  true
  ```
  """
  @spec all?(Image.t(), boolean()) :: boolean
  def all?(%Image{} = image, true) do
    {min, _additional_output} = Operation.min!(image, size: 1)
    min == 255.0
  end

  def all?(%Image{} = image, false) do
    {max, _additional_output} = Operation.max!(image, size: 1)
    max == +0.0
  end

  ### Arithmetic Operators

  @basic_arithmetic_format_doc """
  ### Type Handling

  Output Image Band Format:

  - Two images: Cast to smallest common format that can hold result
  - Image + number:
    - Complex input → Complex output
    - Double input → Double output
    - otherwise → Float output

  """

  @pow_format_doc """
  ### Type Handling

  Output Image Band Format:

  - Two images: Cast to smallest common format that can hold result
  - Image + number:
    - Double input → Double output
    - otherwise  → Float output

  """

  [
    %{
      name: :addition,
      operator: :+,
      desc: @basic_arithmetic_format_doc,
      examples: """
      ### Basic Image Addition
      ```elixir
      # Adding two single-band images
      iex> img1 = Image.build_image!(2, 2, [10])
      iex> img2 = Image.build_image!(2, 2, [20])
      iex> result = img1 + img2
      iex> Image.to_list!(result)
      [[[30], [30]], [[30], [30]]]

      # Adding images with different bands
      iex> multi_band = Image.build_image!(1, 2, [10, 20, 30])
      iex> single_band = Image.build_image!(1, 2, [5])
      iex> result = multi_band + single_band
      iex> Image.to_list!(result)
      [[[15, 25, 35]], [[15, 25, 35]]]
      ```

      ### Image and Number Operations
      ```elixir
      # Adding a number to all bands
      iex> img = Image.build_image!(1, 1, [10, 20, 30]) + 5
      iex> Image.to_list!(img)
      [[[15.0, 25.0, 35.0]]]

      # Adding float (demonstrates type conversion)
      iex> img = Image.build_image!(1, 1, [10]) + 5.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      iex> Image.to_list!(img)
      [[[15.5]]]
      ```

      ### List Operations
      ```elixir
      # List matching image bands
      iex> img = Image.build_image!(1, 2, [10, 20]) + [5, 10]
      iex> Image.to_list!(img)
      [[[15.0, 30.0]], [[15.0, 30.0]]]

      # List larger than bands (expands single-band image)
      iex> img = Image.build_image!(1, 2, [10]) + [5, 10, 15]
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[15.0, 20.0, 25.0]], [[15.0, 20.0, 25.0]]]
      ```

      ### Reverse Operations
      ```elixir
      # Number on the left side
      iex> img = 5 + Image.build_image!(1, 2, [10, 20])
      iex> Image.to_list!(img)
      [[[15.0, 25.0]], [[15.0, 25.0]]]

      # List on the left side
      iex> img = [5, 10, 15] + Image.build_image!(1, 2, [10])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[15.0, 20.0, 25.0]], [[15.0, 20.0, 25.0]]]
      ```

      ### Type Casting Examples
      ```elixir
      # Integer to float conversion
      iex> img = Image.build_image!(2, 2, [10]) + 5.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.+ behavior when no images involved
      iex> 5 + 10
      15
      ```
      """
    },
    %{
      name: :subtraction,
      operator: :-,
      desc: @basic_arithmetic_format_doc,
      examples: """
      ### Basic Image Subtraction
      ```elixir
      # Subtracting two single-band images
      iex> img1 = Image.build_image!(2, 2, [30])
      iex> img2 = Image.build_image!(2, 2, [10])
      iex> result = img1 - img2
      iex> Image.to_list!(result)
      [[[20], [20]], [[20], [20]]]

      # Subtracting images with different bands
      iex> multi_band = Image.build_image!(1, 2, [30, 40, 50])
      iex> single_band = Image.build_image!(1, 2, [10])
      iex> result = multi_band - single_band
      iex> Image.to_list!(result)
      [[[20, 30, 40]], [[20, 30, 40]]]
      ```

      ### Image and Number Operations
      ```elixir
      # Subtracting a number from all bands
      iex> img = Image.build_image!(1, 1, [50, 60, 70]) - 20
      iex> Image.to_list!(img)
      [[[30.0, 40.0, 50.0]]]

      # Subtracting a float (demonstrates type conversion)
      iex> img = Image.build_image!(1, 1, [50]) - 15.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      iex> Image.to_list!(img)
      [[[34.5]]]
      ```

      ### List Operations
      ```elixir
      # List matching image bands
      iex> img = Image.build_image!(1, 2, [30, 50]) - [10, 20]
      iex> Image.to_list!(img)
      [[[20.0, 30.0]], [[20.0, 30.0]]]

      # List larger than bands (expands single-band image)
      iex> img = Image.build_image!(1, 2, [30]) - [5, 10, 15]
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[25.0, 20.0, 15.0]], [[25.0, 20.0, 15.0]]]
      ```

      ### Reverse Operations
      ```elixir
      # Number on the left side
      iex> img = 100 - Image.build_image!(1, 2, [30, 50])
      iex> Image.to_list!(img)
      [[[70.0, 50.0]], [[70.0, 50.0]]]

      # List on the left side
      iex> img = [50, 60, 70] - Image.build_image!(1, 2, [20])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[30.0, 40.0, 50.0]], [[30.0, 40.0, 50.0]]]
      ```

      ### Type Casting Examples
      ```elixir
      # Integer to float conversion
      iex> img = Image.build_image!(2, 2, [30]) - 10.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.- behavior when no images involved
      iex> 50 - 20
      30
      ```
      """
    },
    %{
      name: :multiplication,
      operator: :*,
      desc: @basic_arithmetic_format_doc,
      examples: """
      ### Basic Image Multiplication
      ```elixir
      # Multiplying two single-band images
      iex> img1 = Image.build_image!(2, 2, [3])
      iex> img2 = Image.build_image!(2, 2, [4])
      iex> result = img1 * img2
      iex> Image.to_list!(result)
      [[[12], [12]], [[12], [12]]]

      # Multiplying images with different bands
      iex> multi_band = Image.build_image!(1, 2, [2, 3, 4])
      iex> single_band = Image.build_image!(1, 2, [5])
      iex> result = multi_band * single_band
      iex> Image.to_list!(result)
      [[[10, 15, 20]], [[10, 15, 20]]]
      ```

      ### Image and Number Operations
      ```elixir
      # Multiplying all bands by a number
      iex> img = Image.build_image!(1, 1, [6, 7, 8]) * 3
      iex> Image.to_list!(img)
      [[[18.0, 21.0, 24.0]]]

      # Multiplying by a float (demonstrates type conversion)
      iex> img = Image.build_image!(1, 1, [10]) * 2.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      iex> Image.to_list!(img)
      [[[25.0]]]
      ```

      ### List Operations
      ```elixir
      # List matching image bands
      iex> img = Image.build_image!(1, 2, [2, 3]) * [4, 5]
      iex> Image.to_list!(img)
      [[[8.0, 15.0]], [[8.0, 15.0]]]

      # List larger than bands (expands single-band image)
      iex> img = Image.build_image!(1, 2, [3]) * [2, 4, 6]
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[6.0, 12.0, 18.0]], [[6.0, 12.0, 18.0]]]
      ```

      ### Reverse Operations
      ```elixir
      # Number on the left side
      iex> img = 10 * Image.build_image!(1, 2, [2, 4])
      iex> Image.to_list!(img)
      [[[20.0, 40.0]], [[20.0, 40.0]]]

      # List on the left side
      iex> img = [2, 3, 4] * Image.build_image!(1, 2, [5])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[10.0, 15.0, 20.0]], [[10.0, 15.0, 20.0]]]
      ```

      ### Type Casting Examples
      ```elixir
      # Integer to float conversion
      iex> img = Image.build_image!(2, 2, [4]) * 2.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.* behavior when no images involved
      iex> 5 * 3
      15
      ```
      """
    },
    %{
      name: :division,
      operator: :/,
      desc: @basic_arithmetic_format_doc,
      examples: """
      ### Basic Image Division
      ```elixir
      # Dividing two single-band images
      iex> img1 = Image.build_image!(2, 2, [20])
      iex> img2 = Image.build_image!(2, 2, [4])
      iex> result = img1 / img2
      iex> Image.to_list!(result)
      [[[5.0], [5.0]], [[5.0], [5.0]]]

      # Dividing images with different bands
      iex> multi_band = Image.build_image!(1, 2, [20, 30, 40])
      iex> single_band = Image.build_image!(1, 2, [10])
      iex> result = multi_band / single_band
      iex> Image.to_list!(result)
      [[[2.0, 3.0, 4.0]], [[2.0, 3.0, 4.0]]]

      # Dividing two images where the divisor contains zero.
      # Vix detects division by zero, and sets those pixels to zero in
      # the output, without any error or warning.
      iex> img1 = Image.build_image!(2, 2, [20])
      iex> img2 = Image.build_image!(2, 2, [0])
      iex> result = img1 / img2
      iex> Image.to_list!(result)
      [[[0.0], [0.0]], [[0.0], [0.0]]]
      ```

      ### Image and Number Operations
      ```elixir
      # Dividing all bands by a number
      iex> img = Image.build_image!(1, 1, [30, 60, 90]) / 10
      iex> Image.to_list!(img)
      [[[3.0, 6.0, 9.0]]]

      # Dividing by a float (demonstrates type conversion)
      iex> img = Image.build_image!(1, 1, [25]) / 2.5
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      iex> Image.to_list!(img)
      [[[10.0]]]
      ```

      ### List Operations
      ```elixir
      # List matching image bands
      iex> img = Image.build_image!(1, 2, [40, 60]) / [4, 6]
      iex> Image.to_list!(img)
      [[[10.0, 10.0]], [[10.0, 10.0]]]

      # List larger than bands (expands single-band image)
      iex> img = Image.build_image!(1, 2, [30]) / [3, 6, 5]
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[10.0, 5.0, 6.0]], [[10.0, 5.0, 6.0]]]
      ```

      ### Reverse Operations
      ```elixir
      # Number on the left side
      iex> img = 100 / Image.build_image!(1, 2, [5, 10])
      iex> Image.to_list!(img)
      [[[20.0, 10.0]], [[20.0, 10.0]]]

      # List on the left side
      iex> img = [100, 200, 300] / Image.build_image!(1, 2, [10])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[10.0, 20.0, 30.0]], [[10.0, 20.0, 30.0]]]
      ```

      ### Type Casting Examples
      ```elixir
      # Integer to float conversion
      iex> img = Image.build_image!(2, 2, [25]) / 2
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel./ behavior when no images involved
      iex> 10 / 2
      5.0
      ```
      """
    },
    %{
      name: :power,
      operator: :**,
      desc: @pow_format_doc,
      examples: """
      ### Basic Image Power Operation
      ```elixir
      # Raising each pixel of a single-band image to the power of another single-band image
      iex> img1 = Image.build_image!(2, 2, [2])
      iex> img2 = Image.build_image!(2, 2, [3])
      iex> result = img1 ** img2
      iex> Image.to_list!(result)
      [[[8.0], [8.0]], [[8.0], [8.0]]]

      # Raising multi-band image pixels to the power of single-band image
      iex> multi_band = Image.build_image!(1, 2, [2, 3, 4])
      iex> single_band = Image.build_image!(1, 2, [2])
      iex> result = multi_band ** single_band
      iex> Image.to_list!(result)
      [[[4.0, 9.0, 16.0]], [[4.0, 9.0, 16.0]]]
      ```

      ### Image and Number Operations
      ```elixir
      # Raising all bands of an image to a constant power
      iex> img = Image.build_image!(1, 1, [3, 4, 5]) ** 2
      iex> Image.to_list!(img)
      [[[9.0, 16.0, 25.0]]]

      # Raising image pixels to a fractional power
      iex> img = Image.build_image!(1, 1, [16]) ** 0.5
      iex> Image.to_list!(img)
      [[[4.0]]]
      ```

      ### List Operations
      ```elixir
      # List matching image bands
      iex> img = Image.build_image!(1, 2, [2, 3]) ** [3, 2]
      iex> Image.to_list!(img)
      [[[8.0, 9.0]], [[8.0, 9.0]]]

      # List larger than bands (expands single-band image)
      iex> img = Image.build_image!(1, 2, [2]) ** [3, 4, 5]
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[8.0, 16.0, 32.0]], [[8.0, 16.0, 32.0]]]
      ```

      ### Reverse Operations
      ```elixir
      # Number on the left side
      iex> img = 2 ** Image.build_image!(1, 2, [3, 4])
      iex> Image.to_list!(img)
      [[[8.0, 16.0]], [[8.0, 16.0]]]

      # List on the left side
      iex> img = [2, 3, 4] ** Image.build_image!(1, 2, [2])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[4.0, 9.0, 16.0]], [[4.0, 9.0, 16.0]]]
      ```

      ### Type Casting Examples
      ```elixir
      # Always returns float output
      iex> img = Image.build_image!(2, 2, [3]) ** 2
      iex> Image.format(img)
      :VIPS_FORMAT_FLOAT
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.** behavior when no images involved
      iex> 2 ** 3
      8
      ```
      """
    }
  ]
  |> Enum.each(fn %{name: name, operator: op, desc: desc, examples: examples} ->
    readable_name = Helper.readable_name(name)
    title = "#{readable_name} (#{op})"

    @doc """
    Performs #{title} operation between Images, numbers, and lists of numbers (pixels).

    ## Overview

    The operator handles Images, numbers, and lists together with the following rules:
    - Single numbers are applied to all image bands
    - Lists can be matched with image bands
    - Type casting is handled automatically
    - When neither argument is an image, delegates to `Kernel.#{op}/2`

    ## Behavior

    ### #{readable_name} Rules

    When operating with numbers or lists:

    - Single number: Applied to all image bands
    - List matching image bands: Each number maps to corresponding band
    - List size does not match bands: Creates multi-band output with either the image bands or the list is scaled up to match the other.
    - Two images: Bands are scaled up to match each other.

    #{desc}

    ## Examples

    #{examples}
    """
    @spec unquote(op)(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
    @spec unquote(op)(number, number) :: number()
    def unquote(op)(a, b) do
      if image?(a) or image?(b) do
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
      op_enum: :VIPS_OPERATION_RELATIONAL_LESS,
      inv_op_enum: :VIPS_OPERATION_RELATIONAL_MOREEQ,
      examples: """
      ### Basic Image Comparison

      ```elixir
      # Comparing two images
      iex> img = Image.build_image!(2, 2, [10, 15]) < Image.build_image!(2, 2, [5, 20])
      iex> Image.shape(img)
      {2, 2, 2}
      iex> Image.to_list!(img)
      [[[0, 255], [0, 255]], [[0, 255], [0, 255]]]
      ```

      ### Checking All Pixels
      ```elixir
      # Using all?/2 to verify if all pixels match condition
      iex> img = Image.build_image!(2, 2, [5]) < Image.build_image!(2, 2, [10])
      iex> all?(img, true)
      true
      ```

      ### Multi-band Image Operations
      ```elixir
      # Different band count scenarios
      iex> (Image.build_image!(10, 10, [10, 20, 30]) < Image.build_image!(10, 10, [20, 30, 40])) |> all?(true)
      true
      iex> (Image.build_image!(10, 10, [10]) < Image.build_image!(10, 10, [5, 10, 20])) |> all?(true)
      false
      ```

      ### Image vs. Number Comparison
      ```elixir
      # Single number compared to all bands
      iex> img = Image.build_image!(1, 2, [1, 10, 20]) < 5
      iex> Image.to_list!(img)
      [[[255, 0, 0]], [[255, 0, 0]]]

      # comparing different types
      iex> (Image.build_image!(10, 10, [10]) < 20.0) |> all?(true)
      true

      # List comparison with bands
      iex> img = Image.build_image!(1, 1, [10, 20]) < [20, 10]
      iex> Image.to_list!(img)
      [[[255, 0]]]
      ```

      ### Reverse Comparison
      ```elixir
      # Numbers/lists on the left side
      iex> (10.0 < Image.build_image!(10, 10, [20])) |> all?(true)
      true
      iex> ([10, 20, 30] < Image.build_image!(10, 10, [20, 30, 40])) |> all?(true)
      true
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.< behavior when no images involved
      iex> 4 < 5
      true
      ```
      """
    },
    %{
      name: :less_than_equal,
      operator: :<=,
      op_enum: :VIPS_OPERATION_RELATIONAL_LESSEQ,
      inv_op_enum: :VIPS_OPERATION_RELATIONAL_MORE,
      examples: """
      ## Examples

      ### Basic Image Comparison
      ```elixir
      # Comparing two images
      iex> img = Image.build_image!(2, 2, [10, 15]) <= Image.build_image!(2, 2, [5, 20])
      iex> Image.shape(img)
      {2, 2, 2}
      iex> Image.to_list!(img)
      [[[0, 255], [0, 255]], [[0, 255], [0, 255]]]
      ```

      ### Checking All Pixels
      ```elixir
      # Using all?/2 to verify if all pixels match condition
      iex> img = Image.build_image!(2, 2, [5]) <= Image.build_image!(2, 2, [10])
      iex> all?(img, true)
      true
      ```

      ### Multi-band Image Operations
      ```elixir
      # Different band count scenarios
      iex> (Image.build_image!(10, 10, [10, 20, 30]) <= Image.build_image!(10, 10, [20, 30, 40])) |> all?(true)
      true
      iex> (Image.build_image!(10, 10, [20]) <= Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      false
      iex> (Image.build_image!(10, 10, [1, 2, 3]) <= Image.build_image!(10, 10, [6])) |> all?(true)
      true
      ```

      ### Image vs. Number Comparison
      ```elixir
      # Single number compared to all bands
      iex> img = Image.build_image!(1, 2, [5, 10, 15]) <= 5
      iex> Image.to_list!(img)
      [[[255, 0, 0]], [[255, 0, 0]]]

      # Comparing with integer
      iex> (Image.build_image!(10, 10, [4]) <= 2) |> all?(true)
      false

      # Comparing with float
      iex> (Image.build_image!(10, 10, [4]) <= 4.0) |> all?(true)
      true

      # List comparison with bands
      iex> img = Image.build_image!(1, 1, [10, 20]) <= [20, 10]
      iex> Image.to_list!(img)
      [[[255, 0]]]
      ```

      ### Reverse Comparison
      ```elixir
      # Float on the left side
      iex> (4.0 <= Image.build_image!(10, 10, [5])) |> all?(true)
      true

      # List on the left side
      iex> ([10, 20, 30] <= Image.build_image!(10, 10, [20, 30, 40])) |> all?(true)
      true
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.<= behavior when no images involved
      iex> 4 <= 5
      true
      ```
      """
    },
    %{
      name: :greater_than,
      operator: :>,
      op_enum: :VIPS_OPERATION_RELATIONAL_MORE,
      inv_op_enum: :VIPS_OPERATION_RELATIONAL_LESSEQ,
      examples: """
      ## Examples

      ### Basic Image Comparison
      ```elixir
      # Comparing two images
      iex> img = Image.build_image!(2, 2, [10, 15]) > Image.build_image!(2, 2, [5, 20])
      iex> Image.shape(img)
      {2, 2, 2}
      iex> Image.to_list!(img)
      [[[255, 0], [255, 0]], [[255, 0], [255, 0]]]
      ```

      ### Checking All Pixels
      ```elixir
      # Using all?/2 to verify if all pixels match condition
      iex> img = Image.build_image!(2, 2, [10]) > Image.build_image!(2, 2, [5])
      iex> all?(img, true)
      true
      ```

      ### Multi-band Image Operations
      ```elixir
      # Equal values comparison
      iex> (Image.build_image!(10, 10, [10, 20, 30]) > Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      false

      # Multi-band vs single-band comparison
      iex> (Image.build_image!(10, 10, [10]) > Image.build_image!(10, 10, [20, 30, 40])) |> all?(true)
      false

      # Comparing with smaller value
      iex> (Image.build_image!(10, 10, [10, 20, 30]) > Image.build_image!(10, 10, [5])) |> all?(true)
      true
      ```

      ### Image vs. Number Comparison
      ```elixir
      # Single number compared to all bands
      iex> img = Image.build_image!(1, 2, [5, 15, 25]) > 20
      iex> Image.to_list!(img)
      [[[0, 0, 255]], [[0, 0, 255]]]

      # Comparing with integer
      iex> (Image.build_image!(10, 10, [10]) > 20) |> all?(true)
      false

      # Comparing with float
      iex> (Image.build_image!(10, 10, [20]) > 10.0) |> all?(true)
      true

      # List comparison with bands
      iex> img = Image.build_image!(1, 1, [10, 20]) > [20, 10]
      iex> Image.to_list!(img)
      [[[0, 255]]]
      ```

      ### Reverse Comparison
      ```elixir
      # Float on the left side
      iex> (5.0 > Image.build_image!(10, 10, [4])) |> all?(true)
      true

      # List on the left side
      iex> ([20, 30, 40] > Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      true
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.> behavior when no images involved
      iex> 5 > 4
      true
      ```
      """
    },
    %{
      name: :greater_than_equal,
      operator: :>=,
      op_enum: :VIPS_OPERATION_RELATIONAL_MOREEQ,
      inv_op_enum: :VIPS_OPERATION_RELATIONAL_LESS,
      examples: """
      ## Examples

      ### Basic Image Comparison
      ```elixir
      # Comparing two images
      iex> img = Image.build_image!(2, 2, [10, 15]) >= Image.build_image!(2, 2, [5, 20])
      iex> Image.shape(img)
      {2, 2, 2}
      iex> Image.to_list!(img)
      [[[255, 0], [255, 0]], [[255, 0], [255, 0]]]
      ```

      ### Checking All Pixels
      ```elixir
      # Using all?/2 to verify if all pixels match condition
      iex> img = Image.build_image!(2, 2, [10]) >= Image.build_image!(2, 2, [5])
      iex> all?(img, true)
      true
      ```

      ### Multi-band Image Operations
      ```elixir
      # Greater values comparison
      iex> (Image.build_image!(10, 10, [20, 30, 40]) >= Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      true

      # Equal values comparison
      iex> (Image.build_image!(10, 10, [10, 20, 30]) >= Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      true

      # Single vs multi-band comparison
      iex> (Image.build_image!(10, 10, [20]) >= Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      false

      # Multi vs single-band comparison
      iex> (Image.build_image!(10, 10, [10, 20, 30]) >= Image.build_image!(10, 10, [10])) |> all?(true)
      true
      ```

      ### Image vs. Number Comparison
      ```elixir
      # Single number compared to all bands
      iex> img = Image.build_image!(1, 2, [5, 10, 15]) >= 10
      iex> Image.to_list!(img)
      [[[0, 255, 255]], [[0, 255, 255]]]

      # Comparing with larger number
      iex> (Image.build_image!(10, 10, [10]) >= 20) |> all?(true)
      false

      # Comparing with float
      iex> (Image.build_image!(10, 10, [20]) >= 10.0) |> all?(true)
      true

      # List comparison with bands
      iex> img = Image.build_image!(1, 1, [10, 20]) >= [20, 10]
      iex> Image.to_list!(img)
      [[[0, 255]]]
      ```

      ### Reverse Comparison
      ```elixir
      # Float on the left side
      iex> (10.0 >= Image.build_image!(10, 10, [5])) |> all?(true)
      true

      # List on the left side
      iex> ([20, 30, 40] >= Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      true
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.>= behavior when no images involved
      iex> 5 >= 4
      true
      ```
      """
    },
    %{
      name: :equal,
      operator: :==,
      op_enum: :VIPS_OPERATION_RELATIONAL_EQUAL,
      inv_op_enum: :VIPS_OPERATION_RELATIONAL_EQUAL,
      examples: """
      ## Examples

      ### Basic Image Comparison
      ```elixir
      # Comparing two images
      iex> img = Image.build_image!(2, 2, [10, 20]) == Image.build_image!(2, 2, [20, 20])
      iex> Image.shape(img)
      {2, 2, 2}
      iex> Image.to_list!(img)
      [[[0, 255], [0, 255]], [[0, 255], [0, 255]]]
      ```

      ### Checking All Pixels
      ```elixir
      # Using all?/2 to verify if all pixels match condition
      iex> img = Image.build_image!(2, 2, [10]) == Image.build_image!(2, 2, [10])
      iex> all?(img, true)
      true
      ```

      ### Multi-band Image Operations
      ```elixir
      # Equal values across all bands
      iex> (Image.build_image!(10, 10, [10, 20, 30]) == Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      true

      # Single vs multi-band comparison
      iex> (Image.build_image!(10, 10, [20]) == Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      false

      # Same value across all bands equals single-band image
      iex> (Image.build_image!(10, 10, [10, 10, 10]) == Image.build_image!(10, 10, [10])) |> all?(true)
      true
      ```

      ### Image vs. Number Comparison
      ```elixir
      # Single number compared to all bands
      iex> img = Image.build_image!(1, 2, [5, 10, 20]) == 5
      iex> Image.to_list!(img)
      [[[255, 0, 0]], [[255, 0, 0]]]

      # Non-matching comparison
      iex> (Image.build_image!(10, 10, [10]) == 5) |> all?(true)
      false

      # Float comparison (type coercion)
      iex> (Image.build_image!(10, 10, [10]) == 10.0) |> all?(true)
      true

      # List comparison with bands
      iex> img = Image.build_image!(1, 1, [10, 20]) == [10, 10]
      iex> Image.to_list!(img)
      [[[255, 0]]]
      ```

      ### Reverse Comparison
      ```elixir
      # Float on the left side
      iex> (10.0 == Image.build_image!(10, 10, [10])) |> all?(true)
      true

      # List on the left side
      iex> ([10, 20, 30] == Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      true
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.== behavior when no images involved
      iex> 4 == 4
      true
      ```
      """
    },
    %{
      name: :not_equal,
      operator: :!=,
      op_enum: :VIPS_OPERATION_RELATIONAL_NOTEQ,
      inv_op_enum: :VIPS_OPERATION_RELATIONAL_NOTEQ,
      examples: """
      ## Examples

      ### Basic Image Comparison
      ```elixir
      # Comparing two images
      iex> img = Image.build_image!(2, 2, [10, 15]) != Image.build_image!(2, 2, [15, 15])
      iex> Image.shape(img)
      {2, 2, 2}
      iex> Image.to_list!(img)
      [[[255, 0], [255, 0]], [[255, 0], [255, 0]]]
      ```

      ### Checking All Pixels
      ```elixir
      # Using all?/2 to verify if all pixels match condition
      iex> img = Image.build_image!(2, 2, [5]) != Image.build_image!(2, 2, [10])
      iex> all?(img, true)
      true
      ```

      ### Multi-band Image Operations
      ```elixir
      # Same values across all bands (should be false)
      iex> (Image.build_image!(10, 10, [10, 20, 30]) != Image.build_image!(10, 10, [10, 20, 30])) |> all?(true)
      false

      # Different values between single and multi-band
      iex> (Image.build_image!(10, 10, [20]) != Image.build_image!(10, 10, [10, 10, 10])) |> all?(true)
      true

      # Multi-band vs single-band with matching values
      iex> (Image.build_image!(10, 10, [10, 20, 30]) != Image.build_image!(10, 10, [30])) |> all?(true)
      false
      ```

      ### Image vs. Number Comparison
      ```elixir
      # Single number compared to all bands
      iex> img = Image.build_image!(1, 2, [5, 10, 20]) != 5
      iex> Image.to_list!(img)
      [[[0, 255, 255]], [[0, 255, 255]]]

      # Comparing with same value (should be false)
      iex> (Image.build_image!(10, 10, [10]) != 10) |> all?(true)
      false

      # Float comparison with different value
      iex> (Image.build_image!(10, 10, [10]) != 20.0) |> all?(true)
      true

      # List comparison with bands
      iex> img = Image.build_image!(1, 1, [10, 20]) != [10, 10]
      iex> Image.to_list!(img)
      [[[0, 255]]]
      ```

      ### Reverse Comparison
      ```elixir
      # Float on the left side
      iex> (10.0 != Image.build_image!(10, 10, [20])) |> all?(true)
      true

      # List on the left side
      iex> ([10, 20, 30] != Image.build_image!(10, 10, [20, 30, 40])) |> all?(true)
      true
      ```

      ### Fallback Behavior
      ```elixir
      # Standard Kernel.!= behavior when no images involved
      iex> 4 != 5
      true
      ```
      """
    }
  ]
  |> Enum.each(fn %{
                    name: name,
                    operator: op,
                    op_enum: op_enum,
                    inv_op_enum: inv_op_enum,
                    examples: examples
                  } ->
    readable_name = Helper.readable_name(name)
    title = "#{readable_name} (#{op})"

    @doc """
    Performs #{title} comparison between Images and numbers, returning the result as an Image.

    ## Overview

    The operator compares Images and numbers, with the result being an Image where:
    - `0` represents `false`
    - `255` represents `true`

    When neither argument is an image, the operation delegates to `Kernel.#{op}/2`.

    ## Behavior

    ### Image Comparison Rules

    - Single number: Applied to all image bands
    - List matching image bands: Each number maps to corresponding band
    - List size does not match bands: Creates multi-band output with either the image bands or the list is scaled up to match the other.
    - Two images: Uses `Operation.relational!(a, b, #{inspect(op_enum)})`. Bands are scaled up to match each other.

    ### Type Handling
    - Images are cast to the smallest common format before comparison
    - Supports mixed numeric types (e.g., integers with floats)
    - Works bidirectionally (image < number and number < image)

    ## Examples

    #{examples}
    """
    @spec unquote(op)(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
    @spec unquote(op)(term, term) :: boolean()
    def unquote(op)(a, b) do
      unquote(name)(a, b)
    end

    defp unquote(name)(a, b) do
      if image?(a) or image?(b) do
        relational_operation(a, b, unquote(op_enum), unquote(inv_op_enum))
      else
        Kernel.unquote(op)(a, b)
      end
    end
  end)

  @spec relational_operation(unquote(@arg_typespec), unquote(@arg_typespec), atom, atom) ::
          Image.t() | no_return()
  defp relational_operation(a, b, op_enum, inv_op_enum) do
    operation(
      a,
      b,
      fn %Image{} = a, %Image{} = b ->
        Operation.relational!(a, b, op_enum)
      end,
      fn %Image{} = a, b when is_list(b) ->
        Operation.relational_const!(a, op_enum, b)
      end,
      fn a, %Image{} = b when is_list(a) ->
        Operation.relational_const!(b, inv_op_enum, a)
      end
    )
  end

  ### Bitwise Boolean Operators

  [
    %{
      name: :boolean_and,
      operator: :&&,
      op_enum: :VIPS_OPERATION_BOOLEAN_AND,
      examples: """
      ## Image && Image Operations

      ```elixir
      iex> img = Image.build_image!(2, 1, [0, 255, 0]) && Image.build_image!(2, 1, [0, 255, 255])
      iex> Image.shape(img)
      {2, 1, 3}
      iex> Image.to_list!(img)
      [[[0, 255, 0], [0, 255, 0]]]

      # Identical Images
      iex> (Image.build_image!(2, 2, [2, 4, 8]) && Image.build_image!(2, 2, [2, 4, 8])) |> Image.to_list!()
      [[[2, 4, 8], [2, 4, 8]], [[2, 4, 8], [2, 4, 8]]]

      # Different dimensions
      iex> img = Image.build_image!(1, 1, [2]) && Image.build_image!(1, 2, [2, 4, 8])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[2, 0, 0]], [[0, 0, 0]]]
      ```

      ## Image && Number Operations

      ```elixir
      # Single number comparison (applies to all bands)
      iex> (Image.build_image!(1, 2, [2, 5, 3]) && 6) |> Image.to_list!()
      [[[2, 4, 2]], [[2, 4, 2]]]

      # Float Comparison
      iex> (Image.build_image!(1, 1, [10]) && 6.0) |> Image.to_list!()
      [[[2]]]

      # List comparison (band-wise)
      iex> (Image.build_image!(1, 1, [2, 2]) && [1, 3]) |> Image.to_list!()
      [[[0, 2]]]
      ```

      ## Reverse Operations

      ```elixir
      # Number && Image
      iex> (10.0 && Image.build_image!(1, 1, [5])) |> Image.to_list!()
      [[[0]]]

      # List && Image
      iex> ([2, 2] && Image.build_image!(1, 1, [1, 3])) |> Image.to_list!()
      [[[0, 2]]]
      ```

      ## Kernel Fallback

      ```elixir
      # When neither argument is an image
      iex> false && true
      false
      ```
      """
    },
    %{
      name: :boolean_or,
      operator: :||,
      op_enum: :VIPS_OPERATION_BOOLEAN_OR,
      examples: """
      ## Image || Image Operations

      ```elixir
      iex> img = Image.build_image!(2, 1, [0, 255, 0]) || Image.build_image!(2, 1, [0, 255, 255])
      iex> Image.shape(img)
      {2, 1, 3}
      iex> Image.to_list!(img)
      [[[0, 255, 255], [0, 255, 255]]]

      # Identical Images
      iex> (Image.build_image!(2, 2, [2, 4, 8]) || Image.build_image!(2, 2, [2, 4, 8])) |> Image.to_list!()
      [[[2, 4, 8], [2, 4, 8]], [[2, 4, 8], [2, 4, 8]]]

      # Different dimensions
      iex> img = Image.build_image!(1, 1, [2]) || Image.build_image!(1, 2, [2, 4, 8])
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[2, 6, 10]], [[2, 4, 8]]]
      ```

      ## Image || Number Operations

      ```elixir
      # Single number comparison (applies to all bands)
      iex> (Image.build_image!(1, 2, [2, 4, 8]) || 4) |> Image.to_list!()
      [[[6, 4, 12]], [[6, 4, 12]]]

      # Float Comparison
      iex> (Image.build_image!(1, 1, [4]) || 2.0) |> Image.to_list!()
      [[[6]]]

      # List comparison (band-wise)
      iex> (Image.build_image!(1, 1, [2, 2]) || [1, 3]) |> Image.to_list!()
      [[[3, 3]]]
      ```

      ## Reverse Operations

      ```elixir
      # Number || Image
      iex> (4.0 || Image.build_image!(1, 1, [2])) |> Image.to_list!()
      [[[6]]]

      # List || Image
      iex> ([2, 2] || Image.build_image!(1, 1, [1, 3])) |> Image.to_list!()
      [[[3, 3]]]
      ```

      ## Kernel Fallback

      ```elixir
      # When neither argument is an image
      iex> false || true
      true
      ```
      """
    },
    %{
      name: :boolean_xor,
      operator: :xor,
      op_enum: :VIPS_OPERATION_BOOLEAN_EOR,
      examples: """
      ## Image XOR Image Operations

      ```elixir
      iex> img = xor(Image.build_image!(2, 1, [0, 255, 0]), Image.build_image!(2, 1, [0, 255, 255]))
      iex> Image.shape(img)
      {2, 1, 3}
      iex> Image.to_list!(img)
      [[[0, 0, 255], [0, 0, 255]]]

      # Identical Images
      iex> xor(Image.build_image!(2, 2, [2, 4, 8]), Image.build_image!(2, 2, [2, 4, 8])) |> Image.to_list!()
      [[[0, 0, 0], [0, 0, 0]], [[0, 0, 0], [0, 0, 0]]]

      # Different dimensions
      iex> img = xor(Image.build_image!(1, 1, [2]), Image.build_image!(1, 2, [2, 4, 8]))
      iex> Image.shape(img)
      {1, 2, 3}
      iex> Image.to_list!(img)
      [[[0, 6, 10]], [[2, 4, 8]]]
      ```

      ## Image XOR Number Operations

      ```elixir
      # Single number comparison (applies to all bands)
      iex> xor(Image.build_image!(1, 2, [2, 5, 3]), 6) |> Image.to_list!()
      [[[4, 3, 5]], [[4, 3, 5]]]

      # Float Comparison
      iex> xor(Image.build_image!(1, 1, [10]), 6.0) |> Image.to_list!()
      [[[12]]]

      # List comparison (band-wise)
      iex> xor(Image.build_image!(1, 1, [2, 2]), [1, 3]) |> Image.to_list!()
      [[[3, 1]]]
      ```

      ## Reverse Operations

      ```elixir
      # Number XOR Image
      iex> xor(10.0, Image.build_image!(1, 1, [5])) |> Image.to_list!()
      [[[15]]]

      # List XOR Image
      iex> xor([2, 2], Image.build_image!(1, 1, [1, 3])) |> Image.to_list!()
      [[[3, 1]]]
      ```
      """
    }
  ]
  |> Enum.each(fn %{name: name, operator: op, op_enum: op_enum, examples: examples} ->
    "BOOLEAN_" <> op_name = String.upcase(to_string(name))

    exported? = Helper.operator_exported?(op, 2)

    @doc """
    Performs Bitwise Boolean #{op_name} Operation (#{op}) between Images and numbers, returning the result as an Image.

    ## Overview

    The operation handles various input combinations:

    * Image #{op} Image
    * Image #{op} number(s)
    * number(s) #{op} Image
    #{if exported?, do: "* non-Image values (falls back to `Kernel`)"}

    ## Input Handling

    Values are cast up before operations. Float values are converted to integers

    ### Number Inputs
    - Single number: Applied to all image bands uniformly
    - Number list:
      - If list size matches image bands: Each number applies to its respective band
      - If list size does not match the image bands: Either the image bands or the list is scaled up to match the other.

    ### Image Inputs
    - When both inputs are images: Uses `Operation.boolean!(a, b, #{inspect(op_enum)})`


    # Examples

    #{examples}
    """

    @spec unquote(op)(unquote(@arg_typespec), unquote(@arg_typespec)) :: Image.t()
    @spec unquote(op)(term, term) :: term
    def unquote(op)(a, b) do
      unquote(name)(a, b)
    end

    if exported? do
      defp unquote(name)(a, b) do
        if image?(a) or image?(b) do
          boolean_operation(a, b, unquote(op_enum))
        else
          Kernel.unquote(op)(a, b)
        end
      end
    else
      defp unquote(name)(a, b) do
        if image?(a) or image?(b) do
          boolean_operation(a, b, unquote(op_enum))
        else
          raise ArgumentError, "one of the argument must be an Image"
        end
      end
    end
  end)

  @spec boolean_operation(unquote(@arg_typespec), unquote(@arg_typespec), atom) ::
          Image.t() | no_return()
  defp boolean_operation(a, b, op) do
    operation(
      a,
      b,
      fn %Image{} = a, %Image{} = b ->
        Operation.boolean!(a, b, op)
      end,
      fn %Image{} = a, b when is_list(b) ->
        Operation.boolean_const!(a, op, b)
      end,
      fn a, %Image{} = b when is_list(a) ->
        Operation.boolean_const!(b, op, a)
      end
    )
  end

  @spec operation(
          unquote(@arg_typespec),
          unquote(@arg_typespec),
          (Image.t(), Image.t() -> Image.t()),
          (Image.t(), [number] -> Image.t()),
          ([number], Image.t() -> Image.t())
        ) :: Image.t() | no_return()
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
end
