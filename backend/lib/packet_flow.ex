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
end
