defmodule PacketFlow.ActorSupervisor do
  @moduledoc """
  Dynamic supervisor for managing PacketFlow actor processes.

  Each actor is a persistent GenServer that maintains state between
  capability executions, enabling stateful conversations and long-running
  capability sessions.
  """

  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("PacketFlow.ActorSupervisor started")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a new actor process for the given capability and actor ID.
  """
  def start_actor(capability_id, actor_id, options \\ %{}) do
    actor_config = %{
      capability_id: capability_id,
      actor_id: actor_id,
      options: options
    }

    child_spec = %{
      id: {PacketFlow.ActorProcess, actor_id},
      start: {PacketFlow.ActorProcess, :start_link, [actor_config]},
      restart: :transient,
      shutdown: 5000,
      type: :worker
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.debug("Started actor #{actor_id} for capability #{capability_id}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.debug("Actor #{actor_id} already exists")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start actor #{actor_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Terminate an actor process.
  """
  def terminate_actor(actor_pid, _reason \\ :normal) do
    case DynamicSupervisor.terminate_child(__MODULE__, actor_pid) do
      :ok ->
        Logger.debug("Terminated actor #{inspect(actor_pid)}")
        :ok

      {:error, :not_found} ->
        Logger.debug("Actor #{inspect(actor_pid)} not found for termination")
        :ok

      {:error, reason} ->
        Logger.error("Failed to terminate actor #{inspect(actor_pid)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get all running actor processes.
  """
  def list_actors do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&Process.alive?/1)
  end

  @doc """
  Get count of running actors.
  """
  def actor_count do
    DynamicSupervisor.count_children(__MODULE__).active
  end

  @doc """
  Get information about all active actors for MCP resource access.
  """
  def list_active_actors do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} ->
      if Process.alive?(pid) do
        try do
          # Get actor information from the process
          case GenServer.call(pid, :get_info, 1000) do
            info when is_map(info) ->
              Map.merge(info, %{
                "pid" => inspect(pid),
                "status" => "active"
              })

            _ ->
              %{
                "pid" => inspect(pid),
                "status" => "active",
                "actor_id" => "unknown",
                "capability_id" => "unknown"
              }
          end
        catch
          :exit, _ ->
            %{
              "pid" => inspect(pid),
              "status" => "unresponsive"
            }
        end
      else
        nil
      end
    end)
    |> Enum.filter(& &1)  # Remove nil values
  end
end
