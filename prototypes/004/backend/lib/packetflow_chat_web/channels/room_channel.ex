defmodule PacketflowChatWeb.RoomChannel do
  use Phoenix.Channel

  alias PacketflowChat.Chat
  alias PacketflowChat.Accounts

  @impl true
  def join("room:" <> room_identifier, _payload, socket) do
    user_id = socket.assigns.user_id

    case Chat.get_room(room_identifier) do
      nil ->
        {:error, %{reason: "room_not_found"}}

      room ->
        case Chat.user_in_room?(room.id, user_id) do
          true ->
            send(self(), :after_join)
            {:ok, assign(socket, :room_id, room.id)}

          false ->
            # For public rooms, automatically add the user as a member
            if not room.is_private do
              case Chat.add_room_member(room.id, user_id) do
                {:ok, _room_member} ->
                  send(self(), :after_join)
                  {:ok, assign(socket, :room_id, room.id)}

                {:error, _changeset} ->
                  {:error, %{reason: "failed_to_join"}}
              end
            else
              {:error, %{reason: "unauthorized"}}
            end
        end
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    # Load recent messages
    messages =
      Chat.list_room_messages(room_id, 20)
      |> Enum.map(&format_message/1)

    # Load room members
    members = Chat.list_room_members_with_users(room_id)

    # Get user info for the joining user
    user = Accounts.get_user!(user_id)

    # Notify others that user joined
    broadcast!(socket, "user_joined", %{
      user: %{
        id: user.id,
        username: user.username,
        avatar_url: user.avatar_url
      },
      timestamp: DateTime.utc_now()
    })

    # Send recent messages and member list to the joining user
    push(socket, "messages_loaded", %{messages: messages})
    push(socket, "members_updated", %{members: members})

    {:noreply, socket}
  end

  @impl true
  def handle_in("send_message", %{"content" => content, "message_type" => message_type}, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    # Handle all messages as regular messages now
    # AI commands are handled by the frontend -> AI controller flow
    case Chat.create_message(%{
           content: content,
           message_type: message_type || "text",
           user_id: user_id,
           room_id: room_id
         }) do
      {:ok, message} ->
        # Broadcast the message to all room members
        broadcast!(socket, "message_received", format_message(message))
        {:reply, {:ok, %{message_id: message.id}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end



  # UNUSED: AI commands are now handled by frontend -> AI controller flow
  # defp handle_ai_command(content, message_type, socket) do
  #   user_id = socket.assigns.user_id
  #   room_id = socket.assigns.room_id
  #
  #   # First, save the user's command as a message
  #   case Chat.create_message(%{
  #          content: content,
  #          message_type: message_type || "ai_command",
  #          user_id: user_id,
  #          room_id: room_id
  #        }) do
  #     {:ok, message} ->
  #       # Broadcast the user's command
  #       broadcast!(socket, "message_received", format_message(message))
  #
  #       # Process the AI command asynchronously
  #       Task.start(fn -> process_ai_command_async(content, user_id, room_id, socket) end)
  #
  #       {:reply, {:ok, %{message_id: message.id}}, socket}
  #
  #     {:error, changeset} ->
  #       {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
  #   end
  # end

  defp process_ai_command_async(content, user_id, room_id, socket) do
    try do
      # Create AI processing message
      {:ok, processing_message} = Chat.create_message(%{
        content: "🤖 **AI Assistant**: Processing your request...",
        message_type: "ai_response",
        user_id: user_id,
        room_id: room_id
      })

      # Broadcast processing message
      broadcast!(socket, "message_received", format_message(processing_message))

      # Process the command
      result = if String.starts_with?(String.trim(content), "/") do
        process_capability_command(content, user_id, room_id)
      else
        process_natural_language_request(content, user_id, room_id)
      end

      # Create and broadcast AI response
      response_content = case result do
        {:ok, response} -> "🤖 **AI Assistant**: #{response}"
        {:error, error} -> "🤖 **AI Assistant**: ❌ #{error}"
      end

      {:ok, response_message} = Chat.create_message(%{
        content: response_content,
        message_type: "ai_response",
        user_id: user_id,
        room_id: room_id
      })

      broadcast!(socket, "message_received", format_message(response_message))

    rescue
      error ->
        # Create error message
        {:ok, error_message} = Chat.create_message(%{
          content: "🤖 **AI Assistant**: ❌ Sorry, I encountered an error processing your request.",
          message_type: "ai_response",
          user_id: user_id,
          room_id: room_id
        })

        broadcast!(socket, "message_received", format_message(error_message))

        require Logger
        Logger.error("AI command processing error: #{inspect(error)}")
    end
  end

  defp process_capability_command(content, user_id, room_id) do
    # Remove '/' and split command
    command_parts = content |> String.trim() |> String.slice(1..-1) |> String.split(" ", parts: 2)
    capability_id = List.first(command_parts)
    args = if length(command_parts) > 1, do: List.last(command_parts), else: ""

        # Handle built-in commands first
    case capability_id do
      "help" ->
        {:ok, get_help_message()}

      _ ->
        # Try to execute as a PacketFlow capability
        payload = %{
          room_id: room_id,
          user_id: user_id,
          content: String.trim(args)
        }

        context = %{user_id: user_id}

        # Convert string capability_id to atom for registry lookup
        try do
          capability_atom = String.to_existing_atom(capability_id)
          case PacketFlow.execute_capability(capability_atom, payload, context) do
            {:ok, result} -> {:ok, format_capability_result(result)}
            {:error, reason} -> {:error, "Failed to execute '#{capability_id}': #{inspect(reason)}"}
          end
        rescue
          ArgumentError ->
            {:error, "Unknown capability '#{capability_id}'. Type '/help' to see available capabilities."}
        end
    end
  end

    defp process_natural_language_request(content, user_id, room_id) do
    # Extract command type and clean content
    {command_type, clean_content} = extract_command_and_content(content)

    # Use PacketFlow's AI planner directly
    context = %{
      user_id: user_id,
      room_id: room_id,
      timestamp: DateTime.utc_now(),
      command_type: command_type
    }

    case PacketFlow.AIPlanner.generate_plan(clean_content, context) do
      {:ok, plan} ->
        # Execute the plan automatically
        case PacketFlow.ExecutionEngine.execute_plan(plan, context, context) do
          %{execution_id: _execution_id, results: results} = _result ->
            # Format the results for chat display
            formatted_result = format_execution_results(results)
            {:ok, formatted_result}

          error ->
            {:error, "Failed to execute AI plan: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Sorry, I couldn't understand your request: #{inspect(reason)}"}
    end
  end

  defp extract_command_and_content(content) do
    cond do
      Regex.match?(~r/^analyze:\s*/i, content) ->
        {:analyze, Regex.replace(~r/^analyze:\s*/i, content, "")}

      Regex.match?(~r/^summarize:\s*/i, content) ->
        {:summarize, Regex.replace(~r/^summarize:\s*/i, content, "")}

      Regex.match?(~r/^ai:\s*/i, content) ->
        {:ai, Regex.replace(~r/^ai:\s*/i, content, "")}

      Regex.match?(~r/^ask:\s*/i, content) ->
        {:ask, Regex.replace(~r/^ask:\s*/i, content, "")}

      Regex.match?(~r/^(@ai|@assistant)\s*/i, content) ->
        {:ai, Regex.replace(~r/^(@ai|@assistant)\s*/i, content, "")}

      true ->
        {:general, content}
    end
  end

  defp format_execution_results(results) when is_map(results) do
    # Extract meaningful results from the execution
    # Handle both atom and string keys

        # First try to get the message from any step that has a message field
    step_message = find_message_in_steps(results)

    # Then try top-level message fields
    message = results[:message] || results["message"]
    response = results[:response] || results["response"]
    summary = results[:summary] || results["summary"]
    analysis = results[:analysis] || results["analysis"]

    cond do
      step_message && String.trim(step_message) != "" -> step_message
      message -> message
      response -> response
      summary -> summary
      analysis -> analysis
      true -> "I've processed your request. Here are the results: #{inspect(results)}"
    end
  end

  defp format_execution_results(results) when is_list(results) do
    # If we have multiple results, combine them
    results
    |> Enum.map(&format_execution_results/1)
    |> Enum.join("\n\n")
  end

  defp format_execution_results(result) do
    inspect(result)
  end

        # Helper function to find message in any step
  defp find_message_in_steps(results) when is_map(results) do
    # Look through all keys to find step data with messages
    results
    |> Enum.find_value(fn {key, value} ->
      # Only process map values that could contain step data
      if is_map(value) and not is_struct(value) do
        # Skip known system fields
        case key do
          k when k in [:message, "message", :response, "response", :summary, "summary",
                       :analysis, "analysis", :generated_at, "generated_at", :source, "source",
                       :timestamp, "timestamp", :ai_insights, "ai_insights", :delivery_status, "delivery_status"] ->
            nil

          _ ->
            # Try to extract message from this step
            case Map.get(value, :message) || Map.get(value, "message") do
              msg when is_binary(msg) and msg != "" ->
                String.trim(msg)
              _ ->
                nil
            end
        end
      else
        nil
      end
    end)
  end

  defp find_message_in_steps(_), do: nil

    defp get_help_message do
    """
    **Available AI Commands:**

    **Capability Commands:**
    • `/help` - Show this help message
    • `/analyze_conversation` - Analyze conversation patterns and extract insights
    • `/create_room_summary` - Create an intelligent summary of chat room activity
    • `/generate_response` - Generate AI-powered response suggestions
    • `/moderate_content` - Analyze message content for moderation and safety

    **Natural Language:**
    • `ai: your question` - Ask me anything about the chat
    • `ask: your question` - Alternative format
    • `@ai your question` - Mention format

    **Examples:**
    • `/analyze_conversation` - Analyze recent conversation patterns
    • `ai: summarize this room` - Natural language analysis
    • `ask: what are the main topics discussed?` - Question format
    • `@ai who has been most active in this chat?` - Mention format

    **Usage Tips:**
    • Most capabilities work automatically with reasonable defaults
    • Natural language commands are processed by AI and may use multiple capabilities
    • Commands are processed asynchronously - responses will appear shortly
    """
  end

  defp format_capability_result(result) do
    case result do
      %{"message" => message} -> message
      %{"response" => response} -> response
      %{"result" => result_data} -> inspect(result_data)
      _ -> inspect(result)
    end
  end

  defp format_ai_result(result) do
    case result do
      %{"message" => message} -> message
      %{"response" => response} -> response
      _ -> inspect(result)
    end
  end

  @impl true
  def handle_in("typing_start", _payload, socket) do
    user_id = socket.assigns.user_id

    broadcast_from!(socket, "typing_indicator", %{
      user_id: user_id,
      typing: true
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    user_id = socket.assigns.user_id

    broadcast_from!(socket, "typing_indicator", %{
      user_id: user_id,
      typing: false
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]
    room_id = socket.assigns[:room_id]

    # Only broadcast if the socket successfully joined (has room_id assigned)
    if user_id && room_id do
      user = Accounts.get_user!(user_id)

      broadcast!(socket, "user_left", %{
        user: %{
          id: user.id,
          username: user.username,
          avatar_url: user.avatar_url
        },
        timestamp: DateTime.utc_now()
      })
    end

    :ok
  end

  defp format_message(message) do
    user = Accounts.get_user!(message.user_id)

    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user: %{
        id: user.id,
        username: user.username,
        avatar_url: user.avatar_url
      },
      created_at: message.created_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
