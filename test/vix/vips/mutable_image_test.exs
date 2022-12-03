defmodule Vix.Vips.MutableImageTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image
  alias Vix.Vips.MutableImage

  import Vix.Support.Images

  test "update" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mim} = MutableImage.new(im)

    assert :ok == MutableImage.update(mim, "orientation", 0)
    assert {:ok, 0} == MutableImage.get(mim, "orientation")
  end

  test "set" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mim} = MutableImage.new(im)

    assert {:error, "No such field"} == MutableImage.get(mim, "new-field")
    assert :ok == MutableImage.set(mim, "new-field", :gdouble, 0)
    assert {:ok, 0.0} === MutableImage.get(mim, "new-field")
  end

  test "remove" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mim} = MutableImage.new(im)

    assert {:ok, 1} == MutableImage.get(mim, "orientation")

    assert :ok == MutableImage.remove(mim, "orientation")
    assert {:error, "No such field"} == MutableImage.get(mim, "orientation")
  end

  test "set with invalid type" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mim} = MutableImage.new(im)

    assert {:error,
            "invalid gtype. Supported types are [:gint, :guint, :gdouble, :gboolean, :gchararray, :VipsArrayInt, :VipsArrayDouble, :VipsArrayImage, :VipsRefString, :VipsBlob, :VipsImage, :VipsInterpolate]"} ==
             MutableImage.set(mim, "orientation", "asdf", 0)
  end

  test "to_image" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mim} = MutableImage.new(im)

    :ok = MutableImage.set(mim, "orientation", :gint, 0)
    assert {:ok, %Vix.Vips.Image{} = new_img} = MutableImage.to_image(mim)

    assert {:ok, 0} == Image.header_value(new_img, "orientation")
  end

  test "introspection" do
    {:ok, i} = Vix.Vips.Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, {_, 518}} = Vix.Vips.Image.mutate(i, fn m -> Vix.Vips.MutableImage.width(m) end)
    assert {:ok, {_, 389}} = Vix.Vips.Image.mutate(i, fn m -> Vix.Vips.MutableImage.height(m) end)
    assert {:ok, {_, 3}} = Vix.Vips.Image.mutate(i, fn m -> Vix.Vips.MutableImage.bands(m) end)

    assert {:ok, {_, false}} =
             Vix.Vips.Image.mutate(i, fn m -> Vix.Vips.MutableImage.has_alpha?(m) end)
  end
end
