defmodule Vix.Support.Images do
  import ExUnit.Assertions

  @images_path Path.join(__DIR__, "../images")

  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  def img_path(name) do
    Path.join(@images_path, name)
  end

  defp expected(action, name) do
    Path.join(@images_path, "#{action}_#{name}")
  end
end
