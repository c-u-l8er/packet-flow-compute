defmodule PacketFlow.Registry do
  @moduledoc """
  PacketFlow Registry: Manages registration and discovery of PacketFlow components.
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{
      reactors: %{},
      capabilities: %{},
      contexts: %{},
      intents: %{}
    }}
  end

  def register_reactor(id, reactor_info) do
    GenServer.call(__MODULE__, {:register_reactor, id, reactor_info})
  end

  def register_capability(id, capability_info) do
    GenServer.call(__MODULE__, {:register_capability, id, capability_info})
  end

  def register_context(id, context_info) do
    GenServer.call(__MODULE__, {:register_context, id, context_info})
  end

  def register_intent(id, intent_info) do
    GenServer.call(__MODULE__, {:register_intent, id, intent_info})
  end

  def lookup_reactor(id) do
    GenServer.call(__MODULE__, {:lookup_reactor, id})
  end

  def lookup_capability(id) do
    GenServer.call(__MODULE__, {:lookup_capability, id})
  end

  def lookup_context(id) do
    GenServer.call(__MODULE__, {:lookup_context, id})
  end

  def lookup_intent(id) do
    GenServer.call(__MODULE__, {:lookup_intent, id})
  end

  def list_reactors do
    GenServer.call(__MODULE__, :list_reactors)
  end

  def list_capabilities do
    GenServer.call(__MODULE__, :list_capabilities)
  end

  def list_contexts do
    GenServer.call(__MODULE__, :list_contexts)
  end

  def list_intents do
    GenServer.call(__MODULE__, :list_intents)
  end

  # GenServer callbacks

  def handle_call({:register_reactor, id, reactor_info}, _from, state) do
    new_state = Map.put(state, :reactors, Map.put(state.reactors, id, reactor_info))
    {:reply, :ok, new_state}
  end

  def handle_call({:register_capability, id, capability_info}, _from, state) do
    new_state = Map.put(state, :capabilities, Map.put(state.capabilities, id, capability_info))
    {:reply, :ok, new_state}
  end

  def handle_call({:register_context, id, context_info}, _from, state) do
    new_state = Map.put(state, :contexts, Map.put(state.contexts, id, context_info))
    {:reply, :ok, new_state}
  end

  def handle_call({:register_intent, id, intent_info}, _from, state) do
    new_state = Map.put(state, :intents, Map.put(state.intents, id, intent_info))
    {:reply, :ok, new_state}
  end

  def handle_call({:lookup_reactor, id}, _from, state) do
    {:reply, Map.get(state.reactors, id), state}
  end

  def handle_call({:lookup_capability, id}, _from, state) do
    {:reply, Map.get(state.capabilities, id), state}
  end

  def handle_call({:lookup_context, id}, _from, state) do
    {:reply, Map.get(state.contexts, id), state}
  end

  def handle_call({:lookup_intent, id}, _from, state) do
    {:reply, Map.get(state.intents, id), state}
  end

  def handle_call(:list_reactors, _from, state) do
    {:reply, Map.keys(state.reactors), state}
  end

  def handle_call(:list_capabilities, _from, state) do
    {:reply, Map.keys(state.capabilities), state}
  end

  def handle_call(:list_contexts, _from, state) do
    {:reply, Map.keys(state.contexts), state}
  end

  def handle_call(:list_intents, _from, state) do
    {:reply, Map.keys(state.intents), state}
  end
end
