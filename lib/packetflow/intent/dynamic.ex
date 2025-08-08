defmodule PacketFlow.Intent.Dynamic do
  @moduledoc """
  Dynamic intent processing and routing system for PacketFlow

  This module provides runtime intent creation, dynamic routing,
  composition patterns, validation plugins, and transformation plugins.
  """

  @doc """
  Create an intent dynamically at runtime

  ## Examples
  ```elixir
  # Create a file read intent dynamically
  intent = PacketFlow.Intent.Dynamic.create_intent(
    "FileReadIntent",
    %{path: "/path/to/file", user_id: "user123"},
    [FileCap.read("/path/to/file")]
  )

  # Create a composite intent
  composite_intent = PacketFlow.Intent.Dynamic.create_composite_intent([
    intent1,
    intent2,
    intent3
  ], :sequential)
  ```
  """
  def create_intent(intent_type, payload, capabilities \\ []) do
    %{
      type: intent_type,
      payload: payload,
      capabilities: capabilities,
      metadata: %{
        created_at: System.system_time(),
        dynamic: true,
        id: generate_intent_id()
      }
    }
  end

  @doc """
  Create a composite intent from multiple intents

  ## Examples
  ```elixir
  composite = PacketFlow.Intent.Dynamic.create_composite_intent([
    file_read_intent,
    file_process_intent,
    file_save_intent
  ], :sequential)
  ```
  """
  def create_composite_intent(intents, composition_strategy \\ :parallel) do
    %{
      type: :composite,
      intents: intents,
      composition_strategy: composition_strategy,
      metadata: %{
        created_at: System.system_time(),
        dynamic: true,
        composite: true,
        id: generate_intent_id()
      }
    }
  end

  @doc """
  Route an intent dynamically based on its type and capabilities

  ## Examples
  ```elixir
  # Route to appropriate reactor
  case PacketFlow.Intent.Dynamic.route_intent(intent) do
    {:ok, target_reactor} ->
      PacketFlow.Reactor.process(target_reactor, intent)
    {:error, reason} ->
      Logger.error("Failed to route intent: " <> inspect(reason))
  end
  ```
  """
  def route_intent(intent) do
    case get_routing_strategy(intent) do
      {:ok, strategy} ->
        apply_routing_strategy(intent, strategy)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Compose multiple intents using different composition patterns

  ## Examples
  ```elixir
  # Sequential composition
  result = PacketFlow.Intent.Dynamic.compose_intents([
    intent1,
    intent2,
    intent3
  ], :sequential)

  # Parallel composition
  result = PacketFlow.Intent.Dynamic.compose_intents([
    intent1,
    intent2,
    intent3
  ], :parallel)

  # Conditional composition
  result = PacketFlow.Intent.Dynamic.compose_intents([
    intent1,
    intent2,
    intent3
  ], :conditional, %{condition: &successful?/1})
  ```
  """
  def compose_intents(intents, composition_pattern, opts \\ %{}) do
    case composition_pattern do
      :sequential ->
        compose_sequential(intents, opts)
      :parallel ->
        compose_parallel(intents, opts)
      :conditional ->
        compose_conditional(intents, opts)
      :pipeline ->
        compose_pipeline(intents, opts)
      :fan_out ->
        compose_fan_out(intents, opts)
      _ ->
        {:error, :unsupported_composition_pattern}
    end
  end

  @doc """
  Validate an intent using registered validation plugins

  ## Examples
  ```elixir
  case PacketFlow.Intent.Dynamic.validate_intent(intent) do
    {:ok, validated_intent} ->
      # Process validated intent
    {:error, validation_errors} ->
      # Handle validation errors
  end
  ```
  """
  def validate_intent(intent) do
    validation_plugins = get_validation_plugins()

    validation_result = Enum.reduce_while(validation_plugins, {:ok, intent}, fn plugin, {:ok, current_intent} ->
      case plugin.validate(current_intent) do
        {:ok, validated_intent} ->
          {:cont, {:ok, validated_intent}}
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)

    case validation_result do
      {:ok, validated_intent} ->
        {:ok, validated_intent}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Transform an intent using registered transformation plugins

  ## Examples
  ```elixir
  case PacketFlow.Intent.Dynamic.transform_intent(intent) do
    {:ok, transformed_intent} ->
      # Process transformed intent
    {:error, reason} ->
      # Handle transformation error
  end
  ```
  """
  def transform_intent(intent) do
    transformation_plugins = get_transformation_plugins()

    transformation_result = Enum.reduce_while(transformation_plugins, {:ok, intent}, fn plugin, {:ok, current_intent} ->
      case plugin.transform(current_intent) do
        {:ok, transformed_intent} ->
          {:cont, {:ok, transformed_intent}}
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)

    case transformation_result do
      {:ok, transformed_intent} ->
        {:ok, transformed_intent}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delegate an intent to another processor

  ## Examples
  ```elixir
  case PacketFlow.Intent.Dynamic.delegate_intent(intent, target_processor) do
    {:ok, delegated_intent} ->
      # Intent delegated successfully
    {:error, reason} ->
      # Handle delegation error
  end
  ```
  """
  def delegate_intent(intent, target_processor) do
    case validate_delegation(intent, target_processor) do
      {:ok, _} ->
        delegated_intent = %{
          intent |
          metadata: Map.put(intent.metadata, :delegated_to, target_processor)
        }
        {:ok, delegated_intent}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions

  defp generate_intent_id do
    "intent_#{System.system_time()}_#{:rand.uniform(1000000)}"
  end

  defp get_routing_strategy(intent) do
    # Get routing strategy based on intent type and capabilities
    case intent.type do
      "FileReadIntent" ->
        {:ok, :file_processor}
      "FileWriteIntent" ->
        {:ok, :file_processor}
      "UserIntent" ->
        {:ok, :user_processor}
      :composite ->
        {:ok, :composite_processor}
      _ ->
        {:ok, :default_processor}
    end
  end

  defp apply_routing_strategy(_intent, strategy) do
    case strategy do
      :file_processor ->
        {:ok, PacketFlow.Registry.lookup_reactor("file_reactor")}
      :user_processor ->
        {:ok, PacketFlow.Registry.lookup_reactor("user_reactor")}
      :composite_processor ->
        {:ok, PacketFlow.Registry.lookup_reactor("composite_reactor")}
      :default_processor ->
        {:ok, PacketFlow.Registry.lookup_reactor("default_reactor")}
      _ ->
        {:error, :unknown_routing_strategy}
    end
  end

  defp compose_sequential(intents, _opts) do
    # Execute intents in sequence
    result = Enum.reduce_while(intents, {:ok, []}, fn intent, {:ok, results} ->
      case process_intent(intent) do
        {:ok, result} ->
          {:cont, {:ok, [result | results]}}
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)

    case result do
      {:ok, results} ->
        {:ok, Enum.reverse(results)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compose_parallel(intents, _opts) do
    # Execute intents in parallel
    tasks = Enum.map(intents, fn intent ->
      Task.async(fn -> process_intent(intent) end)
    end)

    results = Enum.map(tasks, &Task.await/1)

    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil ->
        {:ok, Enum.map(results, fn {:ok, result} -> result end)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compose_conditional(intents, %{condition: condition_fn}) do
    # Execute intents conditionally
    Enum.reduce_while(intents, {:ok, []}, fn intent, {:ok, results} ->
      case condition_fn.(results) do
        true ->
          case process_intent(intent) do
            {:ok, result} ->
              {:cont, {:ok, [result | results]}}
            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        false ->
          {:halt, {:ok, Enum.reverse(results)}}
      end
    end)
  end

  defp compose_pipeline(intents, _opts) do
    # Execute intents as a pipeline, passing result to next
    Enum.reduce_while(intents, {:ok, nil}, fn intent, {:ok, previous_result} ->
      case process_intent_with_context(intent, previous_result) do
        {:ok, result} ->
          {:cont, {:ok, result}}
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp compose_fan_out(intents, _opts) do
    # Execute intents and fan out results
    case compose_parallel(intents, %{}) do
      {:ok, results} ->
        {:ok, %{type: :fan_out, results: results}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_intent(intent) do
    # Process a single intent - for testing, just return success
    case route_intent(intent) do
      {:ok, _target} ->
        {:ok, %{result: "processed", intent: intent}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_intent_with_context(intent, context) do
    # Process intent with context from previous result
    intent_with_context = %{intent | payload: Map.put(intent.payload, :context, context)}
    process_intent(intent_with_context)
  end

  defp get_validation_plugins do
    # Get registered validation plugins
    PacketFlow.Intent.Plugin.get_plugins()
    |> Enum.filter(fn plugin -> plugin.plugin_type() == :intent_validation end)
  end

  defp get_transformation_plugins do
    # Get registered transformation plugins - for now, use validation plugins that also transform
    PacketFlow.Intent.Plugin.get_plugins()
    |> Enum.filter(fn plugin ->
      plugin.plugin_type() == :intent_validation or plugin.plugin_type() == :intent_transformation
    end)
  end

  defp validate_delegation(intent, target_processor) do
    # Validate that intent can be delegated to target processor
    case PacketFlow.Registry.lookup_reactor(target_processor) do
      nil ->
        {:error, :target_processor_not_found}
      _ ->
        {:ok, intent}
    end
  end
end
