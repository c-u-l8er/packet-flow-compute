#!/usr/bin/env elixir

# Test script for PacketFlow MCP (Model Context Protocol) integration
#
# This script validates that Phase 3 MCP integration is working correctly:
# - MCP Bridge handles protocol messages
# - MCP Tool Registry generates tools from capabilities
# - MCP Server processes requests
# - Actor-MCP integration works
# - API endpoints respond correctly

# Ensure we're in the right directory and can load the application
File.cd!(Path.dirname(__ENV__.file))

# Add the current directory to the code path
Code.append_path("_build/dev/lib/packetflow_chat/ebin")
Code.append_path("_build/dev/lib/packet_flow/ebin")

# Compile the project first
IO.puts("🔨 Compiling project...")
{result, _} = System.cmd("mix", ["compile"], cd: ".")

if result != 0 do
  IO.puts("❌ Compilation failed. Please run 'mix compile' first.")
  System.halt(1)
end

# Load dependencies
Mix.start()
Mix.env(:dev)

# Load the application
Application.put_env(:packetflow_chat, :environment, :test)

# Ensure all dependencies are loaded
deps = [:crypto, :ssl, :inets, :jason, :plug, :cowboy, :phoenix, :ecto, :postgrex]
Enum.each(deps, fn dep ->
  case Application.ensure_all_started(dep) do
    {:ok, _} -> :ok
    {:error, _} -> :ok  # Some deps might not be needed
  end
end)

# Start the application
IO.puts("🚀 Starting PacketFlow application...")
case Application.ensure_all_started(:packetflow_chat) do
  {:ok, _} ->
    IO.puts("✅ Application started successfully")
  {:error, reason} ->
    IO.puts("❌ Failed to start application: #{inspect(reason)}")
    IO.puts("Please ensure the application is compiled with 'mix compile'")
    System.halt(1)
end

# Give the system time to fully start
Process.sleep(3000)

defmodule MCPIntegrationTest do
  require Logger

  def run_all_tests do
    Logger.info("🧪 Starting PacketFlow MCP Integration Tests")

    tests = [
      {"MCP Bridge Protocol Handling", &test_mcp_bridge_protocol/0},
      {"MCP Tool Registry Generation", &test_mcp_tool_registry/0},
      {"MCP Server Request Processing", &test_mcp_server_requests/0},
      {"MCP API Endpoints", &test_mcp_api_endpoints/0},
      {"Actor MCP Integration", &test_actor_mcp_integration/0},
      {"MCP Cross-System Compatibility", &test_mcp_compatibility/0}
    ]

    results = Enum.map(tests, fn {name, test_fn} ->
      Logger.info("Running test: #{name}")

      try do
        case test_fn.() do
          :ok ->
            Logger.info("✅ #{name} - PASSED")
            {name, :passed}
          {:error, reason} ->
            Logger.error("❌ #{name} - FAILED: #{inspect(reason)}")
            {name, {:failed, reason}}
        end
      rescue
        error ->
          Logger.error("❌ #{name} - ERROR: #{inspect(error)}")
          {name, {:error, error}}
      end
    end)

    print_summary(results)
  end

  def test_mcp_bridge_protocol do
    Logger.info("Testing MCP Bridge protocol message handling...")

    # Test initialize request
    initialize_message = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "1.0.0",
        "capabilities" => %{"tools" => %{}}
      }
    }

    case PacketFlow.MCPBridge.handle_mcp_request(initialize_message, %{}) do
      {:ok, response} ->
        assert_field(response, "jsonrpc", "2.0")
        assert_field(response, "id", 1)
        assert_has_key(response, "result")
        Logger.info("  ✓ Initialize request handled correctly")

      error ->
        return {:error, "Initialize request failed: #{inspect(error)}"}
    end

    # Test tools/list request
    tools_list_message = %{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/list"
    }

    case PacketFlow.MCPBridge.handle_mcp_request(tools_list_message, %{}) do
      {:ok, response} ->
        assert_field(response, "jsonrpc", "2.0")
        assert_field(response, "id", 2)
        assert_has_key(response, "result")
        assert_has_key(response["result"], "tools")
        Logger.info("  ✓ Tools list request handled correctly")

      error ->
        return {:error, "Tools list request failed: #{inspect(error)}"}
    end

    # Test invalid request
    invalid_message = %{
      "method" => "invalid_method"
      # Missing jsonrpc and id
    }

    case PacketFlow.MCPBridge.handle_mcp_request(invalid_message, %{}) do
      {:ok, response} ->
        assert_has_key(response, "error")
        Logger.info("  ✓ Invalid request handled with error response")

      error ->
        return {:error, "Invalid request handling failed: #{inspect(error)}"}
    end

    :ok
  end

  def test_mcp_tool_registry do
    Logger.info("Testing MCP Tool Registry...")

    # Test tool generation from capabilities
    tools = PacketFlow.MCPToolRegistry.generate_mcp_tools()

    if length(tools) == 0 do
      return {:error, "No MCP tools generated from capabilities"}
    end

    Logger.info("  ✓ Generated #{length(tools)} MCP tools from capabilities")

    # Test individual tool structure
    first_tool = List.first(tools)

    required_fields = ["name", "description", "inputSchema"]
    Enum.each(required_fields, fn field ->
      if not Map.has_key?(first_tool, field) do
        throw {:error, "Tool missing required field: #{field}"}
      end
    end)

    Logger.info("  ✓ Tool structure validation passed")

    # Test tool name conversion
    test_capability_id = :test_capability
    tool_name = PacketFlow.MCPToolRegistry.capability_id_to_tool_name(test_capability_id)

    if tool_name != "test_capability" do
      return {:error, "Tool name conversion failed"}
    end

    Logger.info("  ✓ Tool name conversion working")

    :ok
  end

  def test_mcp_server_requests do
    Logger.info("Testing MCP Server request processing...")

    # Test server info
    case PacketFlow.MCPServer.server_info() do
      info when is_map(info) ->
        required_info = ["name", "version", "host", "port"]
        Enum.each(required_info, fn field ->
          if not Map.has_key?(info, field) do
            throw {:error, "Server info missing field: #{field}"}
          end
        end)
        Logger.info("  ✓ Server info retrieved successfully")

      error ->
        return {:error, "Server info failed: #{inspect(error)}"}
    end

    # Test request handling
    test_request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list"
    }

    case PacketFlow.MCPServer.handle_request(test_request, %{}) do
      {:ok, response} ->
        assert_field(response, "jsonrpc", "2.0")
        Logger.info("  ✓ Request handling working")

      error ->
        return {:error, "Request handling failed: #{inspect(error)}"}
    end

    # Test server stats
    case PacketFlow.MCPServer.stats() do
      stats when is_map(stats) ->
        expected_stats = ["request_count", "error_count", "uptime_seconds"]
        Enum.each(expected_stats, fn stat ->
          if not Map.has_key?(stats, stat) do
            throw {:error, "Server stats missing: #{stat}"}
          end
        end)
        Logger.info("  ✓ Server statistics available")

      error ->
        return {:error, "Server stats failed: #{inspect(error)}"}
    end

    :ok
  end

  def test_mcp_api_endpoints do
    Logger.info("Testing MCP API endpoints...")

    # Note: These would normally require HTTP requests to test properly
    # For now, we'll test the controller functions directly

    # Test that the MCP controller module exists and has required functions
    required_functions = [
      {:request, 2},
      {:list_tools, 2},
      {:execute_tool, 2},
      {:capabilities, 2},
      {:server_info, 2},
      {:health, 2}
    ]

    Enum.each(required_functions, fn {function, arity} ->
      if not function_exported?(PacketflowChatWeb.MCPController, function, arity) do
        throw {:error, "MCP controller missing function: #{function}/#{arity}"}
      end
    end)

    Logger.info("  ✓ MCP controller functions available")

    # Test route configuration exists (basic check)
    routes = PacketflowChatWeb.Router.__routes__()
    mcp_routes = Enum.filter(routes, fn route ->
      String.contains?(route.path, "/mcp/")
    end)

    if length(mcp_routes) == 0 do
      return {:error, "No MCP routes found in router"}
    end

    Logger.info("  ✓ MCP routes configured (#{length(mcp_routes)} routes)")

    :ok
  end

  def test_actor_mcp_integration do
    Logger.info("Testing Actor MCP integration...")

    # Test that MCP actor capability module exists
    if not Code.ensure_loaded?(PacketFlow.MCPActorCapability) do
      return {:error, "MCPActorCapability module not available"}
    end

    Logger.info("  ✓ MCP Actor Capability module loaded")

    # Test basic actor creation with MCP capability
    actor_id = "test_mcp_actor_#{System.unique_integer()}"

    case PacketFlow.ActorSupervisor.start_actor(:test_actor_capability, actor_id) do
      {:ok, actor_pid} ->
        Logger.info("  ✓ MCP-capable actor created successfully")

        # Test actor info retrieval
        case GenServer.call(actor_pid, :get_info) do
          info when is_map(info) ->
            Logger.info("  ✓ Actor info retrieved: #{inspect(info)}")

          error ->
            return {:error, "Actor info retrieval failed: #{inspect(error)}"}
        end

        # Clean up
        PacketFlow.ActorSupervisor.terminate_actor(actor_pid)
        Logger.info("  ✓ Actor cleaned up")

      error ->
        return {:error, "Actor creation failed: #{inspect(error)}"}
    end

    :ok
  end

  def test_mcp_compatibility do
    Logger.info("Testing MCP cross-system compatibility...")

    # Test MCP message format compliance
    test_messages = [
      # Valid initialize message
      %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => "1.0.0"}
      },
      # Valid tools/call message
      %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => "test_tool",
          "arguments" => %{"param1" => "value1"}
        }
      }
    ]

    Enum.each(test_messages, fn message ->
      case PacketFlow.MCPBridge.validate_mcp_message(message) do
        {:ok, _} ->
          Logger.info("  ✓ Message validation passed for #{message["method"]}")

        error ->
          throw {:error, "Message validation failed for #{message["method"]}: #{inspect(error)}"}
      end
    end)

    # Test error response format
    error_response = PacketFlow.MCPBridge.handle_mcp_request(%{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "nonexistent_method"
    }, %{})

    case error_response do
      {:ok, response} ->
        if Map.has_key?(response, "error") do
          Logger.info("  ✓ Error response format correct")
        else
          return {:error, "Error response missing 'error' field"}
        end

      error ->
        return {:error, "Error response handling failed: #{inspect(error)}"}
    end

    :ok
  end

  # Helper functions
  defp assert_field(map, key, expected_value) do
    case Map.get(map, key) do
      ^expected_value -> :ok
      actual -> throw {:error, "Expected #{key} to be #{inspect(expected_value)}, got #{inspect(actual)}"}
    end
  end

  defp assert_has_key(map, key) do
    if Map.has_key?(map, key) do
      :ok
    else
      throw {:error, "Expected map to have key #{inspect(key)}"}
    end
  end

  defp print_summary(results) do
    Logger.info("\n" <> String.duplicate("=", 60))
    Logger.info("📊 MCP INTEGRATION TEST SUMMARY")
    Logger.info(String.duplicate("=", 60))

    passed = Enum.count(results, fn {_, status} -> status == :passed end)
    total = length(results)
    failed = total - passed

    Enum.each(results, fn {name, status} ->
      case status do
        :passed ->
          Logger.info("✅ #{name}")
        {:failed, reason} ->
          Logger.error("❌ #{name} - #{inspect(reason)}")
        {:error, error} ->
          Logger.error("💥 #{name} - #{inspect(error)}")
      end
    end)

    Logger.info(String.duplicate("-", 60))
    Logger.info("📈 RESULTS: #{passed}/#{total} tests passed")

    if failed == 0 do
      Logger.info("🎉 ALL MCP INTEGRATION TESTS PASSED!")
      Logger.info("Phase 3 MCP integration is working correctly.")
    else
      Logger.error("⚠️  #{failed} test(s) failed. Please review the errors above.")
    end

    Logger.info(String.duplicate("=", 60))
  end
end

# Run the tests
MCPIntegrationTest.run_all_tests()
