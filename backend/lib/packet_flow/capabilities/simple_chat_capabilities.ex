defmodule PacketFlow.Capabilities.SimpleChatCapabilities do
  @moduledoc """
  Simple chat capabilities without complex macros - temporary solution for Phase 2.
  """

  use PacketFlow.SimpleCapability
  require Logger

  def __capabilities__ do
    [
      %{
        id: :send_message,
        intent: "Send a message to a chat room with optional AI processing",
        requires: [:room_id, :content, :user_id],
        provides: [:message_id, :delivery_status, :ai_insights],
        effects: []
      },
      %{
        id: :analyze_conversation,
        intent: "Analyze conversation patterns and extract insights",
        requires: [:room_id, :message_count],
        provides: [:conversation_summary, :sentiment_analysis, :key_topics],
        effects: []
      },
      %{
        id: :generate_response,
        intent: "Generate AI-powered response suggestions for chat messages",
        requires: [:message_content, :conversation_context],
        provides: [:suggested_responses, :confidence_scores],
        effects: []
      },
      %{
        id: :moderate_content,
        intent: "Analyze message content for moderation and safety",
        requires: [:content, :user_id],
        provides: [:moderation_result, :safety_score, :action_required],
        effects: []
      },
      %{
        id: :create_room_summary,
        intent: "Create an intelligent summary of chat room activity",
        requires: [:room_id, :time_period],
        provides: [:activity_summary, :participant_insights, :trending_topics],
        effects: []
      }
    ]
  end

  def list_capabilities do
    __capabilities__()
  end

  # Capability implementations

  def send_message(payload, context) do
    try do
      # Handle both string and atom keys
      message_params = %{
        room_id: payload["room_id"] || payload[:room_id],
        content: payload["content"] || payload[:content],
        user_id: payload["user_id"] || payload[:user_id]
      }

      case PacketflowChat.Chat.create_message(message_params) do
        {:ok, message} ->
          content = payload["content"] || payload[:content]
          ai_insights = generate_message_insights(content, context)

          {:ok, %{
            message_id: message.id,
            delivery_status: :delivered,
            ai_insights: ai_insights
          }}

        {:error, reason} ->
          {:error, {:message_creation_failed, reason}}
      end
    rescue
      error ->
        Logger.error("send_message capability failed: #{inspect(error)}")
        {:error, {:execution_error, error}}
    end
  end

  def analyze_conversation(payload, context) do
    try do
      # Handle both string and atom keys
      room_id = payload["room_id"] || payload[:room_id]
      message_count = payload["message_count"] || payload[:message_count] || 50

      messages = PacketflowChat.Chat.list_room_messages(room_id, message_count)
      Logger.info("analyze_conversation: Found #{length(messages)} messages for room #{room_id}")

            # Use LLM for intelligent conversation analysis
      case analyze_conversation_with_llm(messages, context) do
        {:ok, llm_analysis} ->
          {:ok, llm_analysis}

        {:error, :no_api_keys_configured} ->
          # Provide helpful message when no API keys are configured
          {:ok, %{
            message: "💡 **AI Analysis Available with API Key**\n\nTo get intelligent conversation analysis, please set up an API key:\n\n• Set `ANTHROPIC_API_KEY` environment variable for Claude\n• Or set `OPENAI_API_KEY` environment variable for GPT-4\n\nFor now, here's a basic analysis of your conversation:",
            analysis: analyze_messages(messages, context),
            source: "basic_with_setup_info"
          }}

        {:error, llm_error} ->
          # Fallback to basic analysis if LLM fails
          Logger.warn("LLM analysis failed: #{inspect(llm_error)}, falling back to basic analysis")
          basic_analysis = analyze_messages(messages, context)

          # Format the basic analysis into a readable message
          summary = basic_analysis.conversation_summary
          sentiment = basic_analysis.sentiment_analysis
          topics = basic_analysis.key_topics

          message_parts = [
            "🤖 **Basic Conversation Analysis** (LLM unavailable)",
            "",
            "📊 **Summary:**",
            "• Total messages: #{summary.total_messages}",
            "• Participants: #{summary.unique_participants}",
            "• Activity level: #{summary.activity_level}",
            "• Time span: #{summary.time_span} minutes"
          ]

          if sentiment.overall_sentiment do
            sentiment_text = cond do
              sentiment.overall_sentiment > 0.6 -> "Positive 😊"
              sentiment.overall_sentiment < 0.4 -> "Negative 😔"
              true -> "Neutral 😐"
            end
            message_parts = message_parts ++ ["", "💭 **Overall Sentiment:** #{sentiment_text}"]
          end

          if topics && length(topics) > 0 do
            message_parts = message_parts ++ ["", "🏷️ **Key Topics:** #{Enum.join(topics, ", ")}"]
          end

          {:ok, %{
            message: Enum.join(message_parts, "\n"),
            analysis: basic_analysis,
            source: "basic_analysis"
          }}
      end
    rescue
      error ->
        Logger.error("analyze_conversation capability failed: #{inspect(error)}")
        {:error, {:analysis_failed, error}}
    end
  end

  def generate_response(payload, context) do
    try do
      # Handle both string and atom keys
      message_content = payload["message_content"] || payload[:message_content]
      conversation_context = payload["conversation_context"] || payload[:conversation_context]

      # Get room context if available
      room_id = if is_map(conversation_context) do
        conversation_context["room_id"] || conversation_context[:room_id]
      else
        payload["room_id"] || payload[:room_id]
      end

      # If no message_content provided, use recent conversation for context
      effective_message_content = if message_content && String.trim(message_content) != "" do
        message_content
      else
        # Get the most recent message from the conversation as the message to respond to
        if room_id do
          recent_messages = PacketflowChat.Chat.list_room_messages(room_id, 5)
          if length(recent_messages) > 0 do
            # Find the most recent non-AI message to respond to
            user_messages = Enum.filter(recent_messages, fn msg ->
              msg.message_type != "ai_capability"
            end)

            if length(user_messages) > 0 do
              latest_user_message = List.first(user_messages)
              latest_user_message.content
            else
              # If only AI messages, use the conversation context
              "Please continue our conversation."
            end
          else
            "Hello! How can I help you today?"
          end
        else
          "Hello! How can I help you today?"
        end
      end

            # Use LLM for intelligent response generation
      case generate_response_with_llm(effective_message_content, room_id, context) do
        {:ok, llm_response} ->
          {:ok, %{
            message: llm_response,
            source: "llm_generated",
            generated_at: DateTime.utc_now()
          }}

        {:error, :no_api_keys_configured} ->
          # Provide helpful message when no API keys are configured
          {:ok, %{
            message: "💡 **Smart AI Responses Available with API Key**\n\nTo get intelligent, context-aware responses, please set up an API key:\n\n• Set `ANTHROPIC_API_KEY` environment variable for Claude\n• Or set `OPENAI_API_KEY` environment variable for GPT-4\n\nFor now, here are some basic response suggestions:",
            suggested_responses: generate_ai_responses(effective_message_content, conversation_context, context)[:suggested_responses] || [],
            source: "basic_with_setup_info"
          }}

        {:error, llm_error} ->
          # Fallback to basic responses if LLM fails
          error_message = case llm_error do
            {:http_error, %HTTPoison.Error{reason: :timeout}} ->
              "LLM API request timed out after 30 seconds"
            {:http_error, %HTTPoison.Error{reason: reason}} ->
              "LLM API connection error: #{inspect(reason)}"
            {:api_error, status_code, body} ->
              "LLM API returned error #{status_code}: #{inspect(body)}"
            other ->
              "LLM error: #{inspect(other)}"
          end

          Logger.warn("LLM response generation failed: #{error_message}, falling back to basic responses")
          suggestions = generate_ai_responses(effective_message_content, conversation_context, context)

          # Format the suggestions into a readable message
          suggested_responses = suggestions[:suggested_responses] || []

          if length(suggested_responses) > 0 do
            message_parts = [
              "🤖 **Basic Response Suggestions** (LLM unavailable)",
              "",
              "Responding to: \"#{String.slice(effective_message_content, 0, 100)}#{if String.length(effective_message_content) > 100, do: "...", else: ""}\"",
              ""
            ]

            suggested_responses
            |> Enum.with_index(1)
            |> Enum.each(fn {response, index} ->
              message_parts = message_parts ++ ["#{index}. #{response}"]
            end)

            {:ok, %{
              message: Enum.join(message_parts, "\n"),
              suggested_responses: suggested_responses,
              source: "basic_suggestions"
            }}
          else
            {:ok, %{
              message: "🤖 **AI Assistant**\n\nI understand you're looking for a response to: \"#{effective_message_content}\"\n\nI'd be happy to help, but I need more context to provide a meaningful response. Could you tell me more about what you're trying to discuss?",
              source: "basic_fallback"
            }}
          end
      end
    rescue
      error ->
        Logger.error("generate_response capability failed: #{inspect(error)}")
        {:error, {:response_generation_failed, error}}
    end
  end

  def moderate_content(payload, context) do
    try do
      # Handle both string and atom keys
      content = payload["content"] || payload[:content]

      Logger.info("moderate_content: Analyzing content: #{inspect(content)}")
      Logger.info("moderate_content: Full payload: #{inspect(payload)}")

      # If no content provided, return an error
      if !content || String.trim(content) == "" do
        Logger.warn("moderate_content: No content provided for moderation")
        {:ok, %{
          moderation_result: %{
            is_safe: true,
            categories_detected: [],
            confidence: 1.0
          },
          safety_score: 1.0,
          action_required: :none,
          message: "No content provided for moderation"
        }}
      else
        moderation_result = analyze_content_safety(content, context)
        Logger.info("moderate_content: Analysis result: #{inspect(moderation_result)}")
        {:ok, moderation_result}
      end
    rescue
      error ->
        Logger.error("moderate_content capability failed: #{inspect(error)}")
        {:error, {:moderation_failed, error}}
    end
  end

  def create_room_summary(payload, context) do
    try do
      # Handle both string and atom keys
      room_id = payload["room_id"] || payload[:room_id]
      time_period = payload["time_period"] || payload[:time_period] || "1d"

      room_data = get_room_activity_data(room_id, time_period)
      Logger.info("create_room_summary: Got room data for #{room_id}, error: #{inspect(Map.get(room_data, :error))}")
      summary = generate_room_summary(room_data, context)
      Logger.info("create_room_summary: Generated summary: #{inspect(summary)}")

      # If summary has error, return it
      if Map.has_key?(summary, :error) do
        {:ok, %{
          message: "❌ **Room Summary Error**\n\nCould not generate summary: #{summary.error}",
          error: summary.error
        }}
      else
        # Format the summary into a readable message
        activity = summary.activity_summary
        insights = summary.participant_insights
        topics = summary.trending_topics

        message_parts = [
          "🤖 **Room Summary**",
          "",
          "📊 **Activity:**",
          "• Total messages: #{activity.total_messages}",
          "• Active users: #{activity.active_users}",
          "• Message frequency: #{Float.round(activity.message_frequency, 2)} messages/minute"
        ]

        if activity.busiest_hour && activity.busiest_hour > 0 do
          message_parts = message_parts ++ ["• Busiest hour: #{activity.busiest_hour}:00"]
        end

        if insights.engagement_level do
          message_parts = message_parts ++ ["", "👥 **Engagement:** #{insights.engagement_level}"]
        end

        if insights.most_active_user do
          user_id_short = String.slice(to_string(insights.most_active_user), 0, 8)
          message_parts = message_parts ++ ["• Most active: User#{user_id_short}"]
        end

        if topics && length(topics) > 0 do
          message_parts = message_parts ++ ["", "🔥 **Trending topics:** #{Enum.join(topics, ", ")}"]
        end

        {:ok, %{
          message: Enum.join(message_parts, "\n"),
          summary: summary,
          source: "basic_summary"
        }}
      end
    rescue
      error ->
        Logger.error("create_room_summary capability failed: #{inspect(error)}")
        {:error, {:summary_generation_failed, error}}
    end
  end

  # Helper functions

  defp generate_message_insights(content, _context) do
    word_count = String.split(content) |> length()

    %{
      word_count: word_count,
      estimated_reading_time: max(1, div(word_count, 200)),
      contains_question: String.contains?(content, "?"),
      sentiment: analyze_basic_sentiment(content),
      language: "en"
    }
  end

  defp analyze_messages(messages, _context) do
    total_messages = length(messages)
    unique_users = messages |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()

    all_content = messages |> Enum.map(& &1.content) |> Enum.join(" ")
    key_topics = extract_keywords(all_content)

    sentiment_scores = messages |> Enum.map(&analyze_basic_sentiment(&1.content))
    avg_sentiment = if length(sentiment_scores) > 0 do
      Enum.sum(sentiment_scores) / length(sentiment_scores)
    else
      0.5
    end

    %{
      conversation_summary: %{
        total_messages: total_messages,
        unique_participants: unique_users,
        time_span: calculate_time_span(messages),
        activity_level: categorize_activity_level(total_messages)
      },
      sentiment_analysis: %{
        overall_sentiment: avg_sentiment,
        sentiment_distribution: calculate_sentiment_distribution(sentiment_scores)
      },
      key_topics: key_topics
    }
  end

  defp generate_ai_responses(message_content, _conversation_context, _context) do
    responses = case analyze_message_type(message_content) do
      :question ->
        ["That's a great question! Let me think about that.",
         "I'd be happy to help with that.",
         "Interesting point - here's what I think..."]

      :greeting ->
        ["Hello! How are you doing today?",
         "Hi there! Great to see you.",
         "Hey! What's new?"]

      :statement ->
        ["That's really interesting!",
         "I see what you mean.",
         "Thanks for sharing that perspective."]

      _ ->
        ["I understand.",
         "That makes sense.",
         "Tell me more about that."]
    end

    %{
      suggested_responses: responses,
      confidence_scores: Enum.map(responses, fn _ -> :rand.uniform() * 0.5 + 0.5 end)
    }
  end

  defp analyze_content_safety(content, _context) do
    content_lower = String.downcase(content)

    # Define different categories of concerning content
    hate_keywords = ["hate", "kill", "die", "murder", "racist", "nazi"]
    spam_keywords = ["spam", "buy now", "click here", "free money", "winner", "congratulations"]
    harassment_keywords = ["abuse", "harass", "bully", "stupid", "idiot", "loser"]
    adult_keywords = ["sex", "porn", "nude", "xxx"]
    violence_keywords = ["violence", "fight", "attack", "weapon", "bomb", "threat"]

    # Calculate scores for each category
    hate_score = calculate_keyword_score(content_lower, hate_keywords) * 0.9
    spam_score = calculate_keyword_score(content_lower, spam_keywords) * 0.7
    harassment_score = calculate_keyword_score(content_lower, harassment_keywords) * 0.8
    adult_score = calculate_keyword_score(content_lower, adult_keywords) * 0.8
    violence_score = calculate_keyword_score(content_lower, violence_keywords) * 0.9

    # Calculate overall risk (higher risk = lower safety)
    total_risk = hate_score + spam_score + harassment_score + adult_score + violence_score

    # Convert risk to safety score (0.0 to 1.0, where 1.0 is completely safe)
    base_safety = 0.95 - total_risk

    # Add some content length and complexity factors
    length_factor = cond do
      String.length(content) < 5 -> -0.1  # Very short messages might be suspicious
      String.length(content) > 500 -> -0.05  # Very long messages slightly suspicious
      true -> 0.0
    end

    # Add randomness for more realistic variation (±5%)
    randomness = (:rand.uniform() - 0.5) * 0.1

    safety_score = base_safety + length_factor + randomness
    safety_score = max(0.0, min(1.0, safety_score))  # Clamp between 0 and 1

    # Determine categories detected
    categories = []
    categories = if hate_score > 0.1, do: categories ++ ["hate_speech"], else: categories
    categories = if spam_score > 0.1, do: categories ++ ["spam"], else: categories
    categories = if harassment_score > 0.1, do: categories ++ ["harassment"], else: categories
    categories = if adult_score > 0.1, do: categories ++ ["adult_content"], else: categories
    categories = if violence_score > 0.1, do: categories ++ ["violence"], else: categories

    %{
      moderation_result: %{
        is_safe: safety_score > 0.7,  # More realistic threshold
        categories_detected: categories,
        confidence: safety_score
      },
      safety_score: safety_score,
      action_required: cond do
        safety_score < 0.3 -> :block_content
        safety_score < 0.7 -> :review_required
        true -> :none
      end
    }
  end

  defp calculate_keyword_score(content, keywords) do
    matches = Enum.count(keywords, &String.contains?(content, &1))
    # Return a score between 0.0 and 1.0 based on matches
    case matches do
      0 -> 0.0
      1 -> 0.3
      2 -> 0.6
      _ -> 1.0  # 3 or more matches
    end
  end

  defp get_room_activity_data(room_id, time_period) do
    room = PacketflowChat.Chat.get_room(room_id)

    if room do
      messages = PacketflowChat.Chat.list_room_messages(room_id, 100)

      %{
        room: room,
        messages: messages,
        time_period: time_period,
        fetched_at: DateTime.utc_now()
      }
    else
      %{error: :room_not_found}
    end
  end

  defp generate_room_summary(room_data, _context) do
    if Map.has_key?(room_data, :error) do
      %{error: room_data.error}
    else
      messages = room_data.messages

      %{
        activity_summary: %{
          total_messages: length(messages),
          active_users: messages |> Enum.map(& &1.user_id) |> Enum.uniq() |> length(),
          busiest_hour: find_busiest_hour(messages),
          message_frequency: calculate_message_frequency(messages)
        },
        participant_insights: %{
          most_active_user: find_most_active_user(messages),
          engagement_level: calculate_engagement_level(messages)
        },
        trending_topics: extract_trending_topics(messages)
      }
    end
  end

  # Utility functions

  defp analyze_basic_sentiment(content) do
    positive_words = ["good", "great", "awesome", "love", "happy", "excellent"]
    negative_words = ["bad", "terrible", "hate", "sad", "awful", "horrible"]

    content_lower = String.downcase(content)

    positive_count = Enum.count(positive_words, &String.contains?(content_lower, &1))
    negative_count = Enum.count(negative_words, &String.contains?(content_lower, &1))

    cond do
      positive_count > negative_count -> 0.7
      negative_count > positive_count -> 0.3
      true -> 0.5
    end
  end

  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {word, _count} -> word end)
  end

  defp calculate_time_span(messages) when length(messages) > 0 do
    sorted_messages = Enum.sort_by(messages, & &1.created_at)
    first = List.first(sorted_messages)
    last = List.last(sorted_messages)

    DateTime.diff(last.created_at, first.created_at, :minute)
  end

  defp calculate_time_span(_), do: 0

  defp categorize_activity_level(message_count) do
    cond do
      message_count > 50 -> :high
      message_count > 20 -> :medium
      message_count > 5 -> :low
      true -> :minimal
    end
  end

  defp calculate_sentiment_distribution(sentiment_scores) when length(sentiment_scores) > 0 do
    total = length(sentiment_scores)

    positive = Enum.count(sentiment_scores, &(&1 > 0.6))
    negative = Enum.count(sentiment_scores, &(&1 < 0.4))
    neutral = total - positive - negative

    %{
      positive: positive / total,
      negative: negative / total,
      neutral: neutral / total
    }
  end

  defp calculate_sentiment_distribution(_), do: %{positive: 0, negative: 0, neutral: 1}

  defp analyze_message_type(content) do
    cond do
      String.contains?(content, "?") -> :question
      String.match?(content, ~r/^(hi|hello|hey|good morning|good afternoon)/i) -> :greeting
      true -> :statement
    end
  end

  defp find_busiest_hour(messages) when length(messages) > 0 do
    messages
    |> Enum.map(fn msg -> msg.created_at.hour end)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_hour, count} -> count end, fn -> {0, 0} end)
    |> elem(0)
  end

  defp find_busiest_hour(_), do: 0

  defp calculate_message_frequency(messages) when length(messages) > 1 do
    time_span_minutes = calculate_time_span(messages)
    if time_span_minutes > 0 do
      length(messages) / time_span_minutes
    else
      0
    end
  end

  defp calculate_message_frequency(_), do: 0

  defp find_most_active_user(messages) when length(messages) > 0 do
    messages
    |> Enum.frequencies_by(& &1.user_id)
    |> Enum.max_by(fn {_user, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp find_most_active_user(_), do: nil

  defp calculate_engagement_level(messages) do
    if length(messages) == 0 do
      :none
    else
      unique_users = messages |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()
      avg_messages_per_user = length(messages) / unique_users

      cond do
        avg_messages_per_user > 10 -> :high
        avg_messages_per_user > 5 -> :medium
        avg_messages_per_user > 2 -> :low
        true -> :minimal
      end
    end
  end

  defp extract_trending_topics(messages) do
    all_content = messages |> Enum.map(& &1.content) |> Enum.join(" ")
    extract_keywords(all_content) |> Enum.take(3)
  end

  # LLM Integration Functions

  defp analyze_conversation_with_llm(messages, _context) do
    if length(messages) == 0 do
      {:ok, %{
        message: "No messages found in this conversation.",
        analysis: %{conversation_summary: %{total_messages: 0}}
      }}
    else
      # Prepare conversation context for LLM
      conversation_text = format_messages_for_llm(messages)

      prompt = """
      Please analyze this conversation and provide insights. Focus on:
      1. Overall sentiment and tone
      2. Key topics and themes discussed
      3. Participant engagement patterns
      4. Notable trends or patterns
      5. Summary of the conversation flow

      Conversation:
      #{conversation_text}

      Please provide a natural, conversational analysis that would be helpful to chat participants.
      """

      case call_llm_with_config(prompt) do
        {:ok, llm_response} ->
          {:ok, %{
            message: llm_response,
            analysis: extract_basic_metrics(messages),
            source: "llm_analysis",
            analyzed_at: DateTime.utc_now()
          }}

        error -> error
      end
    end
  end

  defp generate_response_with_llm(message_content, room_id, _context) do
    # Get recent conversation context if room_id is available
    context_messages = if room_id do
      PacketflowChat.Chat.list_room_messages(room_id, 10)
    else
      []
    end

    context_text = if length(context_messages) > 0 do
      "Recent conversation context:\n" <> format_messages_for_llm(context_messages) <> "\n\n"
    else
      ""
    end

    prompt = """
    #{context_text}User message: "#{message_content}"

    Please provide a helpful, natural response to this message. Consider the full conversation context above.

    Important guidelines:
    - Continue the existing conversation naturally
    - Reference previous topics discussed if relevant
    - Be conversational and engaging
    - Don't start over with generic greetings if we're mid-conversation
    - Pay attention to the specific topic being discussed (like Stargate Universe, fingerprints, etc.)
    """

    call_llm_with_config(prompt)
  end

  defp format_messages_for_llm(messages) do
    messages
    |> Enum.reverse() # Show chronological order
    |> Enum.take(20)  # Limit to recent messages to avoid token limits
    |> Enum.map(fn msg ->
      timestamp = Calendar.strftime(msg.created_at, "%H:%M")
      user_id = String.slice(to_string(msg.user_id), 0, 8) # Truncate for privacy
      "#{timestamp} User#{user_id}: #{msg.content}"
    end)
    |> Enum.join("\n")
  end

  defp extract_basic_metrics(messages) do
    %{
      conversation_summary: %{
        total_messages: length(messages),
        unique_participants: messages |> Enum.map(& &1.user_id) |> Enum.uniq() |> length(),
        time_span_minutes: calculate_time_span(messages),
        activity_level: categorize_activity_level(length(messages))
      }
    }
  end

  defp call_llm_with_config(prompt) do
    # Use the same configuration as AI Planner
    config = %{
      model: "claude-3-5-sonnet-20241022",
      anthropic_api_key: get_api_key(:anthropic),
      openai_api_key: get_api_key(:openai),
      default_provider: :anthropic
    }

    # Check if we have any API keys
    cond do
      config.anthropic_api_key && config.default_provider == :anthropic ->
        call_anthropic_llm(prompt, config)

      config.openai_api_key && config.default_provider == :openai ->
        call_openai_llm(prompt, config)

      config.openai_api_key ->
        # Fallback to OpenAI if Anthropic key is missing
        call_openai_llm(prompt, config)

      config.anthropic_api_key ->
        # Fallback to Anthropic if OpenAI key is missing
        call_anthropic_llm(prompt, config)

      true ->
        Logger.warn("No API keys configured for LLM providers. Set ANTHROPIC_API_KEY or OPENAI_API_KEY environment variables.")
        {:error, :no_api_keys_configured}
    end
  end

  defp get_api_key(provider) do
    case provider do
      :anthropic ->
        System.get_env("ANTHROPIC_API_KEY") ||
        Application.get_env(:packet_flow, :anthropic_api_key)
      :openai ->
        System.get_env("OPENAI_API_KEY") ||
        Application.get_env(:packet_flow, :openai_api_key)
    end
  end

  defp call_anthropic_llm(prompt, config) do
    if config.anthropic_api_key do
      headers = [
        {"Content-Type", "application/json"},
        {"x-api-key", config.anthropic_api_key},
        {"anthropic-version", "2023-06-01"}
      ]

      body = Jason.encode!(%{
        model: config.model,
        max_tokens: 2000,
        messages: [%{
          role: "user",
          content: prompt
        }]
      })

      case HTTPoison.post("https://api.anthropic.com/v1/messages", body, headers, [recv_timeout: 30_000, timeout: 35_000]) do
        {:ok, %{status_code: 200, body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, %{"content" => [%{"text" => text}]}} -> {:ok, text}
            {:ok, response} -> {:error, {:unexpected_response_format, response}}
            {:error, reason} -> {:error, {:json_decode_error, reason}}
          end

        {:ok, %{status_code: status_code, body: body}} ->
          {:error, {:api_error, status_code, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    else
      {:error, :missing_anthropic_api_key}
    end
  end

  defp call_openai_llm(prompt, config) do
    if config.openai_api_key do
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{config.openai_api_key}"}
      ]

      body = Jason.encode!(%{
        model: "gpt-4",
        messages: [%{
          role: "user",
          content: prompt
        }],
        max_tokens: 2000
      })

      case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers, [recv_timeout: 30_000, timeout: 35_000]) do
        {:ok, %{status_code: 200, body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
              {:ok, content}
            {:ok, response} ->
              {:error, {:unexpected_response_format, response}}
            {:error, reason} ->
              {:error, {:json_decode_error, reason}}
          end

        {:ok, %{status_code: status_code, body: body}} ->
          {:error, {:api_error, status_code, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    else
      {:error, :missing_openai_api_key}
    end
  end
end
