defmodule PacketflowChatWeb.AIController do
  @moduledoc """
  Controller for AI-powered PacketFlow capabilities.

  Provides endpoints for intent analysis, plan generation, and capability discovery.
  """

  use PacketflowChatWeb, :controller
  require Logger

  @doc """
  Generate an execution plan from natural language intent.

  POST /api/ai/plan
  {
    "intent": "Analyze the conversation in room 123 and create a summary",
    "context": {"user_id": "user_456"}
  }
  """
  def generate_plan(conn, %{"intent" => intent} = params) do
    context = Map.get(params, "context", %{})

    case PacketFlow.AIPlanner.generate_plan(intent, context) do
      {:ok, plan} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          plan: plan,
          generated_at: DateTime.utc_now()
        })

      {:error, reason} ->
        Logger.error("Plan generation failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Failed to generate plan",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Execute a generated plan.

  POST /api/ai/execute
  {
    "plan": {...},
    "payload": {"room_id": "123", "user_id": "456"}
  }
  """
  def execute_plan(conn, %{"plan" => plan, "payload" => payload} = params) do
    context = Map.get(params, "context", %{})

    case PacketFlow.ExecutionEngine.execute_plan(plan, payload, context) do
      %{execution_id: execution_id} = result ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          execution_id: execution_id,
          result: result,
          executed_at: DateTime.utc_now()
        })

      {:error, reason} ->
        Logger.error("Plan execution failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Failed to execute plan",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Execute a single capability directly.

  POST /api/ai/capability/:capability_id
  {
    "payload": {"room_id": "123", "content": "Hello world"},
    "context": {"user_id": "456"}
  }
  """
  def execute_capability(conn, %{"capability_id" => capability_id} = params) do
    payload = Map.get(params, "payload", %{})
    context = Map.get(params, "context", %{})

    capability_atom = String.to_atom(capability_id)

    # For LLM-enabled capabilities, we want to stream the response
    room_id = payload["room_id"] || payload[:room_id]

    # Send initial "thinking" message
    if room_id do
      send_thinking_message_to_room(room_id, capability_id, context)
    end

    case PacketFlow.ExecutionEngine.execute(capability_atom, payload, context) do
      {:ok, result} ->
        # If there's a room_id in the payload, send the result as a chat message
        if room_id do
          send_capability_result_to_room(room_id, capability_id, result, context)
        end

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          capability_id: capability_id,
          result: result,
          executed_at: DateTime.utc_now()
        })

      {:error, reason} ->
        Logger.error("Capability execution failed: #{inspect(reason)}")

        # Send error message to room if available
        if room_id do
          send_error_message_to_room(room_id, capability_id, reason, context)
        end

        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Failed to execute capability",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Discover capabilities based on intent or criteria.

  GET /api/ai/capabilities?intent=analyze conversation
  GET /api/ai/capabilities?requires=room_id&provides=summary
  """
  def discover_capabilities(conn, params) do
    case build_discovery_query(params) do
      {:ok, query} ->
        capabilities = PacketFlow.CapabilityRegistry.discover(query)

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          capabilities: capabilities,
          query: query,
          count: length(capabilities)
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid discovery query",
          details: reason
        })
    end
  end

  @doc """
  List all available capabilities.

  GET /api/ai/capabilities
  """
  def list_capabilities(conn, _params) do
    capabilities = PacketFlow.CapabilityRegistry.list_all()

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      capabilities: capabilities,
      count: length(capabilities)
    })
  end

  @doc """
  Analyze user intent without generating a full plan.

  POST /api/ai/analyze-intent
  {
    "intent": "I want to see what people are talking about in the main room"
  }
  """
  def analyze_intent(conn, %{"intent" => intent}) do
    case PacketFlow.AIPlanner.analyze_intent(intent) do
      {:ok, analysis} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          analysis: analysis,
          analyzed_at: DateTime.utc_now()
        })

      {:error, reason} ->
        Logger.error("Intent analysis failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Failed to analyze intent",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Get execution status for a running plan.

  GET /api/ai/execution/:execution_id
  """
  def get_execution_status(conn, %{"execution_id" => execution_id}) do
    case PacketFlow.ExecutionEngine.get_execution_status(execution_id) do
      {:ok, status} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          execution_id: execution_id,
          status: status
        })

      {:error, :execution_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Execution not found",
          execution_id: execution_id
        })
    end
  end

  @doc """
  Natural language interface - convert text to capability execution.

  POST /api/ai/natural
  {
    "message": "Can you analyze the conversation in room 123 and tell me the main topics?",
    "context": {"user_id": "456", "room_id": "123"}
  }
  """
  def natural_language_interface(conn, %{"message" => message} = params) do
    context = Map.get(params, "context", %{})

    # Handle built-in commands first
    case String.trim(message) do
      "help" ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          message: get_help_message(),
          processed_at: DateTime.utc_now()
        })

      _ ->
        # Extract command type and clean content
        {command_type, clean_message} = extract_command_and_content(message)

        # Add command type to context
        enhanced_context = Map.put(context, :command_type, command_type)

        # Generate plan from natural language
        case PacketFlow.AIPlanner.generate_plan(clean_message, enhanced_context) do
          {:ok, plan} ->
        # Execute the plan automatically
        case PacketFlow.ExecutionEngine.execute_plan(plan, context, context) do
          %{execution_id: execution_id} = result ->
            # Extract the actual message from execution results
            formatted_message = extract_message_from_results(result)

            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              message: formatted_message,
              plan: plan,
              execution_id: execution_id,
              result: result,
              processed_at: DateTime.utc_now()
            })

          {:error, execution_reason} ->
            # Return the plan even if execution failed
            conn
            |> put_status(:partial_content)
            |> json(%{
              success: false,
              message: "I understood your request but couldn't complete the execution.",
              plan: plan,
              execution_error: inspect(execution_reason),
              processed_at: DateTime.utc_now()
            })
        end

      {:error, reason} ->
        Logger.error("Natural language processing failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          message: "I couldn't understand your request. Please try rephrasing it.",
          error: inspect(reason),
          processed_at: DateTime.utc_now()
        })
        end
    end
  end

  # Private helper functions

  defp build_discovery_query(params) do
    cond do
      Map.has_key?(params, "intent") ->
        {:ok, params["intent"]}

      Map.has_key?(params, "requires") or Map.has_key?(params, "provides") ->
        query = %{}
        query = if params["requires"], do: Map.put(query, :requires, String.split(params["requires"], ",")), else: query
        query = if params["provides"], do: Map.put(query, :provides, String.split(params["provides"], ",")), else: query
        {:ok, query}

      true ->
        {:error, "Must provide either 'intent' or 'requires'/'provides' parameters"}
    end
  end

  # Helper functions for streaming messages to chat room

  defp send_thinking_message_to_room(room_id, capability_id, context) do
    try do
      user_id = context["user_id"] || context[:user_id] || "system"

      message_content = "🤖 **AI Assistant**: Analyzing with #{capability_id}..."

      case PacketflowChat.Chat.create_message(%{
        content: message_content,
        message_type: "ai_capability",
        user_id: user_id,
        room_id: room_id
      }) do
        {:ok, message} ->
          PacketflowChatWeb.Endpoint.broadcast!(
            "room:#{room_id}",
            "message_received",
            format_message_for_broadcast(message)
          )
        {:error, changeset} ->
          Logger.error("Failed to create thinking message: #{inspect(changeset)}")
      end
    rescue
      error ->
        Logger.error("Error sending thinking message: #{inspect(error)}")
    end
  end

  defp send_error_message_to_room(room_id, capability_id, reason, context) do
    try do
      user_id = context["user_id"] || context[:user_id] || "system"

      message_content = "🤖 **AI Assistant**: ❌ Error executing #{capability_id}: #{inspect(reason)}"

      case PacketflowChat.Chat.create_message(%{
        content: message_content,
        message_type: "ai_capability",
        user_id: user_id,
        room_id: room_id
      }) do
        {:ok, message} ->
          PacketflowChatWeb.Endpoint.broadcast!(
            "room:#{room_id}",
            "message_received",
            format_message_for_broadcast(message)
          )
        {:error, changeset} ->
          Logger.error("Failed to create error message: #{inspect(changeset)}")
      end
    rescue
      error ->
        Logger.error("Error sending error message: #{inspect(error)}")
    end
  end

  # Helper function to send capability results to chat room
  defp send_capability_result_to_room(room_id, capability_id, result, context) do
    try do
      # Get user_id from context, default to a system user if not available
      user_id = context["user_id"] || context[:user_id] || "system"

      # Format the result as a readable message
      message_content = format_capability_result(capability_id, result)

      # Create the message in the database
      case PacketflowChat.Chat.create_message(%{
        content: message_content,
        message_type: "ai_capability",
        user_id: user_id,
        room_id: room_id
      }) do
        {:ok, message} ->
          # Broadcast the message to all room members via Phoenix Channel
          PacketflowChatWeb.Endpoint.broadcast!(
            "room:#{room_id}",
            "message_received",
            format_message_for_broadcast(message)
          )
          Logger.info("AI capability result sent to room #{room_id}")

        {:error, changeset} ->
          Logger.error("Failed to create AI capability message: #{inspect(changeset)}")
      end
    rescue
      error ->
        Logger.error("Error sending capability result to room: #{inspect(error)}")
    end
  end

  defp format_capability_result(capability_id, result) do
    case capability_id do
      "analyze_conversation" ->
        if is_map(result) do
          # Check if this is an LLM-generated response
          if result[:message] || result["message"] do
            # LLM response - use the natural language message
            message = result[:message] || result["message"]
            "🤖 **AI Assistant - Conversation Analysis**\n\n#{message}"
          else
            # Fallback to structured format for basic analysis
            summary = result[:conversation_summary] || result["conversation_summary"]
            sentiment = result[:sentiment_analysis] || result["sentiment_analysis"]
            topics = result[:key_topics] || result["key_topics"]

            parts = ["🤖 **Conversation Analysis Results**"]

            if summary do
              parts = parts ++ [
                "",
                "📊 **Summary:**",
                "• Total messages: #{summary[:total_messages] || summary["total_messages"] || "N/A"}",
                "• Participants: #{summary[:unique_participants] || summary["unique_participants"] || "N/A"}",
                "• Activity level: #{summary[:activity_level] || summary["activity_level"] || "N/A"}"
              ]
            end

            if sentiment do
              overall_sentiment = sentiment[:overall_sentiment] || sentiment["overall_sentiment"]
              if overall_sentiment do
                sentiment_text = cond do
                  overall_sentiment > 0.6 -> "Positive 😊"
                  overall_sentiment < 0.4 -> "Negative 😔"
                  true -> "Neutral 😐"
                end
                parts = parts ++ ["", "💭 **Overall Sentiment:** #{sentiment_text}"]
              end
            end

            if topics && is_list(topics) && length(topics) > 0 do
              parts = parts ++ ["", "🏷️ **Key Topics:** #{Enum.join(topics, ", ")}"]
            end

            Enum.join(parts, "\n")
          end
        else
          "🤖 **Conversation Analysis Complete**\n\nSomething went wrong with the analysis. Please try again."
        end

      "send_message" ->
        if is_map(result) do
          message_id = result[:message_id] || result["message_id"]
          delivery_status = result[:delivery_status] || result["delivery_status"]
          ai_insights = result[:ai_insights] || result["ai_insights"]

          parts = ["📨 **Message Sent Successfully**"]

          if delivery_status == :delivered || delivery_status == "delivered" do
            parts = parts ++ ["✅ Message delivered to the room"]
          end

          if ai_insights && is_map(ai_insights) do
            sentiment = ai_insights[:sentiment] || ai_insights["sentiment"]
            word_count = ai_insights[:word_count] || ai_insights["word_count"]
            contains_question = ai_insights[:contains_question] || ai_insights["contains_question"]

            insights = []
            if word_count, do: insights = insights ++ ["📝 #{word_count} words"]
            if sentiment do
              sentiment_text = cond do
                sentiment > 0.6 -> "😊 positive"
                sentiment < 0.4 -> "😔 negative"
                true -> "😐 neutral"
              end
              insights = insights ++ ["💭 #{sentiment_text} tone"]
            end
            if contains_question, do: insights = insights ++ ["❓ contains question"]

            if length(insights) > 0 do
              parts = parts ++ ["", "🔍 **Message insights:** #{Enum.join(insights, ", ")}"]
            end
          end

          Enum.join(parts, "\n")
        else
          "📨 **Message sent successfully**"
        end

      "generate_response" ->
        if is_map(result) do
          # Check if this is an LLM-generated response
          if result[:message] || result["message"] do
            # LLM response - use the natural language message directly
            message = result[:message] || result["message"]
            "🤖 **AI Assistant**\n\n#{message}"
          else
            # Fallback to structured suggestions format
            suggested_responses = result[:suggested_responses] || result["suggested_responses"]

            if suggested_responses && is_list(suggested_responses) && length(suggested_responses) > 0 do
              parts = ["💡 **AI Response Suggestions**", ""]

              suggested_responses
              |> Enum.take(3)  # Limit to 3 suggestions
              |> Enum.with_index(1)
              |> Enum.each(fn {response, index} ->
                parts = parts ++ ["#{index}. \"#{response}\""]
              end)

              parts = parts ++ ["", "💬 Choose one of these responses or use them as inspiration!"]
              Enum.join(parts, "\n")
            else
              "💡 **AI Response Generator**\n\nNo suggestions available at the moment."
            end
          end
        else
          "💡 **AI Response Generator Complete**"
        end

      "moderate_content" ->
        if is_map(result) do
          # Check if there's a direct message (for cases like no content provided)
          if result[:message] || result["message"] do
            message = result[:message] || result["message"]
            "🛡️ **Content Moderation Results**\n\n#{message}"
          else
            moderation_result = result[:moderation_result] || result["moderation_result"]
            safety_score = result[:safety_score] || result["safety_score"]

            if moderation_result && is_map(moderation_result) do
              is_safe = moderation_result[:is_safe] || moderation_result["is_safe"]
              categories = moderation_result[:categories_detected] || moderation_result["categories_detected"] || []

              parts = ["🛡️ **Content Moderation Results**", ""]

              parts = if is_safe do
                parts ++ ["✅ Content appears safe"]
              else
                updated_parts = parts ++ ["⚠️ Content flagged for review"]
                if length(categories) > 0 do
                  updated_parts ++ ["📋 Issues detected: #{Enum.join(categories, ", ")}"]
                else
                  updated_parts
                end
              end

              parts = if safety_score do
                score_percentage = round(safety_score * 100)
                parts ++ ["📊 Safety score: #{score_percentage}%"]
              else
                parts
              end

              Enum.join(parts, "\n")
            else
              "🛡️ **Content Moderation Complete**\n\nResult: #{inspect(result)}"
            end
          end
        else
          "🛡️ **Content Moderation Complete**\n\nInvalid result format: #{inspect(result)}"
        end

      "create_room_summary" ->
        if is_map(result) do
          # Check if this is an LLM-generated response
          if result[:message] || result["message"] do
            # LLM response - use the natural language message
            message = result[:message] || result["message"]
            "🤖 **AI Assistant - Room Summary**\n\n#{message}"
          else
            # Fallback to structured format for basic summary
            activity_summary = result[:activity_summary] || result["activity_summary"]
            participant_insights = result[:participant_insights] || result["participant_insights"]
            trending_topics = result[:trending_topics] || result["trending_topics"]

            parts = ["🤖 **Room Summary**"]

            if activity_summary do
              total_messages = activity_summary[:total_messages] || activity_summary["total_messages"]
              active_users = activity_summary[:active_users] || activity_summary["active_users"]
              parts = parts ++ [
                "",
                "📊 **Activity:**",
                "• Messages: #{total_messages || "N/A"}",
                "• Active users: #{active_users || "N/A"}"
              ]
            end

            if participant_insights do
              engagement = participant_insights[:engagement_level] || participant_insights["engagement_level"]
              if engagement do
                parts = parts ++ ["", "👥 **Engagement:** #{engagement}"]
              end
            end

            if trending_topics && is_list(trending_topics) && length(trending_topics) > 0 do
              parts = parts ++ ["", "🔥 **Trending topics:** #{Enum.join(trending_topics, ", ")}"]
            end

            Enum.join(parts, "\n")
          end
        else
          "🤖 **Room Summary Complete**"
        end

      _ ->
        "🤖 **AI Capability Complete**\n\nCapability '#{capability_id}' executed successfully."
    end
  end

  defp format_message_for_broadcast(message) do
    user = PacketflowChat.Accounts.get_user!(message.user_id)

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

  # Helper function to extract message from execution results
  defp extract_message_from_results(result) when is_map(result) do
    # Handle both atom and string keys, similar to room channel
    results = result[:results] || result["results"] || result

        # First try to get the message from any step that has a message field
    step_message = find_message_in_steps(results)

    # Then try top-level message fields
    message = results[:message] || results["message"]
    response = results[:response] || results["response"]
    summary = results[:summary] || results["summary"]
    analysis = results[:analysis] || results["analysis"]

    extracted_message = cond do
      step_message && String.trim(step_message) != "" -> step_message
      message -> message
      response -> response
      summary -> summary
      analysis -> analysis
      true -> "I've analyzed your request and executed the appropriate capabilities."
    end

    # Apply template substitution to the extracted message
    substitute_message_templates(extracted_message, results)
  end

  defp extract_message_from_results(_), do: "I've processed your request."

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
    **Available Commands:**

    • `/help` - Show this help message
    • `ai: [request]` - Natural language processing
    • `analyze: [topic]` - Analyze conversations or data
    • `summarize: [topic]` - Generate summaries

    **Examples:**
    • `ai: summarize this room`
    • `analyze: conversation patterns`
    • `summarize: key topics discussed today`
    """
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

  # Template substitution for message content
  defp substitute_message_templates(message, results) when is_binary(message) do
    message
    |> substitute_curly_brace_templates(results)
    |> substitute_angle_bracket_templates(results)
  end

  defp substitute_message_templates(message, _results), do: message

  # Handle templates like "{main_topics, key_points}" or "{summary}"
  defp substitute_curly_brace_templates(message, results) do
    # Handle comma-separated field lists like "{main_topics, key_points}"
    message = Regex.replace(~r/\{([^}]+)\}/, message, fn _match, field_list ->
      fields = String.split(field_list, ",") |> Enum.map(&String.trim/1)

      values = Enum.map(fields, fn field ->
        find_field_value(results, field)
      end)
      |> Enum.filter(&(&1 != nil && String.trim(&1) != ""))

      case values do
        [] -> "{#{field_list}}"  # Keep original if no values found
        [single_value] -> single_value
        multiple_values -> Enum.join(multiple_values, "\n\n")
      end
    end)

    message
  end

  # Handle templates like "<output from step_1>"
  defp substitute_angle_bracket_templates(message, results) do
    Regex.replace(~r/<output from (step_\w+)>/i, message, fn _match, step_id ->
      case Map.get(results, step_id) do
        nil -> "<output from #{step_id}>"
        step_data when is_map(step_data) ->
          find_primary_content(step_data)
        value when is_binary(value) -> value
        value -> inspect(value)
      end
    end)
  end

  # Find a specific field value in the results
  defp find_field_value(results, field) do
    # Try to find the field in different places
    cond do
      # Direct field access
      Map.has_key?(results, field) -> Map.get(results, field)
      Map.has_key?(results, String.to_atom(field)) -> Map.get(results, String.to_atom(field))

      # Look in step results
      true -> find_field_in_steps(results, field)
    end
  end

  # Find a field in step results
  defp find_field_in_steps(results, field) do
    results
    |> Enum.find_value(fn {key, value} ->
      if is_binary(key) and String.starts_with?(key, "step_") and is_map(value) do
        Map.get(value, field) || Map.get(value, String.to_atom(field))
      else
        nil
      end
    end)
  end

  # Find the primary content from step data
  defp find_primary_content(step_data) when is_map(step_data) do
    cond do
      Map.has_key?(step_data, "summary") -> Map.get(step_data, "summary")
      Map.has_key?(step_data, :summary) -> Map.get(step_data, :summary)
      Map.has_key?(step_data, "message") -> Map.get(step_data, "message")
      Map.has_key?(step_data, :message) -> Map.get(step_data, :message)
      Map.has_key?(step_data, "response") -> Map.get(step_data, "response")
      Map.has_key?(step_data, :response) -> Map.get(step_data, :response)
      Map.has_key?(step_data, "content") -> Map.get(step_data, "content")
      Map.has_key?(step_data, :content) -> Map.get(step_data, :content)
      true -> inspect(step_data)
    end
  end

  defp find_primary_content(value), do: inspect(value)
end
