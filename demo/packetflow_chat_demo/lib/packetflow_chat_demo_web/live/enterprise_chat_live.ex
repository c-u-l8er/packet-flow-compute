defmodule PacketflowChatDemoWeb.EnterpriseChatLive do
  use PacketflowChatDemoWeb, :live_view

  alias PacketflowChatDemo.{Accounts, Chat, AIConfig, Usage}

  def mount(%{"tenant_slug" => tenant_slug}, _session, socket) do
    # Authentication is handled by the on_mount hook
    current_user = socket.assigns.current_user
    tenant = Accounts.get_tenant_by_slug!(tenant_slug)

    # Verify access
    unless Accounts.tenant_member?(tenant.id, current_user.id) do
      {:ok, redirect(socket, to: ~p"/login")}
    else
      # Get user's sessions for this tenant
      sessions = Chat.list_user_sessions(tenant.id, current_user.id)

      # Create default session if none exist
      active_session = case sessions do
        [] ->
          {:ok, session} = Chat.create_session(%{
            title: "New Chat",
            tenant_id: tenant.id,
            user_id: current_user.id,
            model: tenant.default_model
          })
          # Load the session with messages (will be empty for new session)
          Chat.get_session_with_messages(session.id)
        [session | _] ->
          Chat.get_session_with_messages(session.id)
      end

      # Subscribe to chat updates
      Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat:#{active_session.id}")

      {:ok, assign(socket,
        current_user: current_user,
        tenant: tenant,
        sessions: sessions,
        active_session: active_session,
        active_tab: active_session.id,
        messages: active_session.messages || [],
        message_input: "",
        selected_model: active_session.model || tenant.default_model,
        available_models: AIConfig.available_models(),
        is_streaming: false,
        settings_open: false,
        streaming_message: nil,
        streaming_content: "",
        editing_session_id: nil,
        editing_header_title: false
      )}
    end
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    session = socket.assigns.active_session
    user = socket.assigns.current_user
    model = socket.assigns.selected_model

    # Create user message
    {:ok, user_message} = Chat.create_message(%{
      content: message,
      role: :user,
      session_id: session.id,
      user_id: user.id
    })

    # Model is now updated immediately when selected, no need to update here

    # Clear input and add message to UI
    updated_messages = socket.assigns.messages ++ [user_message]

    socket = assign(socket,
      messages: updated_messages,
      message_input: "",
      is_streaming: true,
      streaming_message: nil,
      streaming_content: ""
    )

    # Start AI response generation using PacketFlow streaming
    case PacketflowChatDemo.ChatReactor.stream_message(
      "enterprise_user_#{user.id}",
      message,
      "enterprise_session_#{session.id}",
      [
        model: model,
        temperature: socket.assigns.tenant.temperature
      ]
    ) do
      {:ok, response} ->
        # Subscribe to the stream
        stream_id = response.stream_id
        Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat_stream:#{stream_id}")

        # Create placeholder streaming message
        streaming_message = %{
          id: generate_message_id(),
          content: "",
          role: :assistant,
          session_id: session.id,
          user_id: nil,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          model_used: nil,
          token_count: nil,
          metadata: %{},
          is_streaming: true
        }

        updated_messages_with_stream = updated_messages ++ [streaming_message]

        socket = assign(socket,
          messages: updated_messages_with_stream,
          streaming_message: streaming_message,
          streaming_content: ""
        )

        {:noreply, socket}

      {:error, error} ->
        # Create error message
        {:ok, error_message} = Chat.create_message(%{
          content: "Error: #{error.message || "Unknown error"}",
          role: :assistant,
          session_id: session.id,
          model_used: model
        })

        updated_messages_with_error = updated_messages ++ [error_message]

        socket = assign(socket,
          messages: updated_messages_with_error,
          is_streaming: false
        )

        {:noreply, socket}
    end
  end

  def handle_event("send_message", _, socket) do
    {:noreply, socket}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, message_input: message)}
  end

  def handle_event("select_model", %{"model" => model}, socket) do
    session = socket.assigns.active_session

    # Update the session's model in the database immediately
    case Chat.update_session(session, %{model: model}) do
      {:ok, _updated_session} ->
        # Update the active session and sessions list
        updated_active_session = %{session | model: model}
        updated_sessions = Enum.map(socket.assigns.sessions, fn s ->
          if s.id == session.id, do: %{s | model: model}, else: s
        end)

        {:noreply, assign(socket,
          selected_model: model,
          active_session: updated_active_session,
          sessions: updated_sessions
        )}

      {:error, _changeset} ->
        # If update fails, keep the current model
        {:noreply, socket}
    end
  end

  def handle_event("switch_session", %{"session_id" => session_id}, socket) do
    session = Chat.get_session_with_messages(session_id)

    # Unsubscribe from old session
    Phoenix.PubSub.unsubscribe(PacketflowChatDemo.PubSub, "chat:#{socket.assigns.active_session.id}")

    # Subscribe to new session
    Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat:#{session_id}")

    {:noreply, assign(socket,
      active_session: session,
      active_tab: session.id,
      messages: session.messages || [],
      selected_model: session.model || socket.assigns.tenant.default_model,
      editing_session_id: nil,
      editing_header_title: false
    )}
  end

  def handle_event("new_session", _params, socket) do
    tenant = socket.assigns.tenant
    user = socket.assigns.current_user

    {:ok, session} = Chat.create_session(%{
      title: "New Chat",
      tenant_id: tenant.id,
      user_id: user.id,
      model: socket.assigns.selected_model
    })

    session_with_messages = Chat.get_session_with_messages(session.id)
    updated_sessions = [session_with_messages | socket.assigns.sessions]

    # Switch to new session
    Phoenix.PubSub.unsubscribe(PacketflowChatDemo.PubSub, "chat:#{socket.assigns.active_session.id}")
    Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat:#{session.id}")

    {:noreply, assign(socket,
      sessions: updated_sessions,
      active_session: session_with_messages,
      active_tab: session.id,
      messages: [],
      editing_session_id: nil,
      editing_header_title: false
    )}
  end

  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))

    if session do
      Chat.delete_session(session)
      updated_sessions = Enum.reject(socket.assigns.sessions, &(&1.id == session_id))

      # If deleting active session, switch to first available or create new
      if socket.assigns.active_session.id == session_id do
        case updated_sessions do
          [first_session | _] ->
            # Load the session with messages preloaded for consistency
            session_with_messages = Chat.get_session_with_messages(first_session.id)

            Phoenix.PubSub.unsubscribe(PacketflowChatDemo.PubSub, "chat:#{session_id}")
            Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat:#{first_session.id}")

            {:noreply, assign(socket,
              sessions: updated_sessions,
              active_session: session_with_messages,
              active_tab: session_with_messages.id,
              messages: session_with_messages.messages || []
            )}

          [] ->
            send(self(), :create_default_session)
            {:noreply, assign(socket, sessions: updated_sessions)}
        end
      else
        {:noreply, assign(socket, sessions: updated_sessions)}
      end
    else
      {:noreply, socket}
    end
  end



  def handle_event("toggle_settings", _params, socket) do
    {:noreply, assign(socket, settings_open: !socket.assigns.settings_open)}
  end

  def handle_event("cancel_streaming", _params, socket) do
    {:noreply, assign(socket, is_streaming: false)}
  end

  def handle_event("edit_session_title", %{"session_id" => session_id}, socket) do
    {:noreply, assign(socket, editing_session_id: session_id)}
  end

  def handle_event("cancel_edit_session", _params, socket) do
    {:noreply, assign(socket, editing_session_id: nil)}
  end

  def handle_event("save_session_title", %{"session_id" => session_id, "title" => title}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))

    if session do
      trimmed_title = String.trim(title)
      final_title = if trimmed_title == "", do: "New Chat", else: trimmed_title

      case Chat.update_session(session, %{title: final_title}) do
        {:ok, _updated_session} ->
          # Update sessions list
          updated_sessions = Enum.map(socket.assigns.sessions, fn s ->
            if s.id == session_id, do: %{s | title: final_title}, else: s
          end)

          # Update active session if it's the one being edited
          updated_active_session = if socket.assigns.active_session.id == session_id do
            %{socket.assigns.active_session | title: final_title}
          else
            socket.assigns.active_session
          end

          {:noreply, assign(socket,
            sessions: updated_sessions,
            active_session: updated_active_session,
            editing_session_id: nil
          )}

        {:error, _changeset} ->
          {:noreply, assign(socket, editing_session_id: nil)}
      end
    else
      {:noreply, assign(socket, editing_session_id: nil)}
    end
  end

  def handle_event("edit_header_title", _params, socket) do
    {:noreply, assign(socket, editing_header_title: true)}
  end

  def handle_event("cancel_edit_header", _params, socket) do
    {:noreply, assign(socket, editing_header_title: false)}
  end

  def handle_event("save_header_title", %{"title" => title}, socket) do
    session = socket.assigns.active_session
    trimmed_title = String.trim(title)
    final_title = if trimmed_title == "", do: "New Chat", else: trimmed_title

    case Chat.update_session(session, %{title: final_title}) do
      {:ok, _updated_session} ->
        # Update sessions list
        updated_sessions = Enum.map(socket.assigns.sessions, fn s ->
          if s.id == session.id, do: %{s | title: final_title}, else: s
        end)

        # Update active session
        updated_active_session = %{socket.assigns.active_session | title: final_title}

        {:noreply, assign(socket,
          sessions: updated_sessions,
          active_session: updated_active_session,
          editing_header_title: false
        )}

      {:error, _changeset} ->
        {:noreply, assign(socket, editing_header_title: false)}
    end
  end

  def handle_info({:stream_started, _stream_id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:stream_chunk, _stream_id, content}, socket) do
    if socket.assigns.streaming_message do
      updated_content = socket.assigns.streaming_content <> content

      # Update the streaming message content
      updated_messages =
        socket.assigns.messages
        |> Enum.map(fn msg ->
          if Map.get(msg, :is_streaming) && Map.get(msg, :id) == socket.assigns.streaming_message.id do
            %{msg | content: updated_content}
          else
            msg
          end
        end)

      socket = assign(socket,
        messages: updated_messages,
        streaming_content: updated_content
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:stream_ended, stream_id}, socket) do
    if socket.assigns.streaming_message do
      # Create final AI message in database
      {:ok, ai_message} = Chat.create_message(%{
        content: socket.assigns.streaming_content,
        role: :assistant,
        session_id: socket.assigns.active_session.id,
        model_used: socket.assigns.selected_model
      })

      # Record usage for billing (with mock data for now)
      # In a real implementation, you'd get these from the AI provider response
      record_usage_async(socket, ai_message, %{
        prompt_tokens: estimate_tokens(socket.assigns.messages),
        completion_tokens: estimate_tokens([%{content: socket.assigns.streaming_content}]),
        stream_id: stream_id
      })

      # Mark the streaming message as complete and replace with DB message
      updated_messages =
        socket.assigns.messages
        |> Enum.map(fn msg ->
          if Map.get(msg, :is_streaming) && Map.get(msg, :id) == socket.assigns.streaming_message.id do
            ai_message
          else
            msg
          end
        end)

      socket = assign(socket,
        messages: updated_messages,
        streaming_message: nil,
        streaming_content: "",
        is_streaming: false
      )

      {:noreply, socket}
    else
      {:noreply, assign(socket, is_streaming: false)}
    end
  end

  def handle_info({:stream_error, _stream_id, reason}, socket) do
    # Create error message
    {:ok, error_message} = Chat.create_message(%{
      content: "Streaming error: #{inspect(reason)}",
      role: :assistant,
      session_id: socket.assigns.active_session.id,
      model_used: socket.assigns.selected_model
    })

    # Replace streaming message with error message
    updated_messages =
      if socket.assigns.streaming_message do
        socket.assigns.messages
        |> Enum.map(fn msg ->
          if Map.get(msg, :is_streaming) && Map.get(msg, :id) == socket.assigns.streaming_message.id do
            error_message
          else
            msg
          end
        end)
      else
        socket.assigns.messages ++ [error_message]
      end

    socket = assign(socket,
      messages: updated_messages,
      streaming_message: nil,
      streaming_content: "",
      is_streaming: false
    )

    {:noreply, socket}
  end

  def handle_info(:create_default_session, socket) do
    tenant = socket.assigns.tenant
    user = socket.assigns.current_user

    {:ok, session} = Chat.create_session(%{
      title: "New Chat",
      tenant_id: tenant.id,
      user_id: user.id,
      model: socket.assigns.selected_model
    })

    session_with_messages = Chat.get_session_with_messages(session.id)
    Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat:#{session.id}")

    {:noreply, assign(socket,
      sessions: [session_with_messages],
      active_session: session_with_messages,
      active_tab: session.id,
      messages: []
    )}
  end

  # Usage tracking helpers
  defp record_usage_async(socket, message, token_info) do
    tenant = socket.assigns.tenant
    user = socket.assigns.current_user
    session = socket.assigns.active_session
    model = socket.assigns.selected_model

    Task.start(fn ->
      prompt_tokens = token_info.prompt_tokens
      completion_tokens = token_info.completion_tokens
      total_tokens = prompt_tokens + completion_tokens

      # Calculate cost using centralized pricing
      cost_info = AIConfig.calculate_cost(model, prompt_tokens, completion_tokens)

      Usage.record_usage(%{
        tenant_id: tenant.id,
        user_id: user.id,
        session_id: session.id,
        message_id: message.id,
        model: model,
        provider: cost_info.provider,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        total_tokens: total_tokens,
        prompt_cost_cents: cost_info.prompt_cost_cents,
        completion_cost_cents: cost_info.completion_cost_cents,
        total_cost_cents: cost_info.total_cost_cents,
        temperature: tenant.temperature,
        max_tokens: tenant.max_tokens,
        success: true
      })
    end)
  end

  # Simple token estimation (replace with proper tokenizer in production)
  defp estimate_tokens(messages) when is_list(messages) do
    messages
    |> Enum.map(fn msg -> estimate_tokens_for_content(msg.content || "") end)
    |> Enum.sum()
  end

  defp estimate_tokens_for_content(content) when is_binary(content) do
    # Rough approximation: 1 token ≈ 4 characters for English text
    # This should be replaced with a proper tokenizer like tiktoken
    content
    |> String.length()
    |> div(4)
    |> max(1)
  end

  defp generate_message_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
    |> String.replace("T", " ")
    |> String.replace("Z", "")
  end

  defp format_message_content(content) do
    content
    |> String.replace("\n", "<br>")
    |> Phoenix.HTML.raw()
  end
end
