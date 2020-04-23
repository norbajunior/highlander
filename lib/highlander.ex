defmodule Highlander do
  @moduledoc """
  Highlander allows you to run a single process just _once_ in a cluster.

  Include in your supervision tree as follow:

  ```
  children = [
    {Highlander, child_spec}
  ]
  ```

  `child_spec.id` is the "key" used to determine global uniqueness.

  In other words, the following will generate one global process:

  ```
  children = [
    {Highlander, %{id: :one}},
    {Highlander, %{id: :one}}
  ]
  ```

  The following will generate two global processes:

  ```
  children = [
    {Highlander, %{id: :one}},
    {Highlander, %{id: :two}}
  ]
  ```
  """

  use GenServer

  def child_spec(child_child_spec) do
    child_child_spec = Supervisor.child_spec(child_child_spec, [])

    %{
      id: child_child_spec.id,
      start: {GenServer, :start_link, [__MODULE__, child_child_spec, []]}
    }
  end

  @impl true
  def init(child_spec) do
    Process.flag(:trap_exit, true)
    {:ok, register(%{child_spec: child_spec})}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, %{ref: ref} = state) do
    {:noreply, register(state)}
  end

  defp name(state) do
    %{child_spec: %{id: global_name}} = state
    {__MODULE__, global_name}
  end

  defp register(state) do
    case :global.register_name(name(state), self()) do
      :yes -> start(state)
      :no -> monitor(state)
    end
  end

  defp start(state) do
    {:ok, pid} = Supervisor.start_link([state.child_spec], strategy: :one_for_one)
    %{child_spec: state.child_spec, pid: pid}
  end

  defp monitor(state) do
    case :global.whereis_name(name(state)) do
      :undefined ->
        register(state)

      pid ->
        ref = Process.monitor(pid)
        %{child_spec: state.child_spec, ref: ref}
    end
  end

  @impl true
  def terminate(reason, %{pid: pid}) do
    Supervisor.stop(pid, reason)
  end

  def terminate(_, _), do: nil
end