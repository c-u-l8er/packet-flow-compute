defmodule PacketflowChatDemo.OpenAIService do
  @moduledoc """
  OpenAI API integration service for real AI responses.
  Supports both regular and streaming responses.
  """

  require Logger

  @api_base_url "https://api.openai.com/v1"
  @default_model "gpt-3.5-turbo"
  @default_max_tokens 1000
  @default_temperature 0.7

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Generate a complete AI response using OpenAI's API.
  """
  def generate_response(message, message_history \\ [], config \\ %{}) do
    api_key = get_api_key()

    if api_key do
      messages = build_messages(message, message_history)
      request_body = build_request_body(messages, config, false)

      case make_api_request(request_body, api_key) do
        {:ok, response} -> parse_response(response)
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "OpenAI API key not configured"}
    end
  end

    @doc """
  Generate a streaming AI response using OpenAI's API.
  For now, we'll simulate streaming by chunking a complete response.
  """
  def generate_streaming_response(message, message_history \\ [], config \\ %{}) do
    # For simplicity, let's get the complete response and then simulate streaming
    case generate_response(message, message_history, config) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end



  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp get_api_key do
    # First try environment variable, then application config
    System.get_env("OPENAI_API_KEY") ||
    Application.get_env(:packetflow_chat_demo, :openai_api_key)
  end

  defp build_messages(current_message, message_history) do
    # Convert message history to OpenAI format
    history_messages =
      message_history
      |> Enum.reverse() # Reverse to get chronological order
      |> Enum.map(&format_message_for_openai/1)

    # Add the current message
    current_formatted = %{
      role: "user",
      content: current_message
    }

    # Add system message at the beginning
    system_message = %{
      role: "system",
      content: "You are a helpful AI assistant powered by PacketFlow. Be friendly, informative, and helpful."
    }

    [system_message | history_messages] ++ [current_formatted]
  end

  defp format_message_for_openai(message) do
    role = case message.role do
      :user -> "user"
      :assistant -> "assistant"
      :system -> "system"
      _ -> "user"
    end

    %{
      role: role,
      content: message.content
    }
  end

  defp build_request_body(messages, config, stream) do
    %{
      model: Map.get(config, :model, @default_model),
      messages: messages,
      max_tokens: Map.get(config, :max_tokens, @default_max_tokens),
      temperature: Map.get(config, :temperature, @default_temperature),
      stream: stream
    }
    |> Jason.encode!()
  end

  defp make_api_request(request_body, api_key) do
    url = "#{@api_base_url}/chat/completions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case HTTPoison.post(url, request_body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, "Failed to parse API response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("OpenAI API error: #{status_code} - #{body}")
        {:error, "API request failed with status #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenAI API request failed: #{inspect(reason)}")
        {:error, "Network error: #{reason}"}
    end
  end



  defp parse_response(response) do
    case get_in(response, ["choices", Access.at(0), "message", "content"]) do
      nil -> {:error, "No response content found"}
      content -> {:ok, String.trim(content)}
    end
  end



  # ============================================================================
  # STREAM PROCESSING
  # ============================================================================

  @doc """
  Start a streaming response process that sends chunks to a GenServer.
  """
  def start_stream_to_process(message, message_history, config, target_pid) do
    spawn_link(fn ->
      case generate_streaming_response(message, message_history, config) do
        {:ok, response} ->
          send(target_pid, {:stream_started, :simulated})
          simulate_streaming(response, target_pid)
        {:error, reason} ->
          send(target_pid, {:stream_error, reason})
      end
    end)
  end

  defp simulate_streaming(response, target_pid) do
    # Split response into words for more natural streaming
    words = String.split(response, " ")

    Enum.each(words, fn word ->
      # Add space back except for the first word
      chunk = if word == Enum.at(words, 0), do: word, else: " #{word}"
      send(target_pid, {:stream_chunk, chunk})
      Process.sleep(50) # Simulate typing delay
    end)

    send(target_pid, {:stream_ended})
  end


end
