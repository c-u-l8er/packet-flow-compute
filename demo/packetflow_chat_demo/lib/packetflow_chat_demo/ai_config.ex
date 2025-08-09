defmodule PacketflowChatDemo.AIConfig do
  @moduledoc """
  Centralized AI provider configuration and pricing.
  """

  @doc """
  Gets the OpenAI API key from application config.
  """
  def openai_api_key do
    Application.get_env(:packetflow_chat_demo, :openai_api_key) ||
      System.get_env("OPENAI_API_KEY")
  end

  @doc """
  Gets the Anthropic API key from application config.
  """
  def anthropic_api_key do
    Application.get_env(:packetflow_chat_demo, :anthropic_api_key) ||
      System.get_env("ANTHROPIC_API_KEY")
  end

  @doc """
  Gets the Google API key from application config.
  """
  def google_api_key do
    Application.get_env(:packetflow_chat_demo, :google_api_key) ||
      System.get_env("GOOGLE_API_KEY")
  end

  @doc """
  Returns all available models based on configured API keys.
  Now focuses on latest GPT-5 models only.
  """
  def available_models do
    models = %{}

    models = if openai_api_key() do
      Map.merge(models, %{
        "gpt-5" => "GPT-5",
        "gpt-5-mini" => "GPT-5 Mini",
        "gpt-5-nano" => "GPT-5 Nano",
        "gpt-5-chat-latest" => "GPT-5 Chat Latest"
      })
    else
      models
    end

    if Enum.empty?(models) do
      # Fallback if no API keys are configured - still show GPT-5 models for demo
      %{
        "gpt-5" => "GPT-5 (Demo)",
        "gpt-5-mini" => "GPT-5 Mini (Demo)",
        "gpt-5-nano" => "GPT-5 Nano (Demo)",
        "gpt-5-chat-latest" => "GPT-5 Chat Latest (Demo)"
      }
    else
      models
    end
  end

  @doc """
  Gets pricing information for a model (in cents per 1K tokens).
  Updated with official GPT-5 pricing from OpenAI.
  """
  def model_pricing(model) do
    case model do
      # GPT-5 Pricing (per 1K tokens) - Official rates
      # Note: Input rates are for regular input, cached input is 10x cheaper
      "gpt-5" -> %{input: 0.125, output: 1.0, provider: "openai"}  # $1.25/1M -> 0.125¢/1K input, $10/1M -> 1.0¢/1K output
      "gpt-5-mini" -> %{input: 0.025, output: 0.2, provider: "openai"}  # $0.25/1M -> 0.025¢/1K input, $2/1M -> 0.2¢/1K output
      "gpt-5-nano" -> %{input: 0.005, output: 0.04, provider: "openai"}  # $0.05/1M -> 0.005¢/1K input, $0.40/1M -> 0.04¢/1K output
      "gpt-5-chat-latest" -> %{input: 0.125, output: 1.0, provider: "openai"}  # Same as gpt-5

      # Legacy models (for backward compatibility)
      "gpt-3.5-turbo" -> %{input: 0.05, output: 0.15, provider: "openai"}
      "gpt-4" -> %{input: 3.0, output: 6.0, provider: "openai"}
      "gpt-4-turbo" -> %{input: 1.0, output: 3.0, provider: "openai"}
      "gpt-4o" -> %{input: 0.5, output: 1.5, provider: "openai"}

      # Anthropic Pricing (per 1K tokens)
      "claude-3-haiku" -> %{input: 0.025, output: 0.125, provider: "anthropic"}
      "claude-3-sonnet" -> %{input: 0.3, output: 1.5, provider: "anthropic"}
      "claude-3-opus" -> %{input: 1.5, output: 7.5, provider: "anthropic"}

      # Google Pricing (per 1K tokens)
      "gemini-pro" -> %{input: 0.05, output: 0.15, provider: "google"}
      "gemini-pro-vision" -> %{input: 0.05, output: 0.15, provider: "google"}

      # Default/Unknown
      _ -> %{input: 0.0, output: 0.0, provider: "unknown"}
    end
  end

  @doc """
  Calculates the cost for a request in cents.
  """
  def calculate_cost(model, prompt_tokens, completion_tokens) do
    pricing = model_pricing(model)

    prompt_cost = Float.round(prompt_tokens / 1000 * pricing.input, 4)
    completion_cost = Float.round(completion_tokens / 1000 * pricing.output, 4)
    total_cost = prompt_cost + completion_cost

    %{
      prompt_cost_cents: round(prompt_cost * 100),
      completion_cost_cents: round(completion_cost * 100),
      total_cost_cents: round(total_cost * 100),
      provider: pricing.provider
    }
  end

  @doc """
  Checks if a provider is available (has API key configured).
  """
  def provider_available?(provider) do
    case provider do
      "openai" -> !is_nil(openai_api_key())
      "anthropic" -> !is_nil(anthropic_api_key())
      "google" -> !is_nil(google_api_key())
      _ -> false
    end
  end

  @doc """
  Gets the provider for a model.
  """
  def model_provider(model) do
    pricing = model_pricing(model)
    pricing.provider
  end
end
