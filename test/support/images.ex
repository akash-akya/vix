defmodule Vix.Support.Images do
  @moduledoc false

  import ExUnit.Assertions
  alias Vix.Vips.Image

  @images_path Path.join(__DIR__, "../images")

  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  def img_path(name) do
    Path.join(@images_path, name)
  end

  def assert_images_equal(a, b) do
    case Vix.Vips.Operation.relational(a, b, :VIPS_OPERATION_RELATIONAL_EQUAL) do
      {:ok, img} ->
        {min, _additional_output} = Vix.Vips.Operation.min!(img, size: 1)
        assert min == 255.0, "Images are not equal"

      {:error, reason} ->
        flunk("Failed to compare images, error: #{inspect(reason)}")
    end
  end

  def shape(image) do
    {Image.width(image), Image.height(image), Image.bands(image)}
  end

  def range_has_step do
    Map.has_key?(1..2, :step)
  end
end
