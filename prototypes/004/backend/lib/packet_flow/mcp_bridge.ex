defmodule PacketFlow.MCPBridge do
  @moduledoc """
  Model Context Protocol (MCP) Bridge for PacketFlow.

  This module implements the MCP protocol specification, enabling PacketFlow
  capabilities to be exposed as MCP tools and allowing external AI systems
  to discover and execute PacketFlow capabilities through the standard MCP protocol.

  ## MCP Protocol Support

  - JSON-RPC 2.0 message format
  - Tool discovery and execution
  - Resource management
  - Error handling and validation

  ## Example Usage

      # Handle MCP initialize request
      {:ok, response} = MCPBridge.handle_mcp_request(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "1.0.0",
          "capabilities" => %{"tools" => %{}}
        }
      }, context)

      # Handle tool list request
      {:ok, response} = MCPBridge.handle_mcp_request(%{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/list"
      }, context)
  """

  require Logger

  @mcp_version "1.0.0"
  @server_name "PacketFlow MCP Server"
  @server_version "1.0.0"

  # Note: This module provides MCP bridge functionality
  # In a full implementation, this would integrate with the capability system

  @doc """
  Handle incoming MCP protocol requests.

  Processes JSON-RPC 2.0 formatted MCP messages and routes them to appropriate handlers.
  """
  def handle_mcp_request(mcp_message, context) do
    Logger.info("Processing MCP request: #{inspect(mcp_message)}")

    case validate_mcp_message(mcp_message) do
      {:ok, validated_message} ->
        process_mcp_method(validated_message, context)

      {:error, reason} ->
        create_error_response(mcp_message["id"], -32600, "Invalid Request", reason)
    end
  rescue
    error ->
      Logger.error("MCP request processing failed: #{inspect(error)}")
      create_error_response(mcp_message["id"], -32603, "Internal error", inspect(error))
  end

  @doc """
  Validate MCP message format according to JSON-RPC 2.0 specification.
  """
  def validate_mcp_message(message) when is_map(message) do
    with {:ok, _} <- validate_jsonrpc_version(message),
         {:ok, _} <- validate_method(message),
         {:ok, _} <- validate_id(message) do
      {:ok, message}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_mcp_message(_), do: {:error, "Message must be a map"}

  defp validate_jsonrpc_version(%{"jsonrpc" => "2.0"}), do: {:ok, :valid}
  defp validate_jsonrpc_version(_), do: {:error, "Missing or invalid jsonrpc version"}

  defp validate_method(%{"method" => method}) when is_binary(method), do: {:ok, :valid}
  defp validate_method(_), do: {:error, "Missing or invalid method"}

  defp validate_id(%{"id" => id}) when is_integer(id) or is_binary(id), do: {:ok, :valid}
  defp validate_id(_), do: {:ok, :notification}  # Notifications don't require ID

  @doc """
  Process MCP method calls and route to appropriate handlers.
  """
  def process_mcp_method(%{"method" => method} = message, context) do
    case method do
      "initialize" ->
        handle_initialize(message, context)

      "tools/list" ->
        handle_tools_list(message, context)

      "tools/call" ->
        handle_tool_call(message, context)

      "resources/list" ->
        handle_resources_list(message, context)

      "resources/read" ->
        handle_resource_read(message, context)

      unknown_method ->
        create_error_response(message["id"], -32601, "Method not found", unknown_method)
    end
  end

  @doc """
  Handle MCP initialize request.
  """
  def handle_initialize(%{"id" => id, "params" => params}, _context) do
    Logger.info("MCP client initializing with params: #{inspect(params)}")

    response_data = %{
      "protocolVersion" => @mcp_version,
      "capabilities" => %{
        "tools" => %{
          "listChanged" => true
        },
        "resources" => %{
          "subscribe" => true,
          "listChanged" => true
        }
      },
      "serverInfo" => %{
        "name" => @server_name,
        "version" => @server_version
      }
    }

    create_success_response(id, response_data)
  end

  def handle_initialize(%{"id" => id}, _context) do
    create_error_response(id, -32602, "Invalid params", "Missing initialization parameters")
  end

  @doc """
  Handle tools/list request - returns all available PacketFlow capabilities as MCP tools.
  """
  def handle_tools_list(%{"id" => id}, _context) do
    Logger.info("Generating MCP tools list from PacketFlow capabilities")

    tools = PacketFlow.MCPToolRegistry.generate_mcp_tools()

    response_data = %{
      "tools" => tools
    }

    create_success_response(id, response_data)
  end

  @doc """
  Handle tools/call request - execute a PacketFlow capability via MCP.
  """
  def handle_tool_call(%{"id" => id, "params" => params}, context) do
    with {:ok, tool_name} <- extract_tool_name(params),
         {:ok, arguments} <- extract_tool_arguments(params),
         {:ok, capability_id} <- resolve_capability_id(tool_name),
         {:ok, result} <- execute_capability(capability_id, arguments, context) do

      response_data = %{
        "content" => [
          %{
            "type" => "text",
            "text" => format_tool_result(result)
          }
        ],
        "isError" => false
      }

      create_success_response(id, response_data)
    else
      {:error, reason} ->
        create_error_response(id, -32602, "Tool execution failed", reason)
    end
  end

  def handle_tool_call(%{"id" => id}, _context) do
    create_error_response(id, -32602, "Invalid params", "Missing tool call parameters")
  end

  @doc """
  Handle resources/list request - return available PacketFlow resources.
  """
  def handle_resources_list(%{"id" => id}, _context) do
    Logger.info("Generating MCP resources list")

    resources = [
      %{
        "uri" => "packetflow://capabilities",
        "name" => "PacketFlow Capabilities",
        "description" => "List of all available PacketFlow capabilities",
        "mimeType" => "application/json"
      },
      %{
        "uri" => "packetflow://actors",
        "name" => "PacketFlow Actors",
        "description" => "List of active PacketFlow actors",
        "mimeType" => "application/json"
      }
    ]

    response_data = %{
      "resources" => resources
    }

    create_success_response(id, response_data)
  end

  @doc """
  Handle resources/read request - read PacketFlow resource content.
  """
  def handle_resource_read(%{"id" => id, "params" => %{"uri" => uri}}, _context) do
    case uri do
      "packetflow://capabilities" ->
        capabilities = PacketFlow.CapabilityRegistry.list_all()
        content = Jason.encode!(capabilities, pretty: true)

        response_data = %{
          "contents" => [
            %{
              "uri" => uri,
              "mimeType" => "application/json",
              "text" => content
            }
          ]
        }

        create_success_response(id, response_data)

      "packetflow://actors" ->
        actors = PacketFlow.ActorSupervisor.list_active_actors()
        content = Jason.encode!(actors, pretty: true)

        response_data = %{
          "contents" => [
            %{
              "uri" => uri,
              "mimeType" => "application/json",
              "text" => content
            }
          ]
        }

        create_success_response(id, response_data)

      unknown_uri ->
        create_error_response(id, -32602, "Resource not found", unknown_uri)
    end
  end

  def handle_resource_read(%{"id" => id}, _context) do
    create_error_response(id, -32602, "Invalid params", "Missing resource URI")
  end

  # Private helper functions

  defp extract_tool_name(%{"name" => name}) when is_binary(name), do: {:ok, name}
  defp extract_tool_name(_), do: {:error, "Missing or invalid tool name"}

  defp extract_tool_arguments(%{"arguments" => args}) when is_map(args), do: {:ok, args}
  defp extract_tool_arguments(_), do: {:ok, %{}}

  defp resolve_capability_id(tool_name) do
    # Convert tool name back to capability ID (atom)
    try do
      capability_id = String.to_existing_atom(tool_name)
      {:ok, capability_id}
    rescue
      ArgumentError ->
        {:error, "Unknown tool: #{tool_name}"}
    end
  end

  defp execute_capability(capability_id, arguments, context) do
    case PacketFlow.CapabilityRegistry.execute(capability_id, arguments, context) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "Capability execution failed: #{inspect(reason)}"}
    end
  end

  defp format_tool_result(result) when is_map(result) do
    Jason.encode!(result, pretty: true)
  end

  defp format_tool_result(result) do
    inspect(result, pretty: true)
  end

  defp create_success_response(id, result) do
    {:ok, %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    }}
  end

  defp create_error_response(id, code, message, data \\ nil) do
    error = %{
      "code" => code,
      "message" => message
    }

    error = if data, do: Map.put(error, "data", data), else: error

    {:ok, %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => error
    }}
  end
end
