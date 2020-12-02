defmodule Vix.Vips.Source do
  @moduledoc """
  *NOT supported yet*
  """
  # Internal module to handle callback from NIF
  defmodule Callback do
    @moduledoc false
    use GenServer
    require Logger

    alias Vix.Nif

    defmodule State do
      defstruct [:read_fun, :after_fun, :source, :acc]
    end

    # TODO: unblock caller if its waiting for callback to write
    def start_link(state) do
      GenServer.start(__MODULE__, state)
    end

    @impl true
    def init(%{start_fun: start_fun, read_fun: read_fun, after_fun: after_fun}) do
      {:ok, source} = Nif.nif_vips_source_new(self())
      acc = start_fun.()

      state = %State{
        read_fun: read_fun,
        after_fun: after_fun,
        source: source,
        acc: acc
      }

      {:ok, state}
    end

    @impl true
    def handle_call(:source, _from, %State{source: source} = state) do
      {:reply, source, state}
    end

    @impl true
    def handle_info(cmd, %State{} = state) do
      handle_cmd(cmd, state)
    end

    # Note that this does *NOT always* gauratee cleanup, for gaurateed
    # cleanup we have to monitor or link
    @impl true
    def terminate(_reason, state) do
      state.after_fun.(state.acc)
    end

    defp handle_cmd(:close, state) do
      {:stop, :normal, state}
    end

    defp handle_cmd(
           {:read, length, cb_state},
           %State{read_fun: read_fun, acc: acc} = state
         ) do
      case read_fun.(acc, length) do
        {:halt, acc} ->
          :ok = Nif.nif_vips_conn_write_result(<<>>, cb_state)
          {:stop, :normal, %State{state | acc: acc}}

        {bin, acc} when is_binary(bin) ->
          # if returned data is < request then we assume its eof
          if IO.iodata_length(bin) < length do
            :ok = Nif.nif_vips_conn_write_result(bin, cb_state)
            {:stop, :normal, %State{state | acc: acc}}
          else
            :ok = Nif.nif_vips_conn_write_result(bin, cb_state)
            {:noreply, %State{state | acc: acc}}
          end

        {_term, acc} ->
          {:stop, :invalid_return_value, %State{state | acc: acc}}
      end
    end
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

    source = GenServer.call(pid, :source)
    {:ok, source}
  end
end
