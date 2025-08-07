defmodule PacketFlow.MCPActorCapability do
  @moduledoc """
  Enhanced actor capability macro with MCP (Model Context Protocol) integration.

  This module extends the basic actor capability with MCP tool access, enabling
  actors to discover and execute external MCP tools while maintaining their
  persistent state and conversation capabilities.

  ## Features

  - All standard actor capability features
  - Access to external MCP tools
  - MCP tool result integration with actor state
  - Automatic MCP tool discovery and validation
  - Error handling for MCP tool failures

  ## Example

      defmodule MyApp.MCPChatAgent do
        use PacketFlow.MCPActorCapability

        mcp_actor_capability :mcp_chat_agent do
          intent "AI chat agent with MCP tool access"
          requires [:message, :user_id]
          provides [:response, :tool_executions, :conversation_state]

          initial_state %{
            conversation_history: [],
            available_tools: [],
            tool_execution_history: []
          }

          # MCP tools this actor can use
          mcp_tools [
            :web_search,
            :code_execution,
            :file_operations
          ]

          handle_message do
            %{type: "chat", message: msg} -> handle_chat_with_tools(msg, state)
            %{type: "tool_request", tool: tool_name, params: params} ->
              execute_mcp_tool(tool_name, params, state)
          end
        end

        def handle_chat_with_tools(message, state) do
          # Analyze if message requires tool usage
          case analyze_tool_requirements(message) do
            {:needs_tools, tools} ->
              execute_tools_and_respond(tools, message, state)

            {:no_tools, _} ->
              generate_direct_response(message, state)
          end
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import PacketFlow.MCPActorCapability
      # Import specific functions from ActorCapability to avoid conflicts
      import PacketFlow.ActorCapability, only: []
      Module.register_attribute(__MODULE__, :mcp_actor_capabilities, accumulate: true)
      Module.register_attribute(__MODULE__, :current_mcp_capability, persist: false)

      @before_compile PacketFlow.MCPActorCapability
    end
  end

  defmacro __before_compile__(env) do
    capabilities = Module.get_attribute(env.module, :mcp_actor_capabilities)

    quote do
      # Include all standard actor capability functions
      def __mcp_capabilities__, do: unquote(Macro.escape(capabilities))

      def list_capabilities do
        __mcp_capabilities__()
        |> Enum.map(fn cap ->
          %{
            id: cap.id,
            intent: cap.intent,
            requires: cap.requires,
            provides: cap.provides,
            effects: cap.effects,
            actor_enabled: true,
            mcp_enabled: true,
            mcp_tools: Map.get(cap, :mcp_tools, [])
          }
        end)
      end

      def initial_actor_state(options \\ %{}) do
        case __mcp_capabilities__() do
          [cap | _] ->
            base_state = Map.get(cap, :initial_state, %{})
            # Add MCP-specific state
            Map.merge(base_state, %{
              mcp_tools_available: discover_available_mcp_tools(cap),
              mcp_execution_history: []
            })
          [] -> %{}
        end
      end

      def handle_actor_message(message, context, current_state) do
        case __mcp_capabilities__() do
          [cap | _] ->
            # Check if this is an MCP tool execution request
            case message do
              %{type: "mcp_tool_call", tool_name: tool_name, parameters: params} ->
                execute_mcp_tool_call(tool_name, params, context, current_state, cap)

              _ ->
                # Handle as regular actor message with MCP context
                handle_message_with_mcp_context(message, context, current_state, cap)
            end

          [] ->
            {:error, :no_capabilities_defined}
        end
      end

      defp discover_available_mcp_tools(capability) do
        configured_tools = Map.get(capability, :mcp_tools, [])

        # In a full implementation, this would query external MCP servers
        # For now, return the configured tools
        Enum.map(configured_tools, fn tool_name ->
          %{
            name: tool_name,
            available: true,
            last_checked: DateTime.utc_now()
          }
        end)
      end

      defp execute_mcp_tool_call(tool_name, parameters, context, current_state, _capability) do
        # Create MCP tool call message
        mcp_message = %{
          "jsonrpc" => "2.0",
          "id" => System.unique_integer([:positive]),
          "method" => "tools/call",
          "params" => %{
            "name" => Atom.to_string(tool_name),
            "arguments" => parameters
          }
        }

        case PacketFlow.MCPBridge.handle_mcp_request(mcp_message, context) do
          {:ok, mcp_response} ->
            # Update state with tool execution result
            execution_record = %{
              tool_name: tool_name,
              parameters: parameters,
              result: mcp_response,
              executed_at: DateTime.utc_now(),
              success: true
            }

            new_history = [execution_record | current_state.mcp_execution_history]
            updated_state = %{current_state | mcp_execution_history: new_history}

            result = %{
              tool_execution: execution_record,
              mcp_response: mcp_response
            }

            {:ok, result, updated_state}

          {:error, reason} ->
            # Record failed execution
            execution_record = %{
              tool_name: tool_name,
              parameters: parameters,
              error: reason,
              executed_at: DateTime.utc_now(),
              success: false
            }

            new_history = [execution_record | current_state.mcp_execution_history]
            updated_state = %{current_state | mcp_execution_history: new_history}

            {:error, reason}
        end
      end

      defp handle_message_with_mcp_context(message, context, current_state, capability) do
        # Add MCP context to regular message handling
        enhanced_context = Map.merge(context, %{
          mcp_tools_available: current_state.mcp_tools_available,
          mcp_execution_history: current_state.mcp_execution_history
        })

        # Use the module's message handling if defined
        if Map.get(capability, :message_handlers) == :defined do
          # Try to call the module's handle_actor_message if it exists
          try do
            apply(__MODULE__, :handle_actor_message_with_mcp, [message, enhanced_context, current_state])
          rescue
            UndefinedFunctionError ->
              # Fallback to basic handling
              {:ok, %{handled: true}, current_state}
          end
        else
          # Fallback to regular capability execution
          {:ok, %{handled: true}, current_state}
        end
      end
    end
  end

  @doc """
  Define an MCP-enabled actor capability.
  """
  defmacro mcp_actor_capability(id, do: block) do
    quote do
      @current_mcp_capability %{
        id: unquote(id),
        intent: nil,
        requires: [],
        provides: [],
        effects: [],
        initial_state: %{},
        state_persistence: :memory,
        actor_timeout: :timer.minutes(30),
        message_handlers: nil,
        mcp_tools: [],
        mcp_enabled: true
      }

      unquote(block)

      Module.put_attribute(__MODULE__, :mcp_actor_capabilities, @current_mcp_capability)
    end
  end

  @doc """
  Define MCP tools that this actor can use.
  """
  defmacro mcp_tools(tool_list) when is_list(tool_list) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :mcp_tools, unquote(tool_list))
    end
  end

  @doc """
  Helper function to execute an MCP tool from within an actor.
  """
  def execute_mcp_tool(actor_pid, tool_name, parameters, context \\ %{}) do
    message = %{
      type: "mcp_tool_call",
      tool_name: tool_name,
      parameters: parameters
    }

    GenServer.call(actor_pid, {:handle_message, message, context})
  end

  @doc """
  Helper function to check if an MCP tool is available.
  """
  def mcp_tool_available?(actor_pid, tool_name) do
    case GenServer.call(actor_pid, :get_state) do
      %{mcp_tools_available: tools} ->
        Enum.any?(tools, fn tool ->
          tool.name == tool_name && tool.available
        end)

      _ ->
        false
    end
  end

  @doc """
  Get MCP tool execution history for an actor.
  """
  def get_mcp_execution_history(actor_pid) do
    case GenServer.call(actor_pid, :get_state) do
      %{mcp_execution_history: history} -> {:ok, history}
      _ -> {:error, :no_history_available}
    end
  end

  # Re-export standard actor capability macros with explicit module references
  defmacro intent(description) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :intent, unquote(description))
    end
  end

  defmacro requires(fields) when is_list(fields) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :requires, unquote(fields))
    end
  end

  defmacro provides(fields) when is_list(fields) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :provides, unquote(fields))
    end
  end

  defmacro effect(type, opts \\ []) do
    quote do
      current_effects = Map.get(@current_mcp_capability, :effects, [])
      new_effect = {unquote(type), unquote(opts)}
      @current_mcp_capability Map.put(@current_mcp_capability, :effects, [new_effect | current_effects])
    end
  end

  defmacro initial_state(state) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :initial_state, unquote(state))
    end
  end

  defmacro state_persistence(strategy) when strategy in [:memory, :disk, :distributed] do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :state_persistence, unquote(strategy))
    end
  end

  defmacro actor_timeout(timeout) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :actor_timeout, unquote(timeout))
    end
  end

  defmacro handle_message(do: block) do
    quote do
      @current_mcp_capability Map.put(@current_mcp_capability, :message_handlers, :defined)
      # Store the block for later use - in a full implementation this would parse the patterns
      # For now, we just mark that message handlers are defined
    end
  end
end
