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

    def implications do
      [
        {admin(), [send_message(), view_history()]},
        {send_message(), [view_history()]}
      ]
    end
  end

  # ============================================================================
  # CONTEXTS - Define what information flows through the system
  # ============================================================================

  defsimple_context ChatContext, [:user_id, :session_id, :capabilities, :model_config] do
    @propagation_strategy :inherit
  end

  # ============================================================================
  # INTENTS - Define what users want to do
  # ============================================================================

  defsimple_intent SendMessageIntent, [:user_id, :message, :session_id] do
    @capabilities [ChatCap.send_message]
  end

  defsimple_intent GetHistoryIntent, [:user_id, :session_id] do
    @capabilities [ChatCap.view_history]
  end

  defsimple_intent AdminConfigIntent, [:user_id, :model_config] do
    @capabilities [ChatCap.admin]
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

    def history_retrieved(data) do
      %__MODULE__{type: :history_retrieved, data: data}
    end

    def config_updated(data) do
      %__MODULE__{type: :config_updated, data: data}
    end

    def error(data) do
      %__MODULE__{type: :error, data: data}
    end
  end

  # ============================================================================
  # REACTORS - Define how the system responds to intents
  # ============================================================================

  defsimple_reactor ChatReactor, [:sessions, :model_config] do
    def init(_opts) do
      initial_state = %__MODULE__{
        sessions: %{},
        model_config: %{
          model: "gpt-3.5-turbo",
          max_tokens: 1000,
          temperature: 0.7
        }
      }
      {:ok, initial_state}
    end

    def process_intent(intent, state) do
      require Logger
      Logger.info("Processing intent: #{inspect(intent)}")
      Logger.info("Current state: #{inspect(state)}")

      result = case intent do
        %SendMessageIntent{} ->
          handle_send_message(intent, state)
        %GetHistoryIntent{} ->
          handle_get_history(intent, state)
        %AdminConfigIntent{} ->
          handle_admin_config(intent, state)
        _ ->
          {:error, :unsupported_intent}
      end

      Logger.info("Process intent result: #{inspect(result)}")
      result
    end

    def handle_call(:get_state, _from, state) do
      {:reply, {:ok, state}, state}
    end

    # ============================================================================
    # HANDLER IMPLEMENTATIONS
    # ============================================================================

    defp handle_send_message(intent, state) do
      # Extract message data
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

    # ============================================================================
    # HELPER FUNCTIONS
    # ============================================================================

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

    defp generate_ai_response(user_message, message_history, config) do
      # Simulate AI response generation
      # In a real application, this would call an actual LLM API
      case simulate_llm_call(user_message, message_history, config) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> {:error, reason}
      end
    end

    defp simulate_llm_call(user_message, _message_history, _config) do
      # Simulate API call delay
      Process.sleep(100)

      # Simple response simulation based on message content
      msg = String.downcase(user_message)
      response = cond do
        String.contains?(msg, "hello") or String.contains?(msg, "hi") ->
          "Hello! I'm your AI assistant powered by PacketFlow. How can I help you today?"

        String.contains?(msg, "help") ->
          "I can help you with various tasks. Try asking me questions about PacketFlow, Elixir, or any other topic!"

        String.contains?(msg, "packetflow") ->
          "PacketFlow is a production-ready distributed computing framework for Elixir that provides a domain-specific language (DSL) for building intent-context-capability oriented systems."

        String.contains?(msg, "capabilities") ->
          "Capabilities in PacketFlow provide fine-grained permission control with implication hierarchies. They define what users can do in the system."

        String.contains?(msg, "context") ->
          "Context in PacketFlow manages information flow through the system with automatic propagation strategies."

        String.contains?(msg, "intent") ->
          "Intents in PacketFlow represent what users want to do, with capability requirements and effect definitions."

        true ->
          "That's an interesting question! I'm here to help you explore PacketFlow and its capabilities. What would you like to know more about?"
      end

      {:ok, response}
    end
  end


end
