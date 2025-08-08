defmodule PacketflowChatDemo.ChatSystem do
  @moduledoc """
  PacketFlow DSL-based LLM Chat System

  This module demonstrates how to use PacketFlow's DSL to build a complete
  LLM chat application with capability-based security, context management,
  and distributed processing.
  """

  use PacketFlow.DSL

  # ============================================================================
  # CAPABILITIES - Define what users can do
  # ============================================================================

  defcapability ChatCap do
    def send_message(), do: {:send_message}
    def view_history(), do: {:view_history}
    def admin(), do: {:admin}
    def stream_response(), do: {:stream_response}
    def manage_sessions(), do: {:manage_sessions}
    def rate_limit(), do: {:rate_limit}

    def implications do
      [
        {admin(), [send_message(), view_history(), stream_response(), manage_sessions()]},
        {send_message(), [view_history(), rate_limit()]},
        {stream_response(), [view_history()]},
        {manage_sessions(), [view_history()]}
      ]
    end
  end

  # ============================================================================
  # CONTEXTS - Define what information flows through the system
  # ============================================================================

  defsimple_context ChatContext, [:user_id, :session_id, :capabilities, :model_config, :rate_limits, :stream_config] do
    @propagation_strategy :inherit
  end

  # ============================================================================
  # INTENTS - Define what users want to do
  # ============================================================================

  defsimple_intent SendMessageIntent, [:user_id, :message, :session_id] do
    @capabilities [ChatCap.send_message]
  end

  defsimple_intent StreamMessageIntent, [:user_id, :message, :session_id] do
    @capabilities [ChatCap.stream_response]
  end

  defsimple_intent GetHistoryIntent, [:user_id, :session_id] do
    @capabilities [ChatCap.view_history]
  end

  defsimple_intent AdminConfigIntent, [:user_id, :model_config] do
    @capabilities [ChatCap.admin]
  end

  defsimple_intent ManageSessionIntent, [:user_id, :session_id, :action] do
    @capabilities [ChatCap.manage_sessions]
  end

  # ============================================================================
  # EFFECTS - Define what happens as a result of intents
  # ============================================================================

  # Define effect structures for different outcomes
  defmodule ChatEffect do
    defstruct [:type, :data]

    def message_sent(data) do
      %__MODULE__{type: :message_sent, data: data}
    end

    def stream_started(data) do
      %__MODULE__{type: :stream_started, data: data}
    end

    def stream_chunk(data) do
      %__MODULE__{type: :stream_chunk, data: data}
    end

    def stream_ended(data) do
      %__MODULE__{type: :stream_ended, data: data}
    end

    def history_retrieved(data) do
      %__MODULE__{type: :history_retrieved, data: data}
    end

    def config_updated(data) do
      %__MODULE__{type: :config_updated, data: data}
    end

    def session_managed(data) do
      %__MODULE__{type: :session_managed, data: data}
    end

    def rate_limited(data) do
      %__MODULE__{type: :rate_limited, data: data}
    end

    def error(data) do
      %__MODULE__{type: :error, data: data}
    end
  end

  # ============================================================================
  # REACTORS - Define how the system responds to intents
  # ============================================================================

  defsimple_reactor ChatReactor, [:sessions, :model_config, :rate_limits, :streams] do
    def init(_opts) do
      initial_state = %__MODULE__{
        sessions: %{},
        model_config: %{
          model: "gpt-3.5-turbo",
          max_tokens: 1000,
          temperature: 0.7,
          stream: false
        },
        rate_limits: %{},
        streams: %{}
      }
      {:ok, initial_state}
    end

    def process_intent(intent, state) do
      require Logger
      Logger.info("Processing intent: #{inspect(intent)}")

      # Check rate limits first
      case check_rate_limits(intent, state) do
        {:ok, state} ->
          result = case intent do
            %SendMessageIntent{} ->
              handle_send_message(intent, state)
            %StreamMessageIntent{} ->
              handle_stream_message(intent, state)
            %GetHistoryIntent{} ->
              handle_get_history(intent, state)
            %AdminConfigIntent{} ->
              handle_admin_config(intent, state)
            %ManageSessionIntent{} ->
              handle_manage_session(intent, state)
            _ ->
              {:error, :unsupported_intent}
          end
          Logger.info("Process intent result: #{inspect(result)}")
          result

        {:error, reason} ->
          {:error, state, [ChatEffect.rate_limited(%{reason: reason})]}
      end
    end

    def handle_call(:get_state, _from, state) do
      {:reply, {:ok, state}, state}
    end

    # ============================================================================
    # HANDLER IMPLEMENTATIONS
    # ============================================================================

    defp handle_send_message(intent, state) do
      %{user_id: user_id, message: message, session_id: session_id} = intent

      # Get or create session
      session = get_session(state.sessions, session_id)

      # Add user message to history
      updated_session = add_message_to_session(session, user_id, message, :user)

      # Generate AI response
      case generate_ai_response(message, updated_session.messages, state.model_config) do
        {:ok, ai_response} ->
          # Add AI response to history
          final_session = add_message_to_session(updated_session, "ai", ai_response, :assistant)

          # Update state
          updated_sessions = Map.put(state.sessions, session_id, final_session)

          # Return effect
          {:ok,
           struct(state, sessions: updated_sessions),
           [ChatEffect.message_sent(%{
             message_id: generate_message_id(),
             response: ai_response,
             timestamp: DateTime.utc_now()
           })]}

        {:error, reason} ->
          {:error,
           state,
           [ChatEffect.error(%{
             error_code: :ai_generation_failed,
             message: "Failed to generate AI response: #{reason}"
           })]}
      end
    end

    defp handle_stream_message(intent, state) do
      %{user_id: user_id, message: message, session_id: session_id} = intent

      # Get or create session
      session = get_session(state.sessions, session_id)

      # Add user message to history
      updated_session = add_message_to_session(session, user_id, message, :user)

      # Start streaming response
      stream_id = generate_stream_id()
      updated_streams = Map.put(state.streams, stream_id, %{
        session_id: session_id,
        user_id: user_id,
        started_at: DateTime.utc_now()
      })

      # Update sessions
      updated_sessions = Map.put(state.sessions, session_id, updated_session)

      # Start streaming in background
      Task.start(fn ->
        stream_ai_response(stream_id, message, updated_session.messages, state.model_config)
      end)

      {:ok,
       struct(state, sessions: updated_sessions, streams: updated_streams),
       [ChatEffect.stream_started(%{
         stream_id: stream_id,
         session_id: session_id
       })]}
    end

    defp handle_get_history(intent, state) do
      %{user_id: _user_id, session_id: session_id} = intent

      case Map.get(state.sessions, session_id) do
        nil ->
          {:error,
           state,
           [ChatEffect.error(%{
             error_code: :session_not_found,
             message: "Session not found"
           })]}

        session ->
          {:ok,
           state,
           [ChatEffect.history_retrieved(%{
             messages: session.messages,
             session_id: session_id
           })]}
      end
    end

    defp handle_admin_config(intent, state) do
      %{user_id: user_id, model_config: new_config} = intent

      updated_config = Map.merge(state.model_config, new_config)

      {:ok,
       struct(state, model_config: updated_config),
       [ChatEffect.config_updated(%{
         model_config: updated_config,
         updated_by: user_id
       })]}
    end

    defp handle_manage_session(intent, state) do
      %{user_id: user_id, session_id: session_id, action: action} = intent

      case action do
        "delete" ->
          updated_sessions = Map.delete(state.sessions, session_id)
          {:ok,
           struct(state, sessions: updated_sessions),
           [ChatEffect.session_managed(%{
             action: "deleted",
             session_id: session_id,
             managed_by: user_id
           })]}

        "clear" ->
          session = get_session(state.sessions, session_id)
          cleared_session = %{session | messages: []}
          updated_sessions = Map.put(state.sessions, session_id, cleared_session)
          {:ok,
           struct(state, sessions: updated_sessions),
           [ChatEffect.session_managed(%{
             action: "cleared",
             session_id: session_id,
             managed_by: user_id
           })]}

        _ ->
          {:error,
           state,
           [ChatEffect.error(%{
             error_code: :invalid_action,
             message: "Invalid session action: #{action}"
           })]}
      end
    end

    # ============================================================================
    # HELPER FUNCTIONS
    # ============================================================================

    defp check_rate_limits(intent, state) do
      %{user_id: user_id} = intent
      user_limits = Map.get(state.rate_limits, user_id, %{count: 0, reset_at: DateTime.utc_now()})

      now = DateTime.utc_now()

      if DateTime.compare(user_limits.reset_at, now) == :gt do
        # Within rate limit window
        if user_limits.count < 10 do
          # Allow request
          updated_limits = %{user_limits | count: user_limits.count + 1}
          updated_rate_limits = Map.put(state.rate_limits, user_id, updated_limits)
          {:ok, struct(state, rate_limits: updated_rate_limits)}
        else
          {:error, "Rate limit exceeded"}
        end
      else
        # Reset rate limit window
        reset_at = DateTime.add(now, 60, :second) # 1 minute window
        updated_limits = %{count: 1, reset_at: reset_at}
        updated_rate_limits = Map.put(state.rate_limits, user_id, updated_limits)
        {:ok, struct(state, rate_limits: updated_rate_limits)}
      end
    end

    defp get_session(sessions, session_id) do
      case Map.get(sessions, session_id) do
        nil -> %{id: session_id, messages: [], created_at: DateTime.utc_now()}
        session -> session
      end
    end

    defp add_message_to_session(session, sender, content, role) do
      message = %{
        id: generate_message_id(),
        sender: sender,
        content: content,
        role: role,
        timestamp: DateTime.utc_now()
      }

      %{session | messages: [message | session.messages]}
    end

    defp generate_message_id do
      :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    end

    defp generate_stream_id do
      :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    end

    defp generate_ai_response(user_message, message_history, config) do
      # Use real OpenAI API instead of simulation
      case PacketflowChatDemo.OpenAIService.generate_response(user_message, message_history, config) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> {:error, reason}
      end
    end

    defp stream_ai_response(stream_id, user_message, message_history, config) do
      # Use real OpenAI streaming API
      PacketflowChatDemo.OpenAIService.start_stream_to_process(
        user_message,
        message_history,
        config,
        self()
      )

      # Handle streaming messages
      handle_stream_messages(stream_id)
    end

    defp handle_stream_messages(stream_id) do
      require Logger
      receive do
        {:stream_started, _ref} ->
          Logger.info("Stream started for #{stream_id}")
          # Broadcast stream start event
          Phoenix.PubSub.broadcast(
            PacketflowChatDemo.PubSub,
            "chat_stream:#{stream_id}",
            {:stream_started, stream_id}
          )
          handle_stream_messages(stream_id)

        {:stream_chunk, content} ->
          Logger.info("Stream chunk for #{stream_id}: #{content}")
          # Broadcast chunk to subscribers
          Phoenix.PubSub.broadcast(
            PacketflowChatDemo.PubSub,
            "chat_stream:#{stream_id}",
            {:stream_chunk, stream_id, content}
          )
          handle_stream_messages(stream_id)

        {:stream_ended} ->
          Logger.info("Stream ended for #{stream_id}")
          # Broadcast stream end event
          Phoenix.PubSub.broadcast(
            PacketflowChatDemo.PubSub,
            "chat_stream:#{stream_id}",
            {:stream_ended, stream_id}
          )

        {:stream_error, reason} ->
          Logger.error("Stream error for #{stream_id}: #{reason}")
          # Broadcast error event
          Phoenix.PubSub.broadcast(
            PacketflowChatDemo.PubSub,
            "chat_stream:#{stream_id}",
            {:stream_error, stream_id, reason}
          )

      after
        30_000 -> # 30 second timeout
          Logger.error("Stream timeout for #{stream_id}")
          Phoenix.PubSub.broadcast(
            PacketflowChatDemo.PubSub,
            "chat_stream:#{stream_id}",
            {:stream_error, stream_id, :timeout}
          )
      end
    end


  end


end
