defmodule PacketFlow.AIPlanner do
  @moduledoc """
  AI-powered planning system that converts natural language intents into
  executable capability plans.

  This module integrates with LLM providers to analyze user intents and
  generate optimal execution plans using available capabilities.
  """

  use GenServer
  require Logger

  @default_model "claude-3-5-sonnet-20241022"
  @planning_timeout 30_000

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate an execution plan from natural language intent.
  """
  def generate_plan(intent, context \\ %{}) do
    GenServer.call(__MODULE__, {:generate_plan, intent, context}, @planning_timeout)
  end

  @doc """
  Analyze user intent and extract structured information.
  """
  def analyze_intent(intent) do
    GenServer.call(__MODULE__, {:analyze_intent, intent}, @planning_timeout)
  end

  # GenServer implementation

  @impl true
  def init(opts) do
    config = %{
      anthropic_api_key: get_api_key(:anthropic, opts),
      openai_api_key: get_api_key(:openai, opts),
      default_provider: Keyword.get(opts, :default_provider, :anthropic),
      model: Keyword.get(opts, :model, @default_model)
    }

    Logger.info("PacketFlow.AIPlanner started with provider: #{config.default_provider}")
    {:ok, config}
  end

  @impl true
  def handle_call({:generate_plan, intent, context}, _from, state) do
    case do_generate_plan(intent, context, state) do
      {:ok, plan} ->
        Logger.info("Generated execution plan for intent: #{String.slice(intent, 0, 50)}...")
        {:reply, {:ok, plan}, state}

      {:error, reason} ->
        Logger.error("Failed to generate plan: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:analyze_intent, intent}, _from, state) do
    case do_analyze_intent(intent, state) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, state}

      {:error, reason} ->
        Logger.error("Failed to analyze intent: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  # Private functions

  defp get_api_key(provider, opts) do
    Keyword.get(opts, :"#{provider}_api_key") ||
    System.get_env("#{String.upcase(to_string(provider))}_API_KEY")
  end

  defp do_generate_plan(intent, context, config) do
    with {:ok, available_capabilities} <- get_available_capabilities(),
         {:ok, planning_prompt} <- build_planning_prompt(intent, available_capabilities, context),
         {:ok, llm_response} <- call_llm(planning_prompt, config),
         {:ok, parsed_plan} <- parse_plan_response(llm_response) do

      # Validate the generated plan
      validated_plan = validate_plan(parsed_plan, available_capabilities)
      {:ok, validated_plan}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_analyze_intent(intent, config) do
    analysis_prompt = build_intent_analysis_prompt(intent)

    with {:ok, llm_response} <- call_llm(analysis_prompt, config),
         {:ok, parsed_analysis} <- parse_intent_analysis(llm_response) do
      {:ok, parsed_analysis}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_available_capabilities do
    case PacketFlow.CapabilityRegistry.list_all() do
      capabilities when is_list(capabilities) ->
        simplified_caps = Enum.map(capabilities, fn cap ->
          %{
            id: cap.id,
            intent: cap.intent,
            requires: cap.requires,
            provides: cap.provides
          }
        end)
        {:ok, simplified_caps}

      error ->
        {:error, {:capability_discovery_failed, error}}
    end
  end

  defp build_planning_prompt(intent, capabilities, context) do
    capabilities_json = Jason.encode!(capabilities, pretty: true)
    context_json = Jason.encode!(context, pretty: true)

    prompt = """
    You are a capability planner for PacketFlow, a distributed systems framework.

    User Intent: "#{intent}"

    Available Capabilities:
    #{capabilities_json}

    Context:
    #{context_json}

    Your task is to create an optimal execution plan that achieves the user's intent using the available capabilities.

    Guidelines:
    1. Break down the intent into concrete, executable steps
    2. Map each step to specific capabilities based on their intent and contracts
    3. Ensure data flow between steps (outputs of one step feed inputs of next)
    4. Handle error scenarios and edge cases
    5. Optimize for performance and reliability

    Respond with a JSON object in this exact format:
    {
      "analysis": {
        "intent_summary": "Brief summary of what the user wants",
        "complexity": "simple|moderate|complex",
        "required_data": ["list", "of", "required", "input", "data"],
        "expected_outputs": ["list", "of", "expected", "results"]
      },
      "execution_plan": {
        "type": "sequential|parallel|conditional",
        "steps": [
          {
            "id": "step_1",
            "capability_id": "capability_name",
            "description": "What this step does",
            "inputs": {"key": "value"},
            "expected_outputs": ["output1", "output2"],
            "depends_on": []
          }
        ]
      },
      "fallback_strategy": {
        "description": "What to do if the plan fails",
        "alternative_capabilities": ["backup", "options"]
      }
    }
    """

    {:ok, prompt}
  end

  defp build_intent_analysis_prompt(intent) do
    """
    Analyze the following user intent and extract structured information:

    Intent: "#{intent}"

    Respond with a JSON object in this format:
    {
      "intent_type": "query|action|creation|analysis|transformation",
      "entities": ["extracted", "entities", "from", "intent"],
      "actions": ["list", "of", "actions", "to", "perform"],
      "context_requirements": ["what", "context", "is", "needed"],
      "complexity_score": 0.5,
      "urgency": "low|medium|high",
      "estimated_execution_time": "seconds"
    }
    """
  end

  defp call_llm(prompt, config) do
    case config.default_provider do
      :anthropic -> call_anthropic(prompt, config)
      :openai -> call_openai(prompt, config)
      _ -> {:error, :unsupported_provider}
    end
  end

  defp call_anthropic(prompt, config) do
    if config.anthropic_api_key do
      headers = [
        {"Content-Type", "application/json"},
        {"x-api-key", config.anthropic_api_key},
        {"anthropic-version", "2023-06-01"}
      ]

      body = Jason.encode!(%{
        model: config.model,
        max_tokens: 4000,
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

  defp call_openai(prompt, config) do
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
        max_tokens: 4000
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

  defp parse_plan_response(response) do
    case Jason.decode(response) do
      {:ok, %{"analysis" => analysis, "execution_plan" => plan} = parsed} ->
        validated_plan = %{
          analysis: analysis,
          execution_plan: plan,
          fallback_strategy: Map.get(parsed, "fallback_strategy", %{}),
          generated_at: DateTime.utc_now(),
          llm_provider: :anthropic
        }
        {:ok, validated_plan}

      {:ok, invalid} ->
        {:error, {:invalid_plan_format, invalid}}

      {:error, reason} ->
        {:error, {:json_parse_error, reason}}
    end
  end

  defp parse_intent_analysis(response) do
    case Jason.decode(response) do
      {:ok, analysis} when is_map(analysis) ->
        {:ok, Map.put(analysis, "analyzed_at", DateTime.utc_now())}

      {:error, reason} ->
        {:error, {:json_parse_error, reason}}
    end
  end

  defp validate_plan(plan, available_capabilities) do
    # Validate that all referenced capabilities exist
    capability_ids = get_capability_ids(available_capabilities)

    validated_steps = plan["execution_plan"]["steps"]
    |> Enum.map(fn step ->
      capability_id = step["capability_id"]

      if capability_id in capability_ids do
        step
      else
        # Try to find a similar capability
        similar = find_similar_capability(capability_id, available_capabilities)
        Map.put(step, "capability_id", similar || capability_id)
      end
    end)

    put_in(plan, ["execution_plan", "steps"], validated_steps)
  end

  defp get_capability_ids(capabilities) do
    Enum.map(capabilities, fn cap -> to_string(cap.id) end)
  end

  defp find_similar_capability(target_id, capabilities) do
    target_lower = String.downcase(to_string(target_id))

    capabilities
    |> Enum.find(fn cap ->
      cap_id_lower = String.downcase(to_string(cap.id))
      String.contains?(cap_id_lower, target_lower) or String.contains?(target_lower, cap_id_lower)
    end)
    |> case do
      nil -> nil
      cap -> to_string(cap.id)
    end
  end
end
