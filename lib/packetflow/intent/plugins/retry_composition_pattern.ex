defmodule PacketFlow.Intent.Plugins.RetryCompositionPattern do
  @moduledoc """
  Retry composition pattern for intent system

  This demonstrates a custom composition pattern that implements
  retry logic for failed intent compositions.
  """

  @behaviour PacketFlow.Intent.Plugin.CompositionPattern

  @pattern_type :retry
  @max_retries 3
  @default_opts %{
    max_retries: 3,
    retry_delay: 1000,
    exponential_backoff: true,
    max_delay: 10000
  }

  @doc """
  Compose intents with retry logic
  """
  def compose(intents, opts) do
    max_retries = Map.get(opts, :max_retries, @max_retries)
    retry_delay = Map.get(opts, :retry_delay, 1000)
    exponential_backoff = Map.get(opts, :exponential_backoff, true)
    max_delay = Map.get(opts, :max_delay, 10000)

    compose_with_retry(intents, :sequential, %{
      max_retries: max_retries,
      retry_delay: retry_delay,
      exponential_backoff: exponential_backoff,
      max_delay: max_delay,
      current_retry: 0
    })
  end

  @doc """
  Get pattern type
  """
  def pattern_type do
    @pattern_type
  end

  @doc """
  Get default options
  """
  def default_opts do
    @default_opts
  end

  # Private Functions

  defp compose_with_retry(intents, strategy, retry_opts) do
    case PacketFlow.Intent.Dynamic.compose_intents(intents, strategy) do
      {:ok, results} ->
        {:ok, results}
      {:error, reason} when retry_opts.current_retry < retry_opts.max_retries ->
        # Retry with exponential backoff
        delay = calculate_retry_delay(retry_opts)
        Process.sleep(delay)

        updated_retry_opts = %{
          retry_opts |
          current_retry: retry_opts.current_retry + 1
        }

        compose_with_retry(intents, strategy, updated_retry_opts)
              {:error, _reason} ->
          {:error, {:max_retries_exceeded, :timeout}}
    end
  end

  defp calculate_retry_delay(retry_opts) do
    if retry_opts.exponential_backoff do
      base_delay = retry_opts.retry_delay
      exponential_delay = base_delay * :math.pow(2, retry_opts.current_retry)
      max_delay = retry_opts.max_delay

      min(round(exponential_delay), max_delay)
    else
      retry_opts.retry_delay
    end
  end
end
