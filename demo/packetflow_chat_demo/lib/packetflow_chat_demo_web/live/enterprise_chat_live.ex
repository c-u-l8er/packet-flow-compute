defmodule PacketflowChatDemoWeb.EnterpriseChatLive do
  use PacketflowChatDemoWeb, :live_view

  alias PacketflowChatDemo.{Accounts, Chat}

  @models %{
    "gpt-4" => "GPT-4",
    "gpt-4-turbo" => "GPT-4 Turbo",
    "gpt-3.5-turbo" => "GPT-3.5 Turbo",
    "claude-3-opus" => "Claude 3 Opus",
    "claude-3-sonnet" => "Claude 3 Sonnet",
    "claude-3-haiku" => "Claude 3 Haiku"
  }

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
        available_models: get_available_models(tenant),
        is_streaming: false,
        settings_open: false
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

    # Update the session's model if it changed
    if session.model != model do
      Chat.update_session(session, %{model: model})
    end

    # Clear input and add message to UI
    updated_messages = socket.assigns.messages ++ [user_message]

    socket = assign(socket,
      messages: updated_messages,
      message_input: "",
      is_streaming: true
    )

    # Start AI response generation
    send(self(), {:generate_ai_response, user_message, model})

    {:noreply, socket}
  end

  def handle_event("send_message", _, socket) do
    {:noreply, socket}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, message_input: message)}
  end

  def handle_event("select_model", %{"model" => model}, socket) do
    {:noreply, assign(socket, selected_model: model)}
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
      selected_model: session.model || socket.assigns.tenant.default_model
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
      messages: []
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
            Phoenix.PubSub.unsubscribe(PacketflowChatDemo.PubSub, "chat:#{session_id}")
            Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat:#{first_session.id}")

            {:noreply, assign(socket,
              sessions: updated_sessions,
              active_session: first_session,
              active_tab: first_session.id,
              messages: first_session.messages || []
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

  def handle_info({:generate_ai_response, user_message, model}, socket) do
    # Generate AI response with proper error handling
    parent = self()

    Task.start_link(fn ->
      try do
        # Simulate thinking time
        Process.sleep(1000 + :rand.uniform(2000))

        ai_response = generate_ai_response(user_message.content, model, socket.assigns.tenant)

        send(parent, {:ai_response_ready, ai_response, user_message.session_id})
      rescue
        error ->
          IO.inspect(error, label: "AI Response Generation Error")
          send(parent, {:ai_response_error, "Sorry, I encountered an error while generating a response.", user_message.session_id})
      end
    end)

    {:noreply, socket}
  end

  def handle_info({:ai_response_ready, response, session_id}, socket) do
    if socket.assigns.active_session.id == session_id do
      # Create AI message
      {:ok, ai_message} = Chat.create_message(%{
        content: response,
        role: :assistant,
        session_id: session_id,
        model_used: socket.assigns.selected_model
      })

      updated_messages = socket.assigns.messages ++ [ai_message]

      {:noreply, assign(socket,
        messages: updated_messages,
        is_streaming: false
      )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:ai_response_error, error_message, session_id}, socket) do
    if socket.assigns.active_session.id == session_id do
      # Create error message
      {:ok, error_msg} = Chat.create_message(%{
        content: error_message,
        role: :assistant,
        session_id: session_id,
        model_used: socket.assigns.selected_model
      })

      updated_messages = socket.assigns.messages ++ [error_msg]

      {:noreply, assign(socket,
        messages: updated_messages,
        is_streaming: false
      )}
    else
      {:noreply, socket}
    end
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

  defp get_available_models(tenant) do
    base_models = @models

    # Filter models based on available API keys
    available = Enum.filter(base_models, fn {model, _name} ->
      case model do
        "gpt-" <> _ -> tenant.openai_api_key != nil
        "claude-" <> _ -> tenant.anthropic_api_key != nil
        _ -> true
      end
    end)

    if Enum.empty?(available), do: base_models, else: available
  end

  defp generate_ai_response(user_message, model, tenant) do
    # This is a placeholder - replace with actual API integration
    responses = [
      "I understand your question about '#{String.slice(user_message, 0, 20)}...'. Let me help you with that.",
      "That's an interesting point. Based on what you've shared, I think...",
      "I can help you with that. Here's what I recommend...",
      "Good question! Let me break this down for you...",
      "I see what you're looking for. Here's my analysis..."
    ]

    Enum.random(responses) <> "\n\n*[Response generated using #{@models[model] || model}]*"
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
    |> Phoenix.HTML.Safe.to_iodata()
  end
end
