defmodule Vix.Vips.MutableImage do
  defstruct [:pid]

  alias __MODULE__
  alias Vix.Type
  alias Vix.Vips.Image

  @moduledoc """
  Vips Mutable Image

  See `Vix.Vips.Image.mutate/2`
  """

  alias Vix.Nif

  @behaviour Type

  @typedoc """
  Represents a mutable instance of VipsImage
  """

  @type t() :: %MutableImage{pid: pid}

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def default(nil) do
    raise "default/1 for Vix.Vips.MutableImage is not supported"
  end

  @impl Type
  def to_nif_term(%Image{} = image, data) do
    Image.to_nif_term(image, data)
  end

  def to_nif_term(%MutableImage{}, _data) do
    raise "to_nif_term/2 for Vix.Vips.MutableImage is not supported"
  end

  @impl Type
  def to_erl_term(_term) do
    raise "to_erl_term/1 for Vix.Vips.MutableImage is not supported"
  end

  # Create mutable image
  @doc false
  @spec new(Vix.Vips.Image.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new(%Image{} = image) do
    GenServer.start_link(__MODULE__, image)
    |> wrap_type()
  end

  @doc """
  Return the number of bands of a mutable image.
  """
  def bands(%MutableImage{pid: pid}) do
    GenServer.call(pid, :bands)
  end

  @doc """
  Return the width of a mutable image.
  """
  def width(%MutableImage{pid: pid}) do
    GenServer.call(pid, :width)
  end

  @doc """
  Return the height of a mutable image.
  """
  def height(%MutableImage{pid: pid}) do
    GenServer.call(pid, :height)
  end

  @doc """
  Return a boolean indicating if a mutable image
  has an alpha band.
  """
  def has_alpha?(%MutableImage{pid: pid}) do
    GenServer.call(pid, :has_alpha?)
  end

  @doc """
  Return the shape of the image as
  `{width, height, bands}`.
  """
  def shape(%MutableImage{pid: pid}) do
    GenServer.call(pid, :shape)
  end

  @doc """
  Set the value of existing metadata item on an image. Value is converted to match existing value GType
  """
  @spec update(__MODULE__.t(), String.t(), term()) :: :ok | {:error, term()}
  def update(%MutableImage{pid: pid}, name, value) do
    GenServer.call(pid, {:update, name, value})
  end

  @supported_gtype ~w(gint guint gdouble gboolean gchararray VipsArrayInt VipsArrayDouble VipsArrayImage VipsRefString VipsBlob VipsImage VipsInterpolate)a

  @doc """
  Create a metadata item on an image of the specified type.
  Vix converts value to specified GType

  Supported GTypes
  #{Enum.map(@supported_gtype, fn type -> "  * `#{inspect(type)}`\n" end)}
  """
  @spec set(__MODULE__.t(), String.t(), atom(), term()) :: :ok | {:error, term()}
  def set(%MutableImage{pid: pid}, name, type, value) do
    if type in @supported_gtype do
      type = to_string(type)
      GenServer.call(pid, {:set, name, type, cast_value(type, value)})
    else
      {:error, "invalid gtype. Supported types are #{inspect(@supported_gtype)}"}
    end
  end

  @doc """
  Remove a metadata item from an image.
  """
  @spec remove(__MODULE__.t(), String.t()) :: :ok | {:error, term()}
  def remove(%MutableImage{pid: pid}, name) do
    GenServer.call(pid, {:remove, name})
  end

  @doc """
  Returns metadata from the image
  """
  @spec get(__MODULE__.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def get(%MutableImage{pid: pid}, name) do
    GenServer.call(pid, {:get, name})
  end

  @doc false
  def to_image(%MutableImage{pid: pid}) do
    GenServer.call(pid, :to_image)
  end

  @doc false
  def stop(%MutableImage{pid: pid}) do
    GenServer.stop(pid, :normal)
  end

  use GenServer

  @impl true
  def init(image) do
    case Image.copy_memory(image) do
      {:ok, copy} -> {:ok, %{image: copy}}
      {:error, error} -> {:stop, error}
    end
  end

  @impl true
  def handle_call({:update, name, value}, _from, %{image: image} = state) do
    {:reply, Nif.nif_image_update_metadata(image.ref, name, value), state}
  end

  @impl true
  def handle_call({:set, name, type, value}, _from, %{image: image} = state) do
    {:reply, Nif.nif_image_set_metadata(image.ref, name, type, value), state}
  end

  @impl true
  def handle_call({:remove, name}, _from, %{image: image} = state) do
    {:reply, Nif.nif_image_remove_metadata(image.ref, name), state}
  end

  @impl true
  def handle_call({:get, name}, _from, %{image: image} = state) do
    {:reply, Image.header_value(image, name), state}
  end

  @impl true
  def handle_call(:to_image, _from, %{image: image} = state) do
    {:reply, Image.copy_memory(image), state}
  end

  @impl true
  def handle_call({:operation, callback}, _from, %{image: image} = state) do
    {:reply, callback.(image), state}
  end

  @impl true
  def handle_call(:width, _from, %{image: image} = state) do
    {:reply, {:ok, Image.width(image)}, state}
  end

  @impl true
  def handle_call(:height, _from, %{image: image} = state) do
    {:reply, {:ok, Image.height(image)}, state}
  end

  @impl true
  def handle_call(:bands, _from, %{image: image} = state) do
    {:reply, {:ok, Image.bands(image)}, state}
  end

  @impl true
  def handle_call(:has_alpha?, _from, %{image: image} = state) do
    {:reply, {:ok, Image.has_alpha?(image)}, state}
  end

  @impl true
  def handle_call(:shape, _from, %{image: image} = state) do
    width = Image.width(image)
    height = Image.height(image)
    bands = Image.bands(image)

    {:reply, {:ok, {width, height, bands}}, state}
  end

  defp wrap_type({:ok, pid}), do: {:ok, %MutableImage{pid: pid}}
  defp wrap_type(value), do: value

  defp cast_value(type, value) do
    Vix.Type.to_nif_term(type, value, nil)
  end
end
