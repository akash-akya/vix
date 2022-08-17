defmodule Vix.Vips.MutableImage do
  defstruct [:pid]

  alias __MODULE__
  alias Vix.Vips.{Image, Operation}

  @moduledoc """
  Vips Mutable Image

  See `Vix.Vips.Image.mutate/2`
  """

  alias Vix.Nif

  @typedoc """
  Represents a mutable instance of VipsImage
  """
  @type t() :: %MutableImage{pid: pid()}

  # Create mutable image
  @doc false
  @spec new(Vix.Vips.Image.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new(%Image{} = image) do
    GenServer.start_link(__MODULE__, image)
    |> wrap_type()
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
  Create a metadata item on an image of the specifed type.
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

  @doc """
  Draws a circle on a mutable image
  """
  @spec draw_circle(__MODULE__.t(), [float()], non_neg_integer(), non_neg_integer(), non_neg_integer(), Keyword.t()) ::
    :ok | {:error, term()}
  def draw_circle(%MutableImage{pid: pid}, color, cx, cy, radius, options \\ []) do
    GenServer.call(pid, {:draw_circle, color, cx, cy, radius, options})
  end

  @doc """
  Draws a line on a mutable image
  """
  @spec draw_line(__MODULE__.t(), [float()], non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Keyword.t()) ::
    :ok | {:error, term()}
  def draw_line(%MutableImage{pid: pid}, color, x1, y1, x2, y2, options \\ []) do
    GenServer.call(pid, {:draw_line, color, x1, y1, x2, y2, options})
  end

  @doc """
  Draws a sub-image on a mutable image
  """
  @spec draw_image(__MODULE__.t(), Vix.Vips.Image.t(), non_neg_integer(), non_neg_integer(), Keyword.t()) ::
    :ok | {:error, term()}
  def draw_image(%MutableImage{pid: pid}, sub_image, cx, cy, options \\ []) do
    options = Keyword.put(options, :mode, :VIPS_COMBINE_MODE_ADD)
    GenServer.call(pid, {:draw_image, sub_image, cx, cy, options})
  end

  @doc """
  Flood an area of an image with the given `color` up
  at the given location up to an edge delineated by
  `color`.

  """
  @spec draw_flood(__MODULE__.t(), [float()], non_neg_integer(), non_neg_integer(), Keyword.t()) ::
  {:ok, {[height: integer(), width: integer(), top: integer(), left: integer()]}} | {:error, term()}
  def draw_flood(%MutableImage{pid: pid}, color, x, y, options \\ []) do
    GenServer.call(pid, {:draw_flood, color, x, y, options})
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
  def handle_call({:draw_circle, color, cx, cy, radius, options}, _from, %{image: image} = state) do
    {:reply, Operation.draw_circle(image, color, cx, cy, radius, options), state}
  end

  @impl true
  def handle_call({:draw_line, color, x1, y1, x2, y2, options}, _from, %{image: image} = state) do
    {:reply, Operation.draw_line(image, color, x1, y1, x2, y2, options), state}
  end

  @impl true
  def handle_call({:draw_image, sub_image, cx, cy, options}, _from, %{image: image} = state) do
    {:reply, Operation.draw_image(image, sub_image, cx, cy, options), state}
  end

  @impl true
  def handle_call({:draw_flood, color, x, y, options}, _from, %{image: image} = state) do
    {:reply, Operation.draw_flood(image, color, x, y, options), state}
  end

  defp wrap_type({:ok, pid}), do: {:ok, %MutableImage{pid: pid}}
  defp wrap_type(value), do: value

  defp cast_value(type, value) do
    Vix.Type.to_nif_term(type, value, nil)
  end
end
