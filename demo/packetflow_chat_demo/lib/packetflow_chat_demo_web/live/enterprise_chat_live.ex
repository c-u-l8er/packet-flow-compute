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
        cms_always_visible: true,
        streaming_message: nil,
        streaming_content: "",
        editing_session_id: nil,
        editing_header_title: false,
        # CMS-related assigns
        cms_enabled: true,
        cms_tab: :preview,
        generated_components: [],
        component_counter: 0,
        selected_component_id: nil,
        dragging_component: nil,
        drag_start_position: nil,
        grid_snap_enabled: true,
        layout_containers: %{
          "main_canvas" => %{
            type: :free_form,
            bounds: %{width: 1200, height: 800},
            grid: %{enabled: true, size: 20},
            background: "#f8fafc"
          }
        },
        # Panel width management (when CMS is always visible)
        chat_panel_width: 50,  # Percentage of available space (excluding sidebar)
        cms_panel_width: 50,   # Percentage of available space (excluding sidebar)
        is_resizing: false
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

    # Clear input and add message to UI
    updated_messages = socket.assigns.messages ++ [user_message]

    # NEW: Check for CMS intent
    case detect_cms_intent(message) do
      {:cms, intent_type, component_type} ->
        handle_cms_message(message, intent_type, component_type, socket, updated_messages)
      :regular ->
        handle_regular_message(message, socket, updated_messages)
    end
  end

  # Extract existing chat logic into separate function
  defp handle_regular_message(message, socket, updated_messages) do
    session = socket.assigns.active_session
    user = socket.assigns.current_user
    model = socket.assigns.selected_model

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

  # CMS Event Handlers
  def handle_event("switch_cms_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)
    {:noreply, assign(socket, cms_tab: tab_atom)}
  end

  def handle_event("select_component", %{"component_id" => component_id}, socket) do
    # Find the selected component
    selected_component = Enum.find(socket.assigns.generated_components, &(&1.id == component_id))

    if selected_component do
      # Create a chat message about the selection
      selection_message = "You've selected the #{selected_component.name} component. What would you like to do with it? You can ask me to modify its styling, add functionality, or create variations."

      # Add the message to chat
      {:ok, ai_message} = Chat.create_message(%{
        content: selection_message,
        role: :assistant,
        session_id: socket.assigns.active_session.id,
        model_used: "cms_generator"
      })

      updated_messages = socket.assigns.messages ++ [ai_message]

      {:noreply, assign(socket,
        messages: updated_messages,
        selected_component_id: component_id
      )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_component", %{"component_id" => component_id}, socket) do
    updated_components = Enum.reject(socket.assigns.generated_components, &(&1.id == component_id))

    # Clear selection if the deleted component was selected
    updated_selection = if socket.assigns.selected_component_id == component_id do
      nil
    else
      socket.assigns.selected_component_id
    end

    {:noreply, assign(socket,
      generated_components: updated_components,
      selected_component_id: updated_selection
    )}
  end

  def handle_event("toggle_grid_snap", _params, socket) do
    {:noreply, assign(socket, grid_snap_enabled: !socket.assigns.grid_snap_enabled)}
  end

  # Panel resize handlers
  def handle_event("start_panel_resize", _params, socket) do
    {:noreply, assign(socket, is_resizing: true)}
  end

  def handle_event("panel_resize", %{"chat_width" => chat_width}, socket) do
    # Ensure widths are within reasonable bounds (20% to 80%)
    chat_width_num = max(20, min(80, chat_width))
    cms_width_num = 100 - chat_width_num

    {:noreply, assign(socket,
      chat_panel_width: chat_width_num,
      cms_panel_width: cms_width_num
    )}
  end

  def handle_event("end_panel_resize", _params, socket) do
    {:noreply, assign(socket, is_resizing: false)}
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

  # CMS Helper Functions

  # Add new private function for intent detection
  defp detect_cms_intent(message) do
    message_lower = String.downcase(message)

    # Debug logging
    IO.puts("🔍 CMS Intent Detection for: '#{message}'")
    IO.puts("   Lowercase: '#{message_lower}'")

    result = cond do
      # Component creation intents
      Regex.match?(~r/create|build|make|generate/, message_lower) and
      Regex.match?(~r/table|form|button|card|dashboard|list/, message_lower) ->
        component_type = extract_component_type(message_lower)
        IO.puts("   ✅ Detected CMS creation intent: #{component_type}")
        {:cms, :create_component, component_type}

      # Component modification intents
      Regex.match?(~r/modify|change|update|edit/, message_lower) ->
        IO.puts("   ✅ Detected CMS modification intent")
        {:cms, :modify_component, nil}

      # Component query intents
      Regex.match?(~r/show|display|what/, message_lower) and
      Regex.match?(~r/components|ui|interface/, message_lower) ->
        IO.puts("   ✅ Detected CMS query intent")
        {:cms, :query_components, nil}

      true ->
        IO.puts("   ❌ No CMS intent detected - treating as regular message")
        :regular
    end

    IO.puts("   Result: #{inspect(result)}")
    result
  end

  defp extract_component_type(message) do
    cond do
      String.contains?(message, "table") -> :table
      String.contains?(message, "form") -> :form
      String.contains?(message, "button") -> :button
      String.contains?(message, "card") -> :card
      String.contains?(message, "dashboard") -> :dashboard
      String.contains?(message, "list") -> :list
      true -> :generic
    end
  end

  # NEW: Handle CMS-specific messages
  defp handle_cms_message(message, intent_type, component_type, socket, updated_messages) do
    case intent_type do
      :create_component ->
        handle_create_component(message, component_type, socket, updated_messages)
      :modify_component ->
        handle_modify_component(message, socket, updated_messages)
      :query_components ->
        handle_query_components(message, socket, updated_messages)
    end
  end

  defp handle_create_component(message, component_type, socket, updated_messages) do
    IO.puts("🔧 Creating component of type: #{component_type}")
    IO.puts("   Current component count: #{length(socket.assigns.generated_components)}")

    # Generate component based on type
    case generate_component(component_type, message, socket) do
      {:ok, component} ->
        IO.puts("   ✅ Component generated successfully: #{component.id}")

        # Add component to generated components
        updated_components = socket.assigns.generated_components ++ [component]
        IO.puts("   📦 Updated component count: #{length(updated_components)}")

        # Create AI response message
        ai_response = create_cms_response_message(component, socket)
        final_messages = updated_messages ++ [ai_response]

        IO.puts("   🎯 Switching to preview tab and updating socket")

        {:noreply, assign(socket,
          messages: final_messages,
          message_input: "",
          generated_components: updated_components,
          component_counter: socket.assigns.component_counter + 1,
          cms_tab: :preview  # Switch to preview tab
        )}

      {:error, reason} ->
        IO.puts("   ❌ Component generation failed: #{reason}")
        error_response = create_error_response(reason, socket)
        final_messages = updated_messages ++ [error_response]

        {:noreply, assign(socket,
          messages: final_messages,
          message_input: ""
        )}
    end
  end

  defp handle_modify_component(message, socket, updated_messages) do
    # For now, just acknowledge the modification request
    response_content = "I understand you'd like to modify a component. Component modification is coming soon! For now, you can delete components and create new ones."

    ai_response = %{
      id: generate_message_id(),
      content: response_content,
      role: :assistant,
      session_id: socket.assigns.active_session.id,
      user_id: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      model_used: "cms_generator",
      token_count: nil,
      metadata: %{is_cms_response: true},
      is_streaming: false
    }

    final_messages = updated_messages ++ [ai_response]

    {:noreply, assign(socket,
      messages: final_messages,
      message_input: ""
    )}
  end

  defp handle_query_components(message, socket, updated_messages) do
    component_count = length(socket.assigns.generated_components)

    response_content = if component_count == 0 do
      "You haven't created any components yet. Try saying 'Create a table' or 'Build a button' to get started!"
    else
      component_types = socket.assigns.generated_components
      |> Enum.map(&(&1.type))
      |> Enum.map(&String.upcase(to_string(&1)))
      |> Enum.join(", ")

      "You currently have #{component_count} component(s): #{component_types}. You can see them in the preview panel on the right!"
    end

    ai_response = %{
      id: generate_message_id(),
      content: response_content,
      role: :assistant,
      session_id: socket.assigns.active_session.id,
      user_id: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      model_used: "cms_generator",
      token_count: nil,
      metadata: %{is_cms_response: true},
      is_streaming: false
    }

    final_messages = updated_messages ++ [ai_response]

    {:noreply, assign(socket,
      messages: final_messages,
      message_input: "",
      cms_tab: :preview
    )}
  end

  # NEW: Component generation functions
  defp generate_component(component_type, message, socket) do
    component_id = "component_#{socket.assigns.component_counter + 1}"

    case component_type do
      :table ->
        {:ok, %{
          id: component_id,
          type: :table,
          name: "Data Table",
          html: generate_table_html(message),
          created_at: DateTime.utc_now(),
          metadata: %{source_message: message},
          layout: %{
            container_id: "main_canvas",
            position: %{x: 100, y: 50},
            size: %{width: 400, height: 300},
            z_index: 1
          }
        }}

      :button ->
        {:ok, %{
          id: component_id,
          type: :button,
          name: "Button",
          html: generate_button_html(message),
          created_at: DateTime.utc_now(),
          metadata: %{source_message: message},
          layout: %{
            container_id: "main_canvas",
            position: %{x: 150, y: 100},
            size: %{width: 120, height: 40},
            z_index: 1
          }
        }}

      :form ->
        {:ok, %{
          id: component_id,
          type: :form,
          name: "Form",
          html: generate_form_html(message),
          created_at: DateTime.utc_now(),
          metadata: %{source_message: message},
          layout: %{
            container_id: "main_canvas",
            position: %{x: 50, y: 50},
            size: %{width: 350, height: 400},
            z_index: 1
          }
        }}

      :card ->
        {:ok, %{
          id: component_id,
          type: :card,
          name: "Card",
          html: generate_card_html(message),
          created_at: DateTime.utc_now(),
          metadata: %{source_message: message},
          layout: %{
            container_id: "main_canvas",
            position: %{x: 200, y: 150},
            size: %{width: 300, height: 200},
            z_index: 1
          }
        }}

      _ ->
        {:error, "Unknown component type: #{component_type}"}
    end
  end

  # HTML generation functions for each component type
  defp generate_table_html(message) do
    """
    <div class="overflow-x-auto">
      <table class="min-w-full bg-white border border-gray-200 rounded-lg">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">John Doe</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">john@example.com</td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">Active</span>
            </td>
          </tr>
          <tr>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Jane Smith</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">jane@example.com</td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">Pending</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="text-xs text-gray-500 mt-2">Generated from: "#{String.slice(message, 0, 50)}..."</p>
    """
  end

  defp generate_button_html(message) do
    button_text = extract_button_text(message) || "Click Me"

    """
    <div class="space-y-2">
      <button class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
        #{button_text}
      </button>
      <p class="text-xs text-gray-500">Generated from: "#{String.slice(message, 0, 50)}..."</p>
    </div>
    """
  end

  defp generate_form_html(message) do
    """
    <div class="max-w-md mx-auto bg-white p-6 rounded-lg border border-gray-200">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Contact Form</h3>
      <form class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
          <input type="text" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
          <input type="email" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Message</label>
          <textarea rows="3" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"></textarea>
        </div>
        <button type="submit" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
          Submit
        </button>
      </form>
      <p class="text-xs text-gray-500 mt-4">Generated from: "#{String.slice(message, 0, 50)}..."</p>
    </div>
    """
  end

  defp generate_card_html(message) do
    """
    <div class="max-w-sm bg-white border border-gray-200 rounded-lg shadow-sm">
      <div class="p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Card Title</h3>
        <p class="text-gray-600 mb-4">This is a sample card component with some descriptive text content.</p>
        <button class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
          Learn More
        </button>
      </div>
      <p class="text-xs text-gray-500 px-6 pb-4">Generated from: "#{String.slice(message, 0, 50)}..."</p>
    </div>
    """
  end

  # Helper function to extract button text from message
  defp extract_button_text(message) do
    # Look for quoted text or common button patterns
    cond do
      match = Regex.run(~r/"([^"]+)"/, message) ->
        Enum.at(match, 1)
      match = Regex.run(~r/'([^']+)'/, message) ->
        Enum.at(match, 1)
      String.contains?(message, "submit") ->
        "Submit"
      String.contains?(message, "save") ->
        "Save"
      String.contains?(message, "cancel") ->
        "Cancel"
      true ->
        nil
    end
  end

  # NEW: Create AI response for CMS actions
  defp create_cms_response_message(component, socket) do
    session = socket.assigns.active_session

    response_content = case component.type do
      :table ->
        "I've created a data table for you! You can see it in the preview panel on the right. The table includes sample data with Name, Email, and Status columns. You can ask me to modify it by adding more columns, changing the styling, or updating the data."

      :button ->
        "I've generated a button component! It's now visible in the preview panel. You can ask me to change the text, color, size, or add click functionality."

      :form ->
        "I've created a contact form with Name, Email, and Message fields. Check it out in the preview panel! You can ask me to add more fields, change the layout, or modify the styling."

      :card ->
        "I've built a card component for you! It's displayed in the preview panel with a title, description, and action button. Let me know if you'd like to customize it further."

      _ ->
        "I've created a #{component.type} component for you! Check the preview panel to see how it looks."
    end

    %{
      id: generate_message_id(),
      content: response_content,
      role: :assistant,
      session_id: session.id,
      user_id: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      model_used: "cms_generator",
      token_count: nil,
      metadata: %{
        component_id: component.id,
        component_type: component.type,
        is_cms_response: true
      },
      is_streaming: false
    }
  end

  defp create_error_response(reason, socket) do
    session = socket.assigns.active_session

    %{
      id: generate_message_id(),
      content: "I encountered an error while creating the component: #{reason}. Could you please try rephrasing your request?",
      role: :assistant,
      session_id: session.id,
      user_id: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      model_used: "cms_generator",
      token_count: nil,
      metadata: %{error: reason, is_cms_response: true},
      is_streaming: false
    }
  end
end
