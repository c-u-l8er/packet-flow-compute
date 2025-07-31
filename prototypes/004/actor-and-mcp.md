# PacketFlow Layer 4: Actor Model + MCP Protocol Specification

**Version:** 1.0  
**Status:** Draft  
**Date:** 2025-07-31

## Overview

Layer 4 extends PacketFlow with stateful capability actors and Model Context Protocol (MCP) integration, enabling persistent conversations and AI tool execution through capabilities.

## Core Extensions

### 1. Actor Capability Definition

```elixir
actor_capability :capability_name do
  # Standard capability fields
  intent "Description"
  requires [:field1, :field2]
  provides [:result1, :result2]
  
  # Actor-specific fields
  initial_state %{key: value}
  state_persistence :memory | :disk | :distributed
  actor_timeout :timer.minutes(30)
  
  # Message handlers
  handle_message do
    pattern -> handler_function
  end
  
  # Periodic tasks
  handle_info message_pattern, state do
    # Handler implementation
  end
end
```

### 2. MCP Tool Integration

```elixir
mcp_capability :capability_name do
  intent "Description"
  
  # MCP tool definitions
  mcp_tools do
    tool :tool_name do
      description "Tool description"
      parameters [:param1, :param2]
      required [:param1]
    end
  end
  
  # Tool execution handler
  handle_tool_call fn tool_name, parameters, context ->
    # Tool implementation
  end
end
```

## Protocol Extensions

### Actor State Message

Extends base wire protocol with actor state management:

```json
{
  "version": "1.0",
  "type": "actor_message",
  "intent": "Interact with stateful capability actor",
  "capability_id": "research_assistant",
  "actor_id": "actor_12345",
  "payload": {
    "message": "What did we discuss about user retention?",
    "message_type": "conversation"
  },
  "context": {
    "user_id": "user_456",
    "session_id": "sess_abc",
    "trace_id": "trace_xyz",
    "timestamp": "2025-07-31T10:30:00Z"
  },
  "actor_options": {
    "create_if_missing": true,
    "state_timeout": 1800000,
    "persistence": "memory"
  }
}
```

### MCP Bridge Message

Enables MCP protocol tunneling through PacketFlow:

```json
{
  "version": "1.0", 
  "type": "mcp_request",
  "intent": "Execute MCP protocol request",
  "capability_id": "mcp_bridge",
  "payload": {
    "mcp_message": {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "tools/call",
      "params": {
        "name": "web_search",
        "arguments": {
          "query": "PacketFlow framework",
          "max_results": 5
        }
      }
    }
  },
  "context": {
    "user_id": "user_456",
    "session_id": "sess_abc", 
    "trace_id": "trace_xyz"
  }
}
```

## Actor Lifecycle Specification

### Actor Creation

1. **Actor Request**: Client sends message to actor capability
2. **Actor Lookup**: Registry checks if actor exists by `actor_id`
3. **Actor Spawn**: If missing and `create_if_missing: true`, spawn new actor
4. **State Initialize**: Load initial state or restore from persistence
5. **Message Route**: Route message to actor process

### Actor State Management

```elixir
# Actor state structure
%{
  actor_id: "unique_actor_identifier",
  capability_id: :capability_name,
  state: %{}, # Capability-specific state
  metadata: %{
    created_at: ~U[2025-07-31 10:00:00Z],
    last_message_at: ~U[2025-07-31 10:30:00Z],
    message_count: 42,
    persistence_strategy: :memory
  },
  timeout_ref: #Reference<...>
}
```

### Actor Termination

Actors terminate when:
- **Timeout**: No messages received within `actor_timeout`
- **Explicit Stop**: Capability sends `{:stop, reason}` 
- **System Shutdown**: Graceful shutdown with state persistence
- **Error**: Unhandled error causes supervised restart

## MCP Integration Specification

### MCP Server Generation

PacketFlow automatically generates MCP server from capabilities:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "name": "PacketFlow Capabilities",
    "version": "1.0.0",
    "capabilities": {
      "tools": {
        "listChanged": true
      },
      "resources": {
        "subscribe": true,
        "listChanged": true
      }
    }
  }
}
```

### Tool List Generation

```json
{
  "jsonrpc": "2.0", 
  "id": 2,
  "result": {
    "tools": [
      {
        "name": "user_transform",
        "description": "Transform user data with specified operations",
        "inputSchema": {
          "type": "object",
          "properties": {
            "user_id": {"type": "string"},
            "operations": {"type": "array"}
          },
          "required": ["user_id", "operations"]
        }
      }
    ]
  }
}
```

### Tool Execution

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "User transformation completed successfully"
      }
    ],
    "isError": false
  }
}
```

## Implementation Requirements

### Actor Registry Extension

Extend `PacketFlow.CapabilityRegistry` with actor management:

```elixir
# New GenServer functions
{:ok, actor_pid} = CapabilityRegistry.get_or_create_actor(capability_id, actor_id, options)
:ok = CapabilityRegistry.send_to_actor(actor_pid, message, context)
{:ok, state} = CapabilityRegistry.get_actor_state(actor_pid)
:ok = CapabilityRegistry.terminate_actor(actor_pid, reason)
```

### Actor Supervisor

New supervision tree for actor processes:

```elixir
# Dynamic supervisor for actor processes
{:ok, supervisor_pid} = DynamicSupervisor.start_link(
  name: PacketFlow.ActorSupervisor,
  strategy: :one_for_one
)

# Actor process specification
child_spec = %{
  id: {PacketFlow.ActorProcess, actor_id},
  start: {PacketFlow.ActorProcess, :start_link, [actor_config]},
  restart: :transient,
  shutdown: 5000
}
```

### MCP Bridge Implementation

Core MCP protocol bridge:

```elixir
defmodule PacketFlow.MCPBridge do
  @behaviour PacketFlow.Capability
  
  def handle_mcp_request(mcp_message, context) do
    case mcp_message["method"] do
      "initialize" -> handle_initialize(mcp_message, context)
      "tools/list" -> handle_tools_list(mcp_message, context) 
      "tools/call" -> handle_tool_call(mcp_message, context)
      "resources/list" -> handle_resources_list(mcp_message, context)
      "resources/read" -> handle_resource_read(mcp_message, context)
    end
  end
end
```

## Configuration

### Actor Configuration

```elixir
# config/config.exs
config :packet_flow, :actors,
  default_timeout: :timer.minutes(30),
  max_actors_per_user: 10,
  persistence_strategy: :memory,
  cleanup_interval: :timer.minutes(5)
```

### MCP Configuration

```elixir
# config/config.exs
config :packet_flow, :mcp,
  server_name: "PacketFlow Capabilities",
  server_version: "1.0.0",
  auto_generate_tools: true,
  expose_capabilities: :all, # or list of capability_ids
  tool_timeout: :timer.seconds(30)
```

## Error Handling

### Actor Errors

```json
{
  "version": "1.0",
  "type": "capability_error", 
  "capability_id": "research_assistant",
  "payload": {
    "error": {
      "type": "actor_timeout",
      "message": "Actor did not respond within timeout period",
      "details": {
        "actor_id": "actor_12345",
        "timeout_ms": 30000
      }
    }
  }
}
```

### MCP Errors

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "capability_error": "Missing required field: user_id"
    }
  }
}
```

## Migration Path

### Phase 1: Basic Actor Support
1. Extend capability macro with actor support
2. Implement actor process and supervisor
3. Add actor lifecycle management to registry
4. Basic message routing to actors

### Phase 2: MCP Integration  
1. Implement MCP bridge capability
2. Auto-generate MCP tools from capabilities
3. Handle MCP protocol messages
4. Add MCP server configuration

### Phase 3: Advanced Features
1. State persistence strategies
2. Actor clustering and distribution
3. Conversation memory and search
4. Performance optimization

## Compatibility

### Backward Compatibility
- Existing capabilities work unchanged
- New actor/MCP features are opt-in
- Wire protocol remains compatible
- No breaking changes to core APIs

### Forward Compatibility  
- Extensible actor state format
- Versioned MCP protocol support
- Pluggable persistence backends
- Configurable timeout strategies

## Security Considerations

### Actor Isolation
- Each actor runs in isolated process
- State is private to actor instance
- Cross-actor communication through registry only
- Resource limits per actor

### MCP Security
- Authentication required for MCP access
- Tool execution uses same authorization as capabilities
- Input validation on all MCP messages
- Rate limiting on tool calls

## Performance Characteristics

### Actor Performance
- **Actor Creation**: ~1ms per actor
- **Message Routing**: ~0.1ms per message
- **Memory Usage**: ~50KB per actor (varies by state size)
- **Cleanup Overhead**: ~0.01ms per actor per cleanup cycle

### MCP Performance
- **Tool Discovery**: ~1ms for capability list generation
- **Tool Execution**: Same as underlying capability + ~0.5ms overhead
- **Protocol Overhead**: ~10% additional latency vs direct capability calls

## Testing Strategy

### Actor Testing
```elixir
defmodule ActorCapabilityTest do
  use ExUnit.Case
  use PacketFlow.ActorTest
  
  test "actor maintains state between messages" do
    {:ok, actor} = start_test_actor(:research_assistant)
    
    send_actor_message(actor, %{query: "What is Elixir?"})
    assert_actor_state_contains(actor, :conversation_history)
    
    send_actor_message(actor, %{query: "Tell me more"})
    state = get_actor_state(actor)
    assert length(state.conversation_history) == 2
  end
end
```

### MCP Testing
```elixir
defmodule MCPIntegrationTest do
  use ExUnit.Case
  use PacketFlow.MCPTest
  
  test "MCP tool call executes capability" do
    mcp_request = mcp_tool_call("user_transform", %{user_id: "123"})
    
    {:ok, response} = execute_mcp_request(mcp_request)
    
    assert response["result"]["isError"] == false
    assert response["result"]["content"]
  end
end
```

This specification provides the foundation for implementing Layer 4 while maintaining PacketFlow's core principles of simplicity, observability, and distributed execution.
