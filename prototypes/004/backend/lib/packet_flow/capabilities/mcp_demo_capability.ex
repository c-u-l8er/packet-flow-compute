defmodule PacketFlow.Capabilities.MCPDemoCapability do
  @moduledoc """
  Demonstration MCP-enabled actor capability.

  This capability showcases the integration between PacketFlow actors and MCP tools,
  showing how an actor can maintain conversation state while having access to
  external MCP tools for enhanced functionality.

  ## Features

  - Persistent conversation memory
  - MCP tool discovery and execution
  - Intelligent tool selection based on user requests
  - Error handling for tool failures
  - Conversation context integration with tool results

  ## Usage

      # Start the MCP demo actor
      {:ok, actor_pid} = PacketFlow.send_to_actor(:mcp_demo_agent, "user123", %{
        message: "Can you help me search for information about Elixir?",
        context: %{room_id: "demo_room"}
      })

      # The actor will automatically determine if tools are needed and execute them
  """

  use PacketFlow.MCPActorCapability

  mcp_actor_capability :mcp_demo_agent do
    intent "Demonstration AI agent with MCP tool access and conversation memory"
    requires [:message, :user_id]
    provides [:response, :tool_executions, :conversation_state, :insights]

    initial_state %{
      conversation_history: [],
      user_preferences: %{},
      tool_usage_stats: %{},
      context_memory: %{},
      last_tool_results: []
    }

    # MCP tools this actor can access
    mcp_tools [
      :web_search,
      :send_message,
      :analyze_conversation
    ]

    state_persistence :memory
    actor_timeout :timer.minutes(45)

    effect :conversation_log, level: :info
    effect :tool_usage_metrics, type: :counter, name: "mcp_tool_executions"

        # Message handling will be implemented in handle_actor_message_with_mcp function
  end

  @doc """
  Handle actor messages with MCP context - required by MCPActorCapability.
  """
  def handle_actor_message_with_mcp(message, context, state) do
    case message do
      %{type: "chat", message: msg, user_id: user_id} ->
        handle_chat_message(msg, user_id, state)

      %{type: "tool_request", tool: tool_name, params: params, user_id: user_id} ->
        handle_explicit_tool_request(tool_name, params, user_id, state)

      %{type: "conversation_summary", user_id: user_id} ->
        generate_conversation_summary(user_id, state)

      # Handle generic messages
      %{message: msg, user_id: user_id} ->
        handle_chat_message(msg, user_id, state)

      _ ->
        {:ok, %{error: "Unsupported message format"}, state}
    end
  end

  @doc """
  Handle chat messages with intelligent tool usage.
  """
  def handle_chat_message(message, user_id, state) do
    # Add message to conversation history
    conversation_entry = %{
      message: message,
      user_id: user_id,
      timestamp: DateTime.utc_now(),
      type: "user_message"
    }

    updated_history = [conversation_entry | state.conversation_history]
    updated_state = %{state | conversation_history: updated_history}

    # Analyze if the message requires tool usage
    case analyze_message_for_tools(message, updated_state) do
      {:needs_tools, tool_requests} ->
        execute_tools_and_respond(tool_requests, message, user_id, updated_state)

      {:no_tools_needed, response_type} ->
        generate_direct_response(message, user_id, response_type, updated_state)
    end
  end

  @doc """
  Handle explicit tool requests from users.
  """
  def handle_explicit_tool_request(tool_name, params, user_id, state) do
    case execute_single_tool(tool_name, params, user_id, state) do
      {:ok, tool_result, updated_state} ->
        response = %{
          type: "tool_execution_result",
          tool_name: tool_name,
          result: tool_result,
          user_id: user_id,
          timestamp: DateTime.utc_now()
        }

        final_state = update_tool_usage_stats(updated_state, tool_name, :success)
        {:ok, response, final_state}

      {:error, reason} ->
        error_response = %{
          type: "tool_execution_error",
          tool_name: tool_name,
          error: reason,
          user_id: user_id,
          timestamp: DateTime.utc_now()
        }

        final_state = update_tool_usage_stats(state, tool_name, :error)
        {:ok, error_response, final_state}
    end
  end

  @doc """
  Generate a conversation summary for the user.
  """
  def generate_conversation_summary(user_id, state) do
    user_messages = Enum.filter(state.conversation_history, fn entry ->
      entry.user_id == user_id
    end)

    summary = %{
      user_id: user_id,
      total_messages: length(user_messages),
      conversation_span: calculate_conversation_span(user_messages),
      tools_used: extract_tools_used(state.tool_usage_stats),
      key_topics: extract_key_topics(user_messages),
      last_activity: get_last_activity(user_messages)
    }

    response = %{
      type: "conversation_summary",
      summary: summary,
      timestamp: DateTime.utc_now()
    }

    {:ok, response, state}
  end

  # Private helper functions

  defp analyze_message_for_tools(message, state) do
    message_lower = String.downcase(message)

    cond do
      # Check for search-related keywords
      Regex.match?(~r/search|find|look up|what is|tell me about/, message_lower) ->
        {:needs_tools, [%{tool: :web_search, query: extract_search_query(message)}]}

      # Check for message sending requests
      Regex.match?(~r/send|message|tell|notify/, message_lower) ->
        {:needs_tools, [%{tool: :send_message, content: message}]}

      # Check for analysis requests
      Regex.match?(~r/analyze|summary|insights|patterns/, message_lower) ->
        {:needs_tools, [%{tool: :analyze_conversation, context: state.conversation_history}]}

      # Default to direct response
      true ->
        {:no_tools_needed, :conversational}
    end
  end

  defp execute_tools_and_respond(tool_requests, original_message, user_id, state) do
    # Execute all requested tools
    {tool_results, updated_state} = Enum.reduce(tool_requests, {[], state}, fn tool_request, {results, current_state} ->
      case execute_single_tool(tool_request.tool, Map.drop(tool_request, [:tool]), user_id, current_state) do
        {:ok, result, new_state} ->
          {[{tool_request.tool, result} | results], new_state}

        {:error, reason} ->
          {[{tool_request.tool, {:error, reason}} | results], current_state}
      end
    end)

    # Generate response based on tool results
    response = generate_tool_enhanced_response(original_message, tool_results, user_id, updated_state)

    # Add response to conversation history
    response_entry = %{
      message: response.content,
      user_id: "system",
      timestamp: DateTime.utc_now(),
      type: "agent_response",
      tool_executions: tool_results
    }

    final_history = [response_entry | updated_state.conversation_history]
    final_state = %{updated_state |
      conversation_history: final_history,
      last_tool_results: tool_results
    }

    {:ok, response, final_state}
  end

  defp execute_single_tool(tool_name, params, user_id, state) do
    # Create MCP tool call message
    mcp_message = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => "tools/call",
      "params" => %{
        "name" => Atom.to_string(tool_name),
        "arguments" => prepare_tool_arguments(tool_name, params, user_id, state)
      }
    }

    context = %{
      user_id: user_id,
      actor_id: "mcp_demo_agent",
      timestamp: DateTime.utc_now()
    }

    case PacketFlow.MCPBridge.handle_mcp_request(mcp_message, context) do
      {:ok, mcp_response} ->
        # Process and store the tool result
        processed_result = process_tool_result(tool_name, mcp_response)
        updated_state = record_tool_execution(state, tool_name, params, processed_result, :success)
        {:ok, processed_result, updated_state}

      {:error, reason} ->
        updated_state = record_tool_execution(state, tool_name, params, nil, :error)
        {:error, reason}
    end
  end

  defp prepare_tool_arguments(tool_name, params, user_id, state) do
    base_args = Map.merge(params, %{
      "user_id" => user_id,
      "context" => %{
        "conversation_history_count" => length(state.conversation_history),
        "last_tools_used" => Map.keys(state.tool_usage_stats)
      }
    })

    case tool_name do
      :web_search ->
        Map.put(base_args, "max_results", 5)

      :send_message ->
        Map.merge(base_args, %{
          "room_id" => get_user_room(user_id, state),
          "message_type" => "agent_response"
        })

      :analyze_conversation ->
        Map.put(base_args, "analysis_depth", "detailed")

      _ ->
        base_args
    end
  end

  defp generate_direct_response(message, user_id, response_type, state) do
    response_content = case response_type do
      :conversational ->
        generate_conversational_response(message, user_id, state)

      :informational ->
        generate_informational_response(message, user_id, state)

      _ ->
        "I understand your message. How can I help you further?"
    end

    response = %{
      type: "direct_response",
      content: response_content,
      user_id: user_id,
      timestamp: DateTime.utc_now(),
      conversation_context: %{
        previous_messages: length(state.conversation_history),
        user_preferences: Map.get(state.user_preferences, user_id, %{})
      }
    }

    # Add to conversation history
    response_entry = %{
      message: response_content,
      user_id: "system",
      timestamp: DateTime.utc_now(),
      type: "agent_response"
    }

    updated_history = [response_entry | state.conversation_history]
    updated_state = %{state | conversation_history: updated_history}

    {:ok, response, updated_state}
  end

  defp generate_tool_enhanced_response(original_message, tool_results, user_id, state) do
    successful_results = Enum.filter(tool_results, fn {_, result} ->
      not match?({:error, _}, result)
    end)

    response_content = if length(successful_results) > 0 do
      "Based on your request '#{original_message}', I've executed #{length(successful_results)} tool(s) and found: " <>
      format_tool_results(successful_results)
    else
      "I tried to help with your request '#{original_message}', but encountered some issues with the tools. Let me try a different approach."
    end

    %{
      type: "tool_enhanced_response",
      content: response_content,
      user_id: user_id,
      timestamp: DateTime.utc_now(),
      tool_executions: tool_results,
      success_count: length(successful_results)
    }
  end

  # Additional helper functions for demonstration

  defp extract_search_query(message) do
    # Simple extraction - in a real implementation, this would be more sophisticated
    message
    |> String.replace(~r/search for|find|look up|what is|tell me about/i, "")
    |> String.trim()
  end

  defp process_tool_result(tool_name, mcp_response) do
    case mcp_response do
      %{"result" => %{"content" => content}} when is_list(content) ->
        Enum.map(content, fn item ->
          Map.get(item, "text", inspect(item))
        end)
        |> Enum.join("\n")

      %{"result" => result} ->
        inspect(result, pretty: true)

      _ ->
        "Tool executed successfully"
    end
  end

  defp record_tool_execution(state, tool_name, params, result, status) do
    execution_record = %{
      tool_name: tool_name,
      params: params,
      result: result,
      status: status,
      timestamp: DateTime.utc_now()
    }

    # Update tool usage stats
    current_stats = Map.get(state.tool_usage_stats, tool_name, %{success: 0, error: 0, total: 0})
    updated_stats = %{
      success: current_stats.success + if(status == :success, do: 1, else: 0),
      error: current_stats.error + if(status == :error, do: 1, else: 0),
      total: current_stats.total + 1,
      last_used: DateTime.utc_now()
    }

    %{state |
      tool_usage_stats: Map.put(state.tool_usage_stats, tool_name, updated_stats)
    }
  end

  defp update_tool_usage_stats(state, tool_name, status) do
    record_tool_execution(state, tool_name, %{}, nil, status)
  end

  defp generate_conversational_response(message, user_id, state) do
    user_history_count = Enum.count(state.conversation_history, fn entry ->
      entry.user_id == user_id
    end)

    if user_history_count > 0 do
      "I see you've mentioned '#{message}'. Based on our previous #{user_history_count} interactions, I'm here to help. What would you like to explore together?"
    else
      "Hello! I'm your MCP-enabled AI assistant. I can help you with searches, analysis, and more. What can I do for you today?"
    end
  end

  defp generate_informational_response(message, _user_id, _state) do
    "I've received your message: '#{message}'. I'm an AI agent with access to various tools that can help with research, analysis, and communication tasks."
  end

  defp format_tool_results(tool_results) do
    Enum.map(tool_results, fn {tool_name, result} ->
      "#{tool_name}: #{inspect(result, limit: 100)}"
    end)
    |> Enum.join("; ")
  end

  defp get_user_room(user_id, state) do
    # Extract room from conversation context or use default
    case get_in(state, [:context_memory, user_id, :room_id]) do
      nil -> "general"
      room_id -> room_id
    end
  end

  defp calculate_conversation_span(messages) do
    if length(messages) < 2 do
      0
    else
      oldest = List.last(messages)
      newest = List.first(messages)
      DateTime.diff(newest.timestamp, oldest.timestamp, :second)
    end
  end

  defp extract_tools_used(tool_stats) do
    Enum.map(tool_stats, fn {tool_name, stats} ->
      %{
        tool: tool_name,
        usage_count: stats.total,
        success_rate: if(stats.total > 0, do: stats.success / stats.total * 100, else: 0)
      }
    end)
  end

  defp extract_key_topics(messages) do
    # Simple keyword extraction - in a real implementation, this would use NLP
    messages
    |> Enum.map(& &1.message)
    |> Enum.join(" ")
    |> String.downcase()
    |> String.split()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {word, _} -> word end)
  end

  defp get_last_activity(messages) do
    case List.first(messages) do
      nil -> nil
      message -> message.timestamp
    end
  end
end
