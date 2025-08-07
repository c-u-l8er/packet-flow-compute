defmodule PacketFlow.MCPServer do
  @moduledoc """
  MCP (Model Context Protocol) Server implementation for PacketFlow.

  This module provides a complete MCP server implementation that exposes
  PacketFlow capabilities as MCP tools, enabling integration with external
  AI systems like Claude Desktop, VS Code extensions, and other MCP clients.

  ## Features

  - JSON-RPC 2.0 protocol support
  - HTTP and WebSocket transport
  - Automatic tool discovery from PacketFlow capabilities
  - Resource management and access
  - Error handling and validation
  - Request/response logging and metrics

  ## Usage

      # Start MCP server
      {:ok, pid} = MCPServer.start_link(port: 8080)

      # Process MCP request
      {:ok, response} = MCPServer.handle_request(request_body, context)
  """

  use GenServer
  require Logger

  @default_port 8080
  @default_host "localhost"
  @server_info %{
    "name" => "PacketFlow MCP Server",
    "version" => "1.0.0"
  }

  # Client API

  @doc """
  Start the MCP server.

  ## Options

  - `:port` - Server port (default: 8080)
  - `:host` - Server host (default: "localhost")
  - `:transport` - Transport type (:http or :websocket, default: :http)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Handle an MCP request.

  Processes a raw MCP request and returns the appropriate response.
  """
  def handle_request(request_body, context \\ %{}) do
    GenServer.call(__MODULE__, {:handle_request, request_body, context})
  end

  @doc """
  Get server information.
  """
  def server_info do
    GenServer.call(__MODULE__, :server_info)
  end

  @doc """
  Get server statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Stop the MCP server.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, @default_port)
    host = Keyword.get(opts, :host, @default_host)
    transport = Keyword.get(opts, :transport, :http)

    state = %{
      port: port,
      host: host,
      transport: transport,
      started_at: DateTime.utc_now(),
      request_count: 0,
      error_count: 0,
      connected_clients: MapSet.new()
    }

    Logger.info("Starting PacketFlow MCP Server on #{host}:#{port} with #{transport} transport")

    {:ok, state}
  end

  @impl true
  def handle_call({:handle_request, request_body, context}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result = process_request(request_body, context)

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Update statistics
    new_state = update_stats(state, result, duration)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:server_info, _from, state) do
    info = Map.merge(@server_info, %{
      "host" => state.host,
      "port" => state.port,
      "transport" => state.transport,
      "started_at" => DateTime.to_iso8601(state.started_at),
      "uptime_seconds" => DateTime.diff(DateTime.utc_now(), state.started_at)
    })

    {:reply, info, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      "request_count" => state.request_count,
      "error_count" => state.error_count,
      "connected_clients" => MapSet.size(state.connected_clients),
      "uptime_seconds" => DateTime.diff(DateTime.utc_now(), state.started_at),
      "error_rate" => calculate_error_rate(state)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:client_connected, client_id}, state) do
    new_clients = MapSet.put(state.connected_clients, client_id)
    Logger.info("MCP client connected: #{client_id}")

    {:noreply, %{state | connected_clients: new_clients}}
  end

  @impl true
  def handle_info({:client_disconnected, client_id}, state) do
    new_clients = MapSet.delete(state.connected_clients, client_id)
    Logger.info("MCP client disconnected: #{client_id}")

    {:noreply, %{state | connected_clients: new_clients}}
  end

  # Private functions

  defp process_request(request_body, context) when is_binary(request_body) do
    case Jason.decode(request_body) do
      {:ok, request_data} ->
        process_mcp_message(request_data, context)

      {:error, %Jason.DecodeError{} = error} ->
        Logger.error("Invalid JSON in MCP request: #{inspect(error)}")
        create_parse_error()
    end
  end

  defp process_request(request_data, context) when is_map(request_data) do
    process_mcp_message(request_data, context)
  end

  defp process_request(invalid_request, _context) do
    Logger.error("Invalid MCP request format: #{inspect(invalid_request)}")
    create_invalid_request_error()
  end

  defp process_mcp_message(request_data, context) do
    Logger.debug("Processing MCP message: #{inspect(request_data)}")

    # Add server context
    enhanced_context = Map.merge(context, %{
      server_info: @server_info,
      timestamp: DateTime.utc_now()
    })

    # Use MCPBridge to handle the actual MCP protocol
    case PacketFlow.MCPBridge.handle_mcp_request(request_data, enhanced_context) do
      {:ok, response} ->
        Logger.debug("MCP request successful: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("MCP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp update_stats(state, result, duration) do
    new_request_count = state.request_count + 1

    new_error_count = case result do
      {:error, _} -> state.error_count + 1
      _ -> state.error_count
    end

    # Log performance metrics
    Logger.debug("MCP request processed in #{duration}ms")

    %{state |
      request_count: new_request_count,
      error_count: new_error_count
    }
  end

  defp calculate_error_rate(%{request_count: 0}), do: 0.0

  defp calculate_error_rate(%{error_count: error_count, request_count: request_count}) do
    Float.round(error_count / request_count * 100, 2)
  end

  defp create_parse_error do
    {:ok, %{
      "jsonrpc" => "2.0",
      "id" => nil,
      "error" => %{
        "code" => -32700,
        "message" => "Parse error",
        "data" => "Invalid JSON format"
      }
    }}
  end

  defp create_invalid_request_error do
    {:ok, %{
      "jsonrpc" => "2.0",
      "id" => nil,
      "error" => %{
        "code" => -32600,
        "message" => "Invalid Request",
        "data" => "Request must be a JSON object"
      }
    }}
  end

  # Public utility functions

  @doc """
  Create a new MCP server configuration.
  """
  def default_config do
    %{
      port: @default_port,
      host: @default_host,
      transport: :http,
      capabilities: %{
        tools: %{listChanged: true},
        resources: %{subscribe: true, listChanged: true}
      },
      server_info: @server_info
    }
  end

  @doc """
  Validate MCP server configuration.
  """
  def validate_config(config) when is_map(config) do
    required_keys = [:port, :host, :transport]

    case Enum.find(required_keys, &(not Map.has_key?(config, &1))) do
      nil ->
        {:ok, config}

      missing_key ->
        {:error, "Missing required configuration key: #{missing_key}"}
    end
  end

  def validate_config(_), do: {:error, "Configuration must be a map"}

  @doc """
  Get the current server configuration.
  """
  def get_config do
    case GenServer.whereis(__MODULE__) do
      nil ->
        {:error, "MCP server not started"}

      _pid ->
        info = server_info()
        {:ok, %{
          port: info["port"],
          host: info["host"],
          transport: info["transport"]
        }}
    end
  end
end
