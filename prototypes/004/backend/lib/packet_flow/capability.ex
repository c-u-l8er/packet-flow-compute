defmodule PacketFlow.Capability do
  @moduledoc """
  Macro for defining declarative capabilities with contracts and effects.

  Capabilities are the core abstraction in PacketFlow - they represent units
  of functionality that can be discovered, composed, and executed across
  network boundaries.
  """

  defmacro __using__(_opts) do
    quote do
      import PacketFlow.Capability
      Module.register_attribute(__MODULE__, :capabilities, accumulate: true)

      @before_compile PacketFlow.Capability
    end
  end

  defmacro __before_compile__(env) do
    capabilities = Module.get_attribute(env.module, :capabilities)

    quote do
      def __capabilities__, do: unquote(capabilities)

      def list_capabilities do
        __capabilities__()
        |> Enum.map(fn cap ->
          %{
            id: cap.id,
            intent: cap.intent,
            requires: cap.requires,
            provides: cap.provides,
            effects: cap.effects
          }
        end)
      end
    end
  end

  @doc """
  Define a capability with declarative contracts.

  ## Example

      capability :user_transform do
        intent "Transform user data with specified operations"
        requires [:user_id, :operations]
        provides [:transformed_user, :operation_log]

        effect :audit_log, level: :info
        effect :metrics, type: :counter, name: "user_transforms"

        execute fn payload, context ->
          # Implementation here
          {:ok, %{transformed_user: result, operation_log: log}}
        end
      end
  """
  defmacro capability(name, do: block) do
    # Extract metadata from the block at compile time
    {metadata, execute_ast} = extract_capability_info(block)

    quote do
      # Store capability metadata
      @capabilities Map.put(unquote(Macro.escape(metadata)), :id, unquote(name))

      # Generate the actual capability function
      def unquote(name)(payload, context \\ %{}) do
        # Get capability metadata
        capability = Enum.find(__capabilities__(), &(&1.id == unquote(name)))

        # Simple execution without complex validation for now
        try do
          unquote(execute_ast)
        rescue
          error ->
            {:error, {:execution_failed, error}}
        end
      end
    end
  end

  # Helper function to extract capability information from the AST
  defp extract_capability_info(block) do
    metadata = %{
      intent: nil,
      requires: [],
      provides: [],
      effects: []
    }

    execute_ast = quote do
      {:error, :no_execute_function}
    end

    # For now, return simple defaults - we'll enhance this later
    {metadata, execute_ast}
  end

  defmacro intent(description) do
    quote do
      @current_capability Map.put(@current_capability, :intent, unquote(description))
    end
  end

  defmacro requires(fields) when is_list(fields) do
    quote do
      @current_capability Map.put(@current_capability, :requires, unquote(fields))
    end
  end

  defmacro provides(fields) when is_list(fields) do
    quote do
      @current_capability Map.put(@current_capability, :provides, unquote(fields))
    end
  end

  defmacro effect(type, opts \\ []) do
    quote do
      effect_def = %{type: unquote(type), opts: unquote(opts)}
      @current_capability Map.update(@current_capability, :effects, [effect_def], &[effect_def | &1])
    end
  end

  defmacro execute(fun) do
    quote do
      @current_capability Map.put(@current_capability, :execute_fn, unquote(fun))
    end
  end

  # Helper functions for validation and execution
  defp validate_requirements(payload, required_fields) do
    missing_fields = required_fields -- Map.keys(payload)

    case missing_fields do
      [] -> :ok
      missing -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_provides(result, provided_fields) do
    case result do
      {:ok, data} when is_map(data) ->
        missing_fields = provided_fields -- Map.keys(data)
        case missing_fields do
          [] -> :ok
          missing -> {:error, {:missing_provided_fields, missing}}
        end

      {:error, _reason} = error -> error

      _ -> {:error, :invalid_result_format}
    end
  end

  defp execute_with_effects(capability, payload, context) do
    # Add telemetry and logging
    start_time = System.monotonic_time(:millisecond)

    # Execute effects (before)
    Enum.each(capability.effects, &execute_effect(&1, :before, payload, context))

    # Execute the capability
    result = case capability.execute_fn do
      nil -> {:error, :no_execute_function}
      fun -> fun.(payload, context)
    end

    # Calculate execution time
    end_time = System.monotonic_time(:millisecond)
    execution_time = end_time - start_time

    # Execute effects (after)
    effect_context = Map.put(context, :execution_time, execution_time)
    Enum.each(capability.effects, &execute_effect(&1, :after, result, effect_context))

    result
  end

  defp execute_effect(effect, phase, data, context) do
    case effect.type do
      :audit_log ->
        level = Keyword.get(effect.opts, :level, :info)
        Logger.log(level, "Capability executed",
          capability: context[:capability_id],
          phase: phase,
          data: inspect(data),
          context: context
        )

      :metrics ->
        metric_type = Keyword.get(effect.opts, :type, :counter)
        metric_name = Keyword.get(effect.opts, :name, "capability_execution")

        case {metric_type, phase} do
          {:counter, :after} ->
            :telemetry.execute([:packet_flow, :capability, :executed], %{count: 1}, context)

          {:histogram, :after} ->
            execution_time = Map.get(context, :execution_time, 0)
            :telemetry.execute([:packet_flow, :capability, :duration], %{duration: execution_time}, context)

          _ -> :ok
        end

      _ -> :ok
    end
  end
end
