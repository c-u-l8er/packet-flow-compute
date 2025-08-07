defmodule PacketflowChatWeb.MCPController do
  @moduledoc """
  Controller for handling MCP (Model Context Protocol) requests.

  This controller provides HTTP endpoints for MCP protocol communication,
  enabling external AI systems to interact with PacketFlow capabilities
  through standard MCP messages.

  ## Endpoints

  - `POST /api/mcp/request` - Handle MCP protocol messages
  - `GET /api/mcp/tools` - List available MCP tools
  - `POST /api/mcp/tools/:name/execute` - Execute specific MCP tool
  - `GET /api/mcp/capabilities` - Get MCP server capabilities
  - `GET /api/mcp/server-info` - Get MCP server information
  """

  use PacketflowChatWeb, :controller
  require Logger

  @doc """
  Handle MCP protocol requests.

  Processes JSON-RPC 2.0 formatted MCP messages and returns appropriate responses.
  """
  def request(conn, params) do
    context = build_request_context(conn)

    case PacketFlow.MCPServer.handle_request(params, context) do
      {:ok, response} ->
        conn
        |> put_status(:ok)
        |> json(response)

      {:error, reason} ->
        Logger.error("MCP request failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          "jsonrpc" => "2.0",
          "id" => params["id"],
          "error" => %{
            "code" => -32603,
            "message" => "Internal error",
            "data" => inspect(reason)
          }
        })
    end
  end

  @doc """
  List available MCP tools.

  Returns all PacketFlow capabilities formatted as MCP tools.
  """
  def list_tools(conn, _params) do
    tools = PacketFlow.MCPToolRegistry.generate_mcp_tools()

    conn
    |> put_status(:ok)
    |> json(%{
      "tools" => tools,
      "count" => length(tools)
    })
  end

  @doc """
  Execute a specific MCP tool.

  Executes a PacketFlow capability through the MCP tool interface.
  """
  def execute_tool(conn, %{"name" => tool_name} = params) do
    context = build_request_context(conn)
    arguments = Map.get(params, "arguments", %{})

    # Create MCP tool call message
    mcp_message = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => "tools/call",
      "params" => %{
        "name" => tool_name,
        "arguments" => arguments
      }
    }

    case PacketFlow.MCPBridge.handle_mcp_request(mcp_message, context) do
      {:ok, response} ->
        conn
        |> put_status(:ok)
        |> json(response)

      {:error, reason} ->
        Logger.error("Tool execution failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          "error" => "Tool execution failed",
          "reason" => inspect(reason),
          "tool_name" => tool_name
        })
    end
  end

  @doc """
  Get MCP server capabilities.

  Returns the capabilities supported by the PacketFlow MCP server.
  """
  def capabilities(conn, _params) do
    capabilities = %{
      "tools" => %{
        "listChanged" => true
      },
      "resources" => %{
        "subscribe" => true,
        "listChanged" => true
      }
    }

    conn
    |> put_status(:ok)
    |> json(%{
      "capabilities" => capabilities,
      "protocolVersion" => "1.0.0"
    })
  end

  @doc """
  Get MCP server information.

  Returns information about the PacketFlow MCP server instance.
  """
  def server_info(conn, _params) do
    case PacketFlow.MCPServer.server_info() do
      info when is_map(info) ->
        conn
        |> put_status(:ok)
        |> json(info)

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          "error" => "MCP server not available",
          "reason" => inspect(reason)
        })
    end
  end

  @doc """
  Get MCP server statistics.

  Returns operational statistics for the MCP server.
  """
  def stats(conn, _params) do
    case PacketFlow.MCPServer.stats() do
      stats when is_map(stats) ->
        conn
        |> put_status(:ok)
        |> json(stats)

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          "error" => "MCP server statistics not available",
          "reason" => inspect(reason)
        })
    end
  end

  @doc """
  Health check endpoint for MCP server.
  """
  def health(conn, _params) do
    # Check if MCP server is running
    case GenServer.whereis(PacketFlow.MCPServer) do
      nil ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          "status" => "unhealthy",
          "message" => "MCP server not running"
        })

      _pid ->
        conn
        |> put_status(:ok)
        |> json(%{
          "status" => "healthy",
          "message" => "MCP server operational",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  # Private helper functions

  defp build_request_context(conn) do
    %{
      user_id: get_user_id(conn),
      session_id: get_session_id(conn),
      trace_id: generate_trace_id(),
      timestamp: DateTime.utc_now(),
      remote_ip: get_remote_ip(conn),
      user_agent: get_user_agent(conn)
    }
  end

  defp get_user_id(conn) do
    # Extract user ID from authentication context
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> nil
    end
  end

  defp get_session_id(conn) do
    # Extract session ID from connection
    case get_session(conn, :session_id) do
      nil -> generate_session_id()
      session_id -> session_id
    end
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
  end

  defp get_remote_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded_ip | _] -> forwarded_ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "unknown"
    end
  end
end
