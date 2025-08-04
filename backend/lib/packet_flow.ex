defmodule PacketFlow do
  @moduledoc """
  PacketFlow: Declarative Capability-Based Distributed Systems Framework

  PacketFlow enables building distributed systems as networks of discoverable,
  composable capabilities with built-in observability and AI integration.
  """

  @doc """
  Start the PacketFlow application with the given configuration.
  """
  def start_link(opts \\ []) do
    children = [
      # Actor infrastructure
      {Registry, keys: :unique, name: PacketFlow.ActorRegistry},
      {PacketFlow.ActorSupervisor, opts},

      # Core PacketFlow components
      {PacketFlow.CapabilityRegistry, opts},
      {PacketFlow.ExecutionEngine, opts},
      {PacketFlow.AIPlanner, opts}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PacketFlow.Supervisor)
  end

  @doc """
  Execute a capability by name with the given payload and context.
  """
  def execute_capability(capability_id, payload, context \\ %{}) do
    PacketFlow.ExecutionEngine.execute(capability_id, payload, context)
  end

  @doc """
  Discover capabilities based on intent or requirements.
  """
  def discover_capabilities(query) do
    PacketFlow.CapabilityRegistry.discover(query)
  end

  @doc """
  Generate an execution plan from natural language intent.
  """
  def plan_from_intent(intent, context \\ %{}) do
    PacketFlow.AIPlanner.generate_plan(intent, context)
  end

  # Actor Management API

  @doc """
  Send a message to an actor, creating it if necessary.
  """
  def send_to_actor(capability_id, actor_id, message, context \\ %{}, options \\ %{}) do
    case PacketFlow.CapabilityRegistry.get_or_create_actor(capability_id, actor_id, options) do
      {:ok, _pid} ->
        PacketFlow.CapabilityRegistry.send_to_actor(capability_id, actor_id, message, context)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get the current state of an actor.
  """
  def get_actor_state(capability_id, actor_id) do
    PacketFlow.CapabilityRegistry.get_actor_state(capability_id, actor_id)
  end

  @doc """
  Terminate an actor.
  """
  def terminate_actor(capability_id, actor_id, reason \\ :normal) do
    PacketFlow.CapabilityRegistry.terminate_actor(capability_id, actor_id, reason)
  end

  @doc """
  List all active actors.
  """
  def list_actors do
    PacketFlow.CapabilityRegistry.list_actors()
  end
end
