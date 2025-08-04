defmodule PacketFlow.ActorCapability do
  @moduledoc """
  Macro for defining actor-based capabilities with persistent state.

  Actor capabilities extend regular capabilities with:
  - Persistent state between message executions
  - Message pattern matching and handling
  - Configurable timeouts and lifecycle management
  - State persistence strategies

  ## Example

      defmodule MyApp.PersistentChatAgent do
        use PacketFlow.ActorCapability

        actor_capability :persistent_chat do
          intent "AI chat agent with conversation memory"
          requires [:message, :user_id]
          provides [:response, :conversation_updated]

          initial_state %{
            conversation_history: [],
            user_preferences: %{}
          }

          state_persistence :memory
          actor_timeout :timer.minutes(30)

          handle_message do
            %{type: "chat", message: msg} -> handle_chat_message(msg, state)
            %{type: "clear"} -> clear_conversation(state)
          end
        end

        def handle_chat_message(message, state) do
          # Process message and update state
          new_history = [message | state.conversation_history]
          new_state = %{state | conversation_history: new_history}

          response = generate_ai_response(message, new_history)

          {:ok, %{response: response}, new_state}
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import PacketFlow.ActorCapability
      Module.register_attribute(__MODULE__, :actor_capabilities, accumulate: true)
      Module.register_attribute(__MODULE__, :current_capability, persist: false)

      @before_compile PacketFlow.ActorCapability
    end
  end

  defmacro __before_compile__(env) do
    capabilities = Module.get_attribute(env.module, :actor_capabilities)

    quote do
      def __capabilities__, do: unquote(Macro.escape(capabilities))

      def list_capabilities do
        __capabilities__()
        |> Enum.map(fn cap ->
          %{
            id: cap.id,
            intent: cap.intent,
            requires: cap.requires,
            provides: cap.provides,
            effects: cap.effects,
            actor_enabled: true
          }
        end)
      end

      # Actor-specific functions
      def initial_actor_state(options \\ %{}) do
        # Return the initial state for the first capability
        # In a real implementation, this would be capability-specific
        case __capabilities__() do
          [cap | _] -> Map.get(cap, :initial_state, %{})
          [] -> %{}
        end
      end

      def handle_actor_message(message, context, current_state) do
        # Route message to appropriate handler based on capability configuration
        case __capabilities__() do
          [cap | _] ->
            if Map.get(cap, :message_handlers) == :defined do
              # Use the module's handle_actor_message implementation if it exists
              {:ok, %{handled: true}, current_state}
            else
              # Fallback to regular capability execution
              execute(message, context)
              |> case do
                {:ok, result} -> {:ok, result, current_state}
                {:error, reason} -> {:error, reason}
              end
            end

          [] ->
            {:error, :no_capabilities_defined}
        end
      end


    end
  end

  @doc """
  Define an actor capability with persistent state and message handling.
  """
  defmacro actor_capability(id, do: block) do
    quote do
      @current_capability %{
        id: unquote(id),
        intent: nil,
        requires: [],
        provides: [],
        effects: [],
        initial_state: %{},
        state_persistence: :memory,
        actor_timeout: :timer.minutes(30),
        message_handlers: nil
      }

      unquote(block)

      Module.put_attribute(__MODULE__, :actor_capabilities, @current_capability)
    end
  end

  @doc """
  Set the intent description for the capability.
  """
  defmacro intent(description) do
    quote do
      @current_capability Map.put(@current_capability, :intent, unquote(description))
    end
  end

  @doc """
  Define required input fields.
  """
  defmacro requires(fields) when is_list(fields) do
    quote do
      @current_capability Map.put(@current_capability, :requires, unquote(fields))
    end
  end

  @doc """
  Define provided output fields.
  """
  defmacro provides(fields) when is_list(fields) do
    quote do
      @current_capability Map.put(@current_capability, :provides, unquote(fields))
    end
  end

  @doc """
  Define side effects.
  """
  defmacro effect(type, opts \\ []) do
    quote do
      current_effects = Map.get(@current_capability, :effects, [])
      new_effect = {unquote(type), unquote(opts)}
      @current_capability Map.put(@current_capability, :effects, [new_effect | current_effects])
    end
  end

  @doc """
  Set the initial state for the actor.
  """
  defmacro initial_state(state) do
    quote do
      @current_capability Map.put(@current_capability, :initial_state, unquote(state))
    end
  end

  @doc """
  Set the state persistence strategy.
  """
  defmacro state_persistence(strategy) when strategy in [:memory, :disk, :distributed] do
    quote do
      @current_capability Map.put(@current_capability, :state_persistence, unquote(strategy))
    end
  end

  @doc """
  Set the actor timeout.
  """
  defmacro actor_timeout(timeout) do
    quote do
      @current_capability Map.put(@current_capability, :actor_timeout, unquote(timeout))
    end
  end

  @doc """
  Define message handlers for the actor.
  """
  defmacro handle_message(do: _block) do
    quote do
      # For now, we'll store a simple marker that handlers are defined
      # In a full implementation, this would parse pattern matching syntax
      @current_capability Map.put(@current_capability, :message_handlers, :defined)
    end
  end
end
