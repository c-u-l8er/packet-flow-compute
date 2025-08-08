defmodule PacketFlow.Component.Communication do
  @moduledoc """
  Component communication protocols for inter-component messaging

  This module provides:
  - Message routing between components
  - Protocol definitions for different message types
  - Message validation and transformation
  - Asynchronous and synchronous communication patterns
  - Message queuing and buffering
  """

  use GenServer

  @type message_type :: :request | :response | :notification | :broadcast | :event
  @type message_priority :: :low | :normal | :high | :urgent
  @type message_id :: String.t()

  @type component_message :: %{
    id: message_id(),
    type: message_type(),
    from: atom(),
    to: atom() | [atom()],
    payload: term(),
    priority: message_priority(),
    timestamp: integer(),
    timeout: integer() | nil,
    reply_to: pid() | nil,
    metadata: map()
  }

  @type communication_protocol :: %{
    name: atom(),
    version: String.t(),
    message_types: [message_type()],
    validation_rules: map(),
    transformation_rules: map()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{
      message_queue: :queue.new(),
      pending_requests: %{},
      protocols: %{},
      subscriptions: %{},
      message_handlers: %{},
      statistics: %{
        messages_sent: 0,
        messages_received: 0,
        messages_failed: 0,
        average_latency: 0.0
      }
    }}
  end

  @doc """
  Register a communication protocol
  """
  @spec register_protocol(communication_protocol()) :: :ok | {:error, term()}
  def register_protocol(protocol) do
    GenServer.call(__MODULE__, {:register_protocol, protocol})
  end

  @doc """
  Send a message to a component
  """
  @spec send_message(atom(), term(), keyword()) :: :ok | {:error, term()}
  def send_message(to, payload, opts \\ []) do
    message = build_message(to, payload, opts)
    GenServer.call(__MODULE__, {:send_message, message})
  end

  @doc """
  Send a synchronous request to a component
  """
  @spec send_request(atom(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def send_request(to, payload, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    message = build_message(to, payload, Keyword.put(opts, :type, :request))
    GenServer.call(__MODULE__, {:send_request, message}, timeout + 1000)
  end

  @doc """
  Broadcast a message to multiple components
  """
  @spec broadcast_message([atom()], term(), keyword()) :: :ok | {:error, term()}
  def broadcast_message(targets, payload, opts \\ []) do
    message = build_message(targets, payload, Keyword.put(opts, :type, :broadcast))
    GenServer.call(__MODULE__, {:broadcast_message, message})
  end

  @doc """
  Subscribe to messages from a component
  """
  @spec subscribe(atom(), atom()) :: :ok | {:error, term()}
  def subscribe(from_component, to_component) do
    GenServer.call(__MODULE__, {:subscribe, from_component, to_component})
  end

  @doc """
  Unsubscribe from messages from a component
  """
  @spec unsubscribe(atom(), atom()) :: :ok | {:error, term()}
  def unsubscribe(from_component, to_component) do
    GenServer.call(__MODULE__, {:unsubscribe, from_component, to_component})
  end

  @doc """
  Register a message handler for a component
  """
  @spec register_message_handler(atom(), module()) :: :ok | {:error, term()}
  def register_message_handler(component, handler_module) do
    GenServer.call(__MODULE__, {:register_message_handler, component, handler_module})
  end

  @doc """
  Get communication statistics
  """
  @spec get_statistics() :: map()
  def get_statistics() do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Get pending requests for debugging
  """
  @spec get_pending_requests() :: map()
  def get_pending_requests() do
    GenServer.call(__MODULE__, :get_pending_requests)
  end

  # GenServer callbacks

  def handle_call({:register_protocol, protocol}, _from, state) do
    case validate_protocol(protocol) do
      :ok ->
        new_protocols = Map.put(state.protocols, protocol.name, protocol)
        new_state = %{state | protocols: new_protocols}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:send_message, message}, _from, state) do
    case validate_and_route_message(message, state) do
      {:ok, new_state} ->
        updated_stats = update_statistics(state.statistics, :sent)
        final_state = %{new_state | statistics: updated_stats}
        {:reply, :ok, final_state}

      {:error, reason} ->
        updated_stats = update_statistics(state.statistics, :failed)
        new_state = %{state | statistics: updated_stats}
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call({:send_request, message}, from, state) do
    request_id = message.id
    timeout = message.timeout || 5000

    # Store the request for response handling
    timer_ref = Process.send_after(self(), {:request_timeout, request_id}, timeout)
    pending_request = %{
      from: from,
      timer_ref: timer_ref,
      sent_at: System.system_time(:millisecond)
    }

    new_pending = Map.put(state.pending_requests, request_id, pending_request)
    temp_state = %{state | pending_requests: new_pending}

    case validate_and_route_message(message, temp_state) do
      {:ok, new_state} ->
        updated_stats = update_statistics(new_state.statistics, :sent)
        final_state = %{new_state | statistics: updated_stats}
        {:noreply, final_state}

      {:error, reason} ->
        # Clean up pending request
        Process.cancel_timer(timer_ref)
        cleaned_pending = Map.delete(temp_state.pending_requests, request_id)
        updated_stats = update_statistics(state.statistics, :failed)
        final_state = %{state | pending_requests: cleaned_pending, statistics: updated_stats}
        {:reply, {:error, reason}, final_state}
    end
  end

  def handle_call({:broadcast_message, message}, _from, state) do
    targets = if is_list(message.to), do: message.to, else: [message.to]

    results = Enum.map(targets, fn target ->
      individual_message = %{message | to: target}
      validate_and_route_message(individual_message, state)
    end)

    failed_count = Enum.count(results, fn result -> match?({:error, _}, result) end)

    if failed_count == 0 do
      updated_stats = update_statistics(state.statistics, :sent, length(targets))
      new_state = %{state | statistics: updated_stats}
      {:reply, :ok, new_state}
    else
      updated_stats = update_statistics(state.statistics, :failed, failed_count)
      new_state = %{state | statistics: updated_stats}
      {:reply, {:error, {:partial_failure, failed_count}}, new_state}
    end
  end

  def handle_call({:subscribe, from_component, to_component}, _from, state) do
    subscriptions = Map.update(state.subscriptions, from_component, [to_component], fn subs ->
      if to_component in subs, do: subs, else: [to_component | subs]
    end)

    new_state = %{state | subscriptions: subscriptions}
    {:reply, :ok, new_state}
  end

  def handle_call({:unsubscribe, from_component, to_component}, _from, state) do
    subscriptions = Map.update(state.subscriptions, from_component, [], fn subs ->
      List.delete(subs, to_component)
    end)

    new_state = %{state | subscriptions: subscriptions}
    {:reply, :ok, new_state}
  end

  def handle_call({:register_message_handler, component, handler_module}, _from, state) do
    case validate_message_handler(handler_module) do
      :ok ->
        new_handlers = Map.put(state.message_handlers, component, handler_module)
        new_state = %{state | message_handlers: new_handlers}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_statistics, _from, state) do
    {:reply, state.statistics, state}
  end

  def handle_call(:get_pending_requests, _from, state) do
    {:reply, state.pending_requests, state}
  end

  def handle_info({:request_timeout, request_id}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        {:noreply, state}

      pending_request ->
        GenServer.reply(pending_request.from, {:error, :timeout})
        new_pending = Map.delete(state.pending_requests, request_id)
        updated_stats = update_statistics(state.statistics, :failed)
        new_state = %{state | pending_requests: new_pending, statistics: updated_stats}
        {:noreply, new_state}
    end
  end

  def handle_info({:component_message, from_component, payload}, state) do
    # Handle incoming messages from components
    message = %{
      id: generate_message_id(),
      type: :notification,
      from: from_component,
      to: __MODULE__,
      payload: payload,
      priority: :normal,
      timestamp: System.system_time(:millisecond),
      timeout: nil,
      reply_to: nil,
      metadata: %{}
    }

    case handle_incoming_message(message, state) do
      {:ok, new_state} ->
        updated_stats = update_statistics(new_state.statistics, :received)
        final_state = %{new_state | statistics: updated_stats}
        {:noreply, final_state}

      {:error, _reason} ->
        updated_stats = update_statistics(state.statistics, :failed)
        new_state = %{state | statistics: updated_stats}
        {:noreply, new_state}
    end
  end

  def handle_info({:message_response, request_id, response}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        {:noreply, state}

      pending_request ->
        Process.cancel_timer(pending_request.timer_ref)
        GenServer.reply(pending_request.from, {:ok, response})

        # Update latency statistics
        latency = System.system_time(:millisecond) - pending_request.sent_at
        updated_stats = update_latency_statistics(state.statistics, latency)

        new_pending = Map.delete(state.pending_requests, request_id)
        new_state = %{state | pending_requests: new_pending, statistics: updated_stats}
        {:noreply, new_state}
    end
  end

  # Private functions

  defp build_message(to, payload, opts) do
    %{
      id: generate_message_id(),
      type: Keyword.get(opts, :type, :notification),
      from: Keyword.get(opts, :from, :unknown),
      to: to,
      payload: payload,
      priority: Keyword.get(opts, :priority, :normal),
      timestamp: System.system_time(:millisecond),
      timeout: Keyword.get(opts, :timeout),
      reply_to: Keyword.get(opts, :reply_to),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp generate_message_id() do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> String.slice(0, 22)
  end

  defp validate_protocol(protocol) do
    required_fields = [:name, :version, :message_types]

    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(protocol, field)
    end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  defp validate_and_route_message(message, state) do
    with :ok <- validate_message(message),
         :ok <- validate_target_exists(message.to),
         {:ok, processed_message} <- process_message(message, state) do
      route_message(processed_message, state)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_message(message) do
    required_fields = [:id, :type, :from, :to, :payload, :timestamp]

    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(message, field) or is_nil(Map.get(message, field))
    end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:invalid_message, missing_fields}}
    end
  end

  defp validate_target_exists(target) when is_atom(target) do
    case Process.whereis(target) do
      nil -> {:error, {:target_not_found, target}}
      _pid -> :ok
    end
  end

  defp validate_target_exists(target) when is_pid(target) do
    if Process.alive?(target) do
      :ok
    else
      {:error, {:target_not_found, target}}
    end
  end

  defp validate_target_exists(targets) when is_list(targets) do
    Enum.reduce_while(targets, :ok, fn target, _acc ->
      case validate_target_exists(target) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp process_message(message, state) do
    # Apply any message transformation rules from protocols
    case get_protocol_for_message(message, state.protocols) do
      nil -> {:ok, message}
      protocol -> apply_protocol_transformations(message, protocol)
    end
  end

  defp get_protocol_for_message(message, protocols) do
    # Simple protocol matching based on message type
    Enum.find_value(protocols, fn {_name, protocol} ->
      if message.type in protocol.message_types do
        protocol
      else
        nil
      end
    end)
  end

  defp apply_protocol_transformations(message, protocol) do
    # Apply transformation rules from the protocol
    case Map.get(protocol, :transformation_rules) do
      nil -> {:ok, message}
      rules -> apply_transformation_rules(message, rules)
    end
  end

  defp apply_transformation_rules(message, _rules) do
    # Simple rule application - can be extended
    {:ok, message}
  end

  defp route_message(message, state) do
    case message.type do
      :broadcast ->
        route_broadcast_message(message, state)
      _ ->
        route_individual_message(message, state)
    end
  end

  defp route_individual_message(message, state) do
    target = message.to

    case Map.get(state.message_handlers, target) do
      nil ->
        # Send directly to the target process
        send(target, {:component_message, message.from, message.payload})
        {:ok, state}

      handler_module ->
        # Use custom message handler
        case apply(handler_module, :handle_message, [message]) do
          :ok -> {:ok, state}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp route_broadcast_message(message, state) do
    # For broadcast, send directly to the target
    target = message.to

    cond do
      is_pid(target) ->
        send(target, {:component_message, message.from, message.payload})
        {:ok, state}
      is_atom(target) ->
        case Process.whereis(target) do
          nil -> {:error, {:target_not_found, target}}
          pid ->
            send(pid, {:component_message, message.from, message.payload})
            {:ok, state}
        end
      true ->
        {:error, {:invalid_target, target}}
    end
  end

  defp handle_incoming_message(message, state) do
    # Handle responses to pending requests
    if message.type == :response and Map.has_key?(message.metadata, :request_id) do
      request_id = message.metadata.request_id
      send(self(), {:message_response, request_id, message.payload})
    end

    {:ok, state}
  end

  defp validate_message_handler(handler_module) do
    if function_exported?(handler_module, :handle_message, 1) do
      :ok
    else
      {:error, :invalid_handler}
    end
  end

  defp update_statistics(stats, operation, count \\ 1) do
    case operation do
      :sent -> %{stats | messages_sent: stats.messages_sent + count}
      :received -> %{stats | messages_received: stats.messages_received + count}
      :failed -> %{stats | messages_failed: stats.messages_failed + count}
    end
  end

  defp update_latency_statistics(stats, latency) do
    current_avg = stats.average_latency
    total_messages = stats.messages_sent + stats.messages_received

    new_avg = if total_messages > 0 do
      (current_avg * (total_messages - 1) + latency) / total_messages
    else
      latency
    end

    %{stats | average_latency: new_avg}
  end
end
