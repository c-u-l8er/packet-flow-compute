defmodule PacketFlow.ActorProcess do
  @moduledoc """
  Individual actor process that maintains state for a specific capability instance.

  Each actor is a GenServer that:
  - Maintains persistent state between messages
  - Handles capability-specific message patterns
  - Manages its own lifecycle and timeout
  - Provides state persistence hooks
  """

  use GenServer
  require Logger

  @default_timeout :timer.minutes(30)

  defstruct [
    :actor_id,
    :capability_id,
    :capability_module,
    :state,
    :metadata,
    :timeout_ref,
    :options
  ]

  # Public API

  def start_link(config) do
    actor_id = config.actor_id
    GenServer.start_link(__MODULE__, config, name: via_tuple(actor_id))
  end

  @doc """
  Send a message to the actor and get a response.
  """
  def send_message(actor_pid, message, context \\ %{}) do
    GenServer.call(actor_pid, {:handle_message, message, context}, 30_000)
  end

  @doc """
  Get the current state of the actor.
  """
  def get_state(actor_pid) do
    GenServer.call(actor_pid, :get_state)
  end

  @doc """
  Update the actor's state.
  """
  def update_state(actor_pid, state_update_fn) when is_function(state_update_fn, 1) do
    GenServer.call(actor_pid, {:update_state, state_update_fn})
  end

  @doc """
  Gracefully stop the actor.
  """
  def stop(actor_pid, reason \\ :normal) do
    GenServer.stop(actor_pid, reason)
  end

  # Registry helpers

  defp via_tuple(actor_id) do
    {:via, Registry, {PacketFlow.ActorRegistry, actor_id}}
  end

  def whereis(actor_id) do
    case Registry.lookup(PacketFlow.ActorRegistry, actor_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  # GenServer implementation

  @impl true
  def init(config) do
    # Set up initial state
    actor_state = %__MODULE__{
      actor_id: config.actor_id,
      capability_id: config.capability_id,
      capability_module: get_capability_module(config.capability_id),
      state: get_initial_state(config),
      metadata: %{
        created_at: DateTime.utc_now(),
        last_message_at: DateTime.utc_now(),
        message_count: 0,
        persistence_strategy: Map.get(config.options, :persistence, :memory)
      },
      options: config.options
    }

    # Set up timeout
    timeout = Map.get(config.options, :actor_timeout, @default_timeout)
    timeout_ref = Process.send_after(self(), :timeout, timeout)

    actor_state = %{actor_state | timeout_ref: timeout_ref}

    Logger.info("Actor #{config.actor_id} initialized for capability #{config.capability_id}")

    {:ok, actor_state}
  end

  @impl true
  def handle_call({:handle_message, message, context}, _from, state) do
    # Cancel existing timeout and set new one
    if state.timeout_ref, do: Process.cancel_timer(state.timeout_ref)
    timeout = Map.get(state.options, :actor_timeout, @default_timeout)
    timeout_ref = Process.send_after(self(), :timeout, timeout)

    # Update metadata
    updated_metadata = %{
      state.metadata |
      last_message_at: DateTime.utc_now(),
      message_count: state.metadata.message_count + 1
    }

    updated_state = %{state |
      metadata: updated_metadata,
      timeout_ref: timeout_ref
    }

    try do
      # Handle the message based on capability type
      case handle_capability_message(message, context, updated_state) do
        {:ok, result, new_actor_state} ->
          {:reply, {:ok, result}, new_actor_state}

        {:error, reason} ->
          Logger.error("Actor #{state.actor_id} message handling failed: #{inspect(reason)}")
          {:reply, {:error, reason}, updated_state}
      end
    rescue
      error ->
        Logger.error("Actor #{state.actor_id} crashed: #{inspect(error)}")
        {:reply, {:error, :actor_crash}, updated_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    public_state = %{
      actor_id: state.actor_id,
      capability_id: state.capability_id,
      state: state.state,
      metadata: state.metadata
    }
    {:reply, public_state, state}
  end

  @impl true
  def handle_call({:update_state, update_fn}, _from, state) do
    try do
      new_state = update_fn.(state.state)
      updated_actor_state = %{state | state: new_state}
      {:reply, :ok, updated_actor_state}
    rescue
      error ->
        Logger.error("Actor #{state.actor_id} state update failed: #{inspect(error)}")
        {:reply, {:error, :state_update_failed}, state}
    end
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      "actor_id" => state.actor_id,
      "capability_id" => state.capability_id,
      "created_at" => DateTime.to_iso8601(state.metadata.created_at),
      "last_message_at" => if state.metadata.last_message_at do
        DateTime.to_iso8601(state.metadata.last_message_at)
      else
        nil
      end,
      "message_count" => state.metadata.message_count,
      "persistence_strategy" => state.metadata.persistence_strategy
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Actor #{state.actor_id} timed out, shutting down")
    {:stop, :timeout, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Actor #{state.actor_id} terminating: #{inspect(reason)}")

    # TODO: Implement state persistence based on strategy
    case state.metadata.persistence_strategy do
      :disk -> persist_state_to_disk(state)
      :distributed -> persist_state_distributed(state)
      :memory -> :ok  # No persistence needed
    end

    :ok
  end

  # Private helpers

  defp get_capability_module(capability_id) do
    # Read directly from ETS to avoid GenServer call during initialization
    case :ets.lookup(:packet_flow_capabilities, capability_id) do
      [{^capability_id, capability}] -> capability.module
      [] -> nil
    end
  end

  defp get_initial_state(config) do
    # Get initial state from capability module if it supports actors
    capability_module = get_capability_module(config.capability_id)

    if capability_module && function_exported?(capability_module, :initial_actor_state, 1) do
      capability_module.initial_actor_state(config.options)
    else
      %{}  # Default empty state
    end
  end

  defp handle_capability_message(message, context, actor_state) do
    capability_module = actor_state.capability_module

    cond do
      # Check if capability module supports actor message handling
      capability_module && function_exported?(capability_module, :handle_actor_message, 3) ->
        case capability_module.handle_actor_message(message, context, actor_state.state) do
          {:ok, result, new_state} ->
            updated_actor_state = %{actor_state | state: new_state}
            {:ok, result, updated_actor_state}

          {:error, reason} ->
            {:error, reason}
        end

      # Fallback to regular capability execution
      capability_module && function_exported?(capability_module, :execute, 2) ->
        case capability_module.execute(message, context) do
          {:ok, result} ->
            {:ok, result, actor_state}

          {:error, reason} ->
            {:error, reason}
        end

      true ->
        {:error, :capability_not_found}
    end
  end

  # TODO: Implement persistence strategies
  defp persist_state_to_disk(_state), do: :ok
  defp persist_state_distributed(_state), do: :ok
end
