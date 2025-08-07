defmodule PacketFlow.CapabilityRegistry do
  @moduledoc """
  Registry for discovering and managing capabilities across the PacketFlow network.

  The registry maintains metadata about all available capabilities and provides
  discovery functionality for AI agents and other systems.
  """

  use GenServer
  require Logger

  @table_name :packet_flow_capabilities

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a capability module with the registry.
  """
  def register_module(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:register_module, module})
  end

  @doc """
  Discover capabilities based on intent, requirements, or provides.
  """
  def discover(query) when is_binary(query) do
    GenServer.call(__MODULE__, {:discover_by_intent, query})
  end

  def discover(query) when is_map(query) do
    GenServer.call(__MODULE__, {:discover_by_criteria, query})
  end

  @doc """
  Get all registered capabilities.
  """
  def list_all do
    GenServer.call(__MODULE__, :list_all)
  end

  @doc """
  Get capability metadata by ID.
  """
  def get_capability(capability_id) do
    GenServer.call(__MODULE__, {:get_capability, capability_id})
  end

  # Actor Management API

  @doc """
  Get or create an actor for the given capability and actor ID.
  """
  def get_or_create_actor(capability_id, actor_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:get_or_create_actor, capability_id, actor_id, options})
  end

  @doc """
  Send a message to an actor.
  """
  def send_to_actor(capability_id, actor_id, message, context \\ %{}) do
    GenServer.call(__MODULE__, {:send_to_actor, capability_id, actor_id, message, context}, 30_000)
  end

  @doc """
  Get the current state of an actor.
  """
  def get_actor_state(capability_id, actor_id) do
    GenServer.call(__MODULE__, {:get_actor_state, capability_id, actor_id})
  end

  @doc """
  Terminate an actor.
  """
  def terminate_actor(capability_id, actor_id, reason \\ :normal) do
    GenServer.call(__MODULE__, {:terminate_actor, capability_id, actor_id, reason})
  end

  @doc """
  List all active actors.
  """
  def list_actors do
    GenServer.call(__MODULE__, :list_actors)
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:named_table, :public, :set])

    # Auto-discover capabilities in the application
    discover_application_capabilities()

    Logger.info("PacketFlow.CapabilityRegistry started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register_module, module}, _from, state) do
    case register_module_capabilities(module) do
      {:ok, count} ->
        Logger.info("Registered #{count} capabilities from module #{module}")
        {:reply, {:ok, count}, state}

      {:error, reason} ->
        Logger.error("Failed to register capabilities from #{module}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:discover_by_intent, query}, _from, state) do
    capabilities = :ets.tab2list(@table_name)

    matches = capabilities
    |> Enum.filter(fn {_id, capability} ->
      intent_matches?(capability.intent, query)
    end)
    |> Enum.map(fn {_id, capability} -> capability end)

    {:reply, matches, state}
  end

  @impl true
  def handle_call({:discover_by_criteria, criteria}, _from, state) do
    capabilities = :ets.tab2list(@table_name)

    matches = capabilities
    |> Enum.filter(fn {_id, capability} ->
      criteria_matches?(capability, criteria)
    end)
    |> Enum.map(fn {_id, capability} -> capability end)

    {:reply, matches, state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    capabilities = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, capability} -> capability end)

    {:reply, capabilities, state}
  end

  @impl true
  def handle_call({:get_capability, capability_id}, _from, state) do
    case :ets.lookup(@table_name, capability_id) do
      [{^capability_id, capability}] -> {:reply, {:ok, capability}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  # Actor Management Handlers

  def handle_call({:get_or_create_actor, capability_id, actor_id, options}, _from, state) do
    # First verify the capability exists (read directly from ETS to avoid deadlock)
    case :ets.lookup(@table_name, capability_id) do
      [{^capability_id, _capability}] ->
        # Check if actor already exists
        case PacketFlow.ActorProcess.whereis(actor_id) do
          nil ->
            # Create new actor
            case PacketFlow.ActorSupervisor.start_actor(capability_id, actor_id, options) do
              {:ok, pid} -> {:reply, {:ok, pid}, state}
              {:error, reason} -> {:reply, {:error, reason}, state}
            end

          pid when is_pid(pid) ->
            # Actor already exists
            {:reply, {:ok, pid}, state}
        end

      [] ->
        {:reply, {:error, :capability_not_found}, state}
    end
  end

  def handle_call({:send_to_actor, _capability_id, actor_id, message, context}, _from, state) do
    case PacketFlow.ActorProcess.whereis(actor_id) do
      nil ->
        {:reply, {:error, :actor_not_found}, state}

      pid when is_pid(pid) ->
        case PacketFlow.ActorProcess.send_message(pid, message, context) do
          {:ok, result} -> {:reply, {:ok, result}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:get_actor_state, _capability_id, actor_id}, _from, state) do
    case PacketFlow.ActorProcess.whereis(actor_id) do
      nil ->
        {:reply, {:error, :actor_not_found}, state}

      pid when is_pid(pid) ->
        case PacketFlow.ActorProcess.get_state(pid) do
          state_data -> {:reply, {:ok, state_data}, state}
        end
    end
  end

  def handle_call({:terminate_actor, _capability_id, actor_id, reason}, _from, state) do
    case PacketFlow.ActorProcess.whereis(actor_id) do
      nil ->
        {:reply, {:error, :actor_not_found}, state}

      pid when is_pid(pid) ->
        case PacketFlow.ActorSupervisor.terminate_actor(pid, reason) do
          :ok -> {:reply, :ok, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:list_actors, _from, state) do
    actors = PacketFlow.ActorSupervisor.list_actors()
    {:reply, {:ok, actors}, state}
  end

  # Private functions

  defp discover_application_capabilities do
    # Get all modules in the current application
    {:ok, modules} = :application.get_key(:packetflow_chat, :modules)

    modules
    |> Enum.each(fn module ->
      if capability_module?(module) do
        register_module_capabilities(module)
      end
    end)
  end

  defp capability_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__capabilities__, 0)
  end

  defp register_module_capabilities(module) do
    try do
      capabilities = module.__capabilities__()

      count = capabilities
      |> Enum.map(fn capability ->
        full_capability = Map.merge(capability, %{
          module: module,
          registered_at: DateTime.utc_now()
        })

        :ets.insert(@table_name, {capability.id, full_capability})
      end)
      |> length()

      {:ok, count}
    rescue
      error ->
        {:error, error}
    end
  end

  defp intent_matches?(intent, query) when is_binary(intent) and is_binary(query) do
    intent_lower = String.downcase(intent)
    query_lower = String.downcase(query)

    # Simple keyword matching - can be enhanced with semantic search
    query_words = String.split(query_lower, ~r/\s+/)

    Enum.any?(query_words, fn word ->
      String.contains?(intent_lower, word)
    end)
  end

  defp intent_matches?(_, _), do: false

  defp criteria_matches?(capability, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :requires ->
          # Check if capability provides all required fields
          required_fields = List.wrap(value)
          Enum.all?(required_fields, &(&1 in capability.provides))

        :provides ->
          # Check if capability requires all provided fields
          provided_fields = List.wrap(value)
          Enum.all?(provided_fields, &(&1 in capability.requires))

        :intent ->
          intent_matches?(capability.intent, value)

        _ ->
          Map.get(capability, key) == value
      end
    end)
  end

  @doc """
  Check if a capability exists.
  """
  def capability_exists?(capability_id) do
    case get_capability(capability_id) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Execute a capability by ID with given payload and context.
  """
  def execute(capability_id, payload, context \\ %{}) do
    case get_capability(capability_id) do
      {:ok, capability} ->
        try do
          case capability.module.execute(payload, context) do
            {:ok, result} -> {:ok, result}
            {:error, reason} -> {:error, reason}
            result -> {:ok, result}  # Handle direct return values
          end
        rescue
          error ->
            {:error, "Execution failed: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
