defmodule Vix.Vips.Source do
  @moduledoc """
  *NOT supported yet*
  """
  # Internal module to handle callback from NIF
  defmodule Callback do
    @moduledoc false
    use GenServer

    alias Vix.Nif

    # TODO: unblock
    def start_link(state) do
      GenServer.start(__MODULE__, state)
    end

    @impl true
    def init(state) do
      Process.flag(:trap_exit, true)
      {:ok, state, {:continue, nil}}
    end

    @impl true
    def handle_continue(nil, %{start_fun: start_fun} = state) do
      acc = start_fun.()
      {:noreply, Map.put(state, :acc, acc)}
    end

    @impl true
    def handle_info({:read, length, cb_term}, %{read_fun: read_fun, acc: acc} = state) do
      case read_fun.(acc, length) do
        {:halt, acc} ->
          :ok = Nif.nif_vips_conn_write_result(<<>>, cb_term)
          {:stop, :normal, %{state | acc: acc}}

        {bin, acc} when is_binary(bin) ->
          # if returned data is < request then we assume its eof
          if IO.iodata_length(bin) < length do
            :ok = Nif.nif_vips_conn_write_result(bin, cb_term)
            {:stop, :normal, %{state | acc: acc}}
          else
            :ok = Nif.nif_vips_conn_write_result(bin, cb_term)
            {:noreply, %{state | acc: acc}}
          end

        {_term, acc} ->
          {:stop, :invalid_return_value, %{state | acc: acc}}
      end
    end

    # Note that this does *NOT always* gauratee cleanup, for true cleanup we have to monitor or link
    @impl true
    def terminate(_reason, %{after_fun: after_fun, acc: acc} = state) do
      _acc = after_fun.(acc)
      state
    end

    @impl true
    def terminate(_reason, state), do: state
  end

  alias Vix.Type
  alias Vix.Nif

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def to_nif_term(_value, _data), do: raise("VipsSource is not implemented yet")

  @impl Type
  def to_erl_term(_value), do: raise("VipsSource is not implemented yet")

  def new_from_stream(start_fun, read_fun, after_fun) do
    {:ok, pid} =
      Callback.start_link(%{start_fun: start_fun, read_fun: read_fun, after_fun: after_fun})

    case Nif.nif_vips_source_new(pid) do
      {:ok, source} ->
        {:ok, source}

      error ->
        :ok = GenServer.stop(pid, :normal)
        error
    end
  end
end
