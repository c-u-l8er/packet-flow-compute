#!/usr/bin/env elixir

# Simple test script for PacketFlow MCP modules
# Tests the MCP modules directly without requiring the full application

# Ensure we're in the right directory
File.cd!(Path.dirname(__ENV__.file))

# Compile the project first
IO.puts("🔨 Compiling project...")
{result, output} = System.cmd("mix", ["compile", "--force"], cd: ".")

if result != 0 do
  IO.puts("❌ Compilation failed:")
  IO.puts(output)
  System.halt(1)
end

IO.puts("✅ Compilation successful")

# Load compiled modules
Code.append_path("_build/dev/lib/packetflow_chat/ebin")

# Basic module loading test
defmodule MCPModuleTest do
  def run_tests do
    IO.puts("\n🧪 Testing MCP Module Loading...")

    tests = [
      {"MCP Bridge Module", &test_mcp_bridge_module/0},
      {"MCP Tool Registry Module", &test_mcp_tool_registry_module/0},
      {"MCP Server Module", &test_mcp_server_module/0},
      {"MCP Actor Capability Module", &test_mcp_actor_capability_module/0}
    ]

    results = Enum.map(tests, fn {name, test_fn} ->
      IO.puts("Testing: #{name}")

      try do
        case test_fn.() do
          :ok ->
            IO.puts("✅ #{name} - PASSED")
            {name, :passed}
          {:error, reason} ->
            IO.puts("❌ #{name} - FAILED: #{inspect(reason)}")
            {name, {:failed, reason}}
        end
      rescue
        error ->
          IO.puts("💥 #{name} - ERROR: #{inspect(error)}")
          {name, {:error, error}}
      end
    end)

    print_summary(results)
  end

  def test_mcp_bridge_module do
    # Test that the module loads
    case Code.ensure_loaded(PacketFlow.MCPBridge) do
      {:module, _} ->
        IO.puts("  ✓ MCPBridge module loaded")

        # Test basic message validation
        valid_message = %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize"
        }

        case PacketFlow.MCPBridge.validate_mcp_message(valid_message) do
          {:ok, _} ->
            IO.puts("  ✓ Message validation working")
            :ok
          error ->
            {:error, "Message validation failed: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Failed to load MCPBridge: #{reason}"}
    end
  end

  def test_mcp_tool_registry_module do
    case Code.ensure_loaded(PacketFlow.MCPToolRegistry) do
      {:module, _} ->
        IO.puts("  ✓ MCPToolRegistry module loaded")

        # Test capability ID to tool name conversion
        test_id = :test_capability
        tool_name = PacketFlow.MCPToolRegistry.capability_id_to_tool_name(test_id)

        if tool_name == "test_capability" do
          IO.puts("  ✓ Tool name conversion working")
          :ok
        else
          {:error, "Tool name conversion failed"}
        end

      {:error, reason} ->
        {:error, "Failed to load MCPToolRegistry: #{reason}"}
    end
  end

  def test_mcp_server_module do
    case Code.ensure_loaded(PacketFlow.MCPServer) do
      {:module, _} ->
        IO.puts("  ✓ MCPServer module loaded")

        # Test default config generation
        config = PacketFlow.MCPServer.default_config()

        required_keys = [:port, :host, :transport, :capabilities]
        missing_keys = Enum.filter(required_keys, fn key ->
          not Map.has_key?(config, key)
        end)

        if length(missing_keys) == 0 do
          IO.puts("  ✓ Default config has all required keys")
          :ok
        else
          {:error, "Missing config keys: #{inspect(missing_keys)}"}
        end

      {:error, reason} ->
        {:error, "Failed to load MCPServer: #{reason}"}
    end
  end

  def test_mcp_actor_capability_module do
    case Code.ensure_loaded(PacketFlow.MCPActorCapability) do
      {:module, _} ->
        IO.puts("  ✓ MCPActorCapability module loaded")

        # Test that required functions exist
        required_functions = [
          {:execute_mcp_tool, 4},
          {:mcp_tool_available?, 2}
        ]

        missing_functions = Enum.filter(required_functions, fn {func, arity} ->
          not function_exported?(PacketFlow.MCPActorCapability, func, arity)
        end)

        if length(missing_functions) == 0 do
          IO.puts("  ✓ All required functions available")
          :ok
        else
          {:error, "Missing functions: #{inspect(missing_functions)}"}
        end

      {:error, reason} ->
        {:error, "Failed to load MCPActorCapability: #{reason}"}
    end
  end

  defp print_summary(results) do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("📊 MCP MODULE TEST SUMMARY")
    IO.puts(String.duplicate("=", 50))

    passed = Enum.count(results, fn {_, status} -> status == :passed end)
    total = length(results)
    failed = total - passed

    Enum.each(results, fn {name, status} ->
      case status do
        :passed ->
          IO.puts("✅ #{name}")
        {:failed, reason} ->
          IO.puts("❌ #{name} - #{inspect(reason)}")
        {:error, error} ->
          IO.puts("💥 #{name} - #{inspect(error)}")
      end
    end)

    IO.puts(String.duplicate("-", 50))
    IO.puts("📈 RESULTS: #{passed}/#{total} tests passed")

    if failed == 0 do
      IO.puts("🎉 ALL MCP MODULES LOADED SUCCESSFULLY!")
      IO.puts("Phase 3 MCP modules are ready.")
    else
      IO.puts("⚠️  #{failed} test(s) failed. Check compilation.")
    end

    IO.puts(String.duplicate("=", 50))
  end
end

# Run the tests
MCPModuleTest.run_tests()
