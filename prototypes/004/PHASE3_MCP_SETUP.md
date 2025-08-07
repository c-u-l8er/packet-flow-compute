# PacketFlow Phase 3 - MCP Protocol Integration Setup Guide

## Overview

Phase 3 of PacketFlow development adds **Model Context Protocol (MCP)** integration, transforming PacketFlow into an industry-standard AI tool platform that can connect with any MCP-compatible AI system.

### What's New in Phase 3

- 🚧 **MCP Bridge**: Expose PacketFlow capabilities as MCP tools
- 🚧 **Tool Discovery**: Automatic MCP tool generation from capabilities  
- 🚧 **Cross-System Integration**: Connect with Claude Desktop, VS Code, and other MCP clients
- 🚧 **Enhanced Actor Integration**: MCP-aware stateful actors
- 🚧 **Frontend MCP Interface**: Native MCP tool execution in the chat UI

## Phase 1 & 2 Foundation ✅

Before implementing Phase 3, ensure you have the working foundation:

### ✅ Phase 1: Actor Model (COMPLETED)
```bash
# Verify actor system is working
cd backend && mix run test_actor_system.exs
```

Expected output:
- ✅ Actor creation and messaging
- ✅ Stateful conversations with memory
- ✅ Actor lifecycle management
- ✅ Multiple concurrent actors

### ✅ Phase 2: AI Integration (COMPLETED)  
```bash
# Verify AI capabilities are working
curl -X POST http://localhost:4000/api/ai/natural \
  -H "Content-Type: application/json" \
  -d '{"message": "What capabilities are available?"}'
```

Expected response:
- Natural language processing working
- Capability discovery functional
- AI plan generation active

## Phase 3 Implementation Plan

### 1. MCP Bridge Infrastructure

#### Core MCP Components
```elixir
# New modules to implement:
- PacketFlow.MCPBridge          # Core MCP protocol handler
- PacketFlow.MCPServer          # MCP server implementation  
- PacketFlow.MCPToolRegistry    # Auto-generate tools from capabilities
- PacketFlow.MCPTransport       # Handle MCP message transport
```

#### MCP Protocol Messages
```json
// Tool discovery
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "result": {
    "tools": [
      {
        "name": "send_message",
        "description": "Send a message to a chat room with AI insights",
        "inputSchema": {
          "type": "object",
          "properties": {
            "room_id": {"type": "string"},
            "content": {"type": "string"},
            "user_id": {"type": "string"}
          }
        }
      }
    ]
  }
}
```

### 2. Actor-MCP Integration

#### MCP-Aware Actors
```elixir
mcp_actor_capability :persistent_chat_agent do
  intent "AI chat agent with MCP tool access"
  requires [:message, :user_id]
  provides [:response, :tool_executions, :conversation_state]
  
  # MCP tools this actor can use
  mcp_tools [
    :web_search,
    :code_execution,
    :file_operations
  ]
  
  # Handle MCP tool responses
  handle_mcp_response do
    tool_result -> integrate_with_conversation(tool_result, state)
  end
end
```

### 3. Enhanced Frontend Integration

#### MCP Tool Interface
```typescript
// New frontend components
interface MCPTool {
  name: string;
  description: string;
  inputSchema: JSONSchema;
  category: 'chat' | 'analysis' | 'automation';
}

interface MCPExecution {
  tool_name: string;
  parameters: Record<string, any>;
  result: any;
  execution_time: number;
}
```

## Implementation Steps

### Step 1: MCP Bridge Foundation

1. **Create MCP Bridge Module**
```bash
# Create the core MCP bridge
touch backend/lib/packet_flow/mcp_bridge.ex
```

2. **Implement MCP Protocol Handler**
```elixir
defmodule PacketFlow.MCPBridge do
  @behaviour PacketFlow.Capability
  
  def handle_mcp_request(mcp_message, context) do
    case mcp_message["method"] do
      "initialize" -> handle_initialize(mcp_message, context)
      "tools/list" -> handle_tools_list(mcp_message, context)
      "tools/call" -> handle_tool_call(mcp_message, context)
    end
  end
end
```

### Step 2: Tool Registry Enhancement

1. **Auto-Generate MCP Tools**
```elixir
defmodule PacketFlow.MCPToolRegistry do
  def generate_mcp_tools do
    PacketFlow.CapabilityRegistry.list_all()
    |> Enum.map(&capability_to_mcp_tool/1)
  end
  
  defp capability_to_mcp_tool(capability) do
    %{
      name: Atom.to_string(capability.id),
      description: capability.intent,
      inputSchema: generate_schema(capability.requires)
    }
  end
end
```

### Step 3: Actor-MCP Integration

1. **Extend Actor Capability Macro**
```elixir
defmacro mcp_actor_capability(id, do: block) do
  quote do
    # Combine actor capabilities with MCP tool access
    @current_capability Map.put(@current_capability, :mcp_enabled, true)
    unquote(block)
  end
end
```

### Step 4: Frontend MCP Interface

1. **MCP Tool Discovery Component**
```svelte
<!-- MCPToolExplorer.svelte -->
<script>
  import { onMount } from 'svelte';
  
  let mcpTools = [];
  let selectedTool = null;
  
  onMount(async () => {
    const response = await fetch('/api/mcp/tools');
    mcpTools = await response.json();
  });
</script>

<div class="mcp-tool-explorer">
  <h3>🔧 Available MCP Tools</h3>
  {#each mcpTools as tool}
    <div class="tool-card" on:click={() => selectedTool = tool}>
      <h4>{tool.name}</h4>
      <p>{tool.description}</p>
    </div>
  {/each}
</div>
```

## Testing Strategy

### 1. MCP Protocol Compliance
```bash
# Test MCP protocol messages
curl -X POST http://localhost:4000/api/mcp/request \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

### 2. Actor-MCP Integration
```bash
# Test MCP-aware actors
mix run -e "
  {:ok, _} = PacketFlow.send_to_actor(:mcp_chat_agent, \"user123\", %{
    message: \"Use web search to find recent AI news\",
    mcp_tools_enabled: true
  })
"
```

### 3. Cross-System Integration
```bash
# Test with Claude Desktop (requires MCP client setup)
# 1. Configure Claude Desktop to connect to PacketFlow MCP server
# 2. Verify tool discovery works
# 3. Execute PacketFlow capabilities from Claude
```

## Configuration

### MCP Server Configuration
```elixir
# config/config.exs
config :packet_flow, :mcp,
  server_name: "PacketFlow MCP Server",
  server_version: "1.0.0",
  port: 8080,
  transport: :stdio,  # or :websocket
  capabilities: [
    tools: %{listChanged: true},
    resources: %{subscribe: true}
  ]
```

### Actor MCP Integration
```elixir
config :packet_flow, :actors,
  mcp_enabled: true,
  mcp_timeout: :timer.seconds(30),
  default_mcp_tools: [:web_search, :code_execution]
```

## API Endpoints

### New MCP Endpoints
- `POST /api/mcp/request` - Handle MCP protocol messages
- `GET /api/mcp/tools` - List available MCP tools
- `POST /api/mcp/tools/:name/execute` - Execute specific MCP tool
- `GET /api/mcp/capabilities` - MCP server capabilities
- `WebSocket /api/mcp/ws` - MCP WebSocket transport

### Enhanced Actor Endpoints
- `POST /api/actors/:id/mcp` - Send MCP-enabled message to actor
- `GET /api/actors/:id/mcp/tools` - List actor's available MCP tools
- `POST /api/actors/:id/mcp/execute` - Execute MCP tool through actor

## Integration Examples

### 1. Claude Desktop Integration
```json
// claude_desktop_config.json
{
  "mcpServers": {
    "packetflow": {
      "command": "curl",
      "args": ["-X", "POST", "http://localhost:4000/api/mcp/request"],
      "env": {
        "PACKETFLOW_API_KEY": "your_api_key"
      }
    }
  }
}
```

### 2. VS Code Extension Integration
```typescript
// VS Code extension using PacketFlow MCP tools
const mcpClient = new MCPClient('http://localhost:4000/api/mcp');

const tools = await mcpClient.listTools();
const result = await mcpClient.executeTool('analyze_conversation', {
  room_id: 'current_workspace',
  message_count: 100
});
```

### 3. Custom AI Agent Integration
```python
# Python AI agent using PacketFlow MCP server
import requests

def call_packetflow_tool(tool_name, parameters):
    response = requests.post('http://localhost:4000/api/mcp/request', json={
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": parameters
        },
        "id": 1
    })
    return response.json()

# Use PacketFlow capabilities from any AI system
result = call_packetflow_tool('send_message', {
    'room_id': 'ai_workspace',
    'content': 'Hello from external AI agent!',
    'user_id': 'ai_agent_001'
})
```

## Success Metrics

Phase 3 is successful when you can:

1. 🎯 **MCP Protocol Compliance**: PacketFlow responds correctly to all MCP messages
2. 🎯 **Tool Discovery**: External AI systems can discover PacketFlow capabilities
3. 🎯 **Cross-System Execution**: Execute PacketFlow capabilities from Claude Desktop, VS Code, etc.
4. 🎯 **Actor-MCP Integration**: Actors can use external MCP tools and be used as MCP tools
5. 🎯 **Frontend Integration**: Chat interface shows MCP tool executions and results

## Troubleshooting

### Common Issues

1. **MCP Protocol Errors**
   - Verify JSON-RPC 2.0 message format
   - Check required fields in MCP messages
   - Validate tool schemas match capability contracts

2. **Cross-System Connection Issues**
   - Ensure MCP server is accessible on configured port
   - Check firewall settings for MCP transport
   - Verify authentication tokens are valid

3. **Actor-MCP Integration Problems**
   - Confirm actors have MCP capabilities enabled
   - Check MCP tool timeout configurations
   - Verify external MCP tools are accessible

### Debug Commands
```bash
# Test MCP server directly
curl -X POST http://localhost:4000/api/mcp/request \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1}'

# Check MCP tool registry
mix run -e "IO.inspect(PacketFlow.MCPToolRegistry.list_tools())"

# Test actor MCP integration
mix run -e "PacketFlow.send_to_actor(:mcp_test_actor, \"user1\", %{message: \"test\"})"
```

## Next Steps (Phase 4)

After Phase 3 MCP integration:

1. **Intelligence Modules**: AI planning and reasoning modules
2. **Spatial Arenas**: Game-like environments for capability interaction  
3. **Performance Optimization**: Caching, load balancing, clustering
4. **Ecosystem Integration**: Cross-organizational capability sharing

## Benefits of Phase 3

### For AI Systems
- **Universal Tool Access**: Any MCP-compatible AI can use PacketFlow capabilities
- **Persistent Context**: Actors provide memory across tool executions
- **Intelligent Composition**: Capabilities can be chained automatically

### For Developers  
- **Industry Standard**: MCP protocol ensures compatibility with major AI platforms
- **Ecosystem Access**: Connect to growing MCP tool ecosystem
- **Future-Proof**: Foundation for autonomous AI agent systems

### For Organizations
- **AI Integration**: Seamlessly connect internal capabilities with AI systems
- **Scalable Architecture**: Actor model handles concurrent AI interactions
- **Observable Operations**: Full telemetry for AI tool usage

**Phase 3 transforms PacketFlow from a capability framework into a universal AI tool platform** 🚀

The MCP integration creates a bridge between PacketFlow's intelligent capability system and the broader AI ecosystem, enabling any AI system to discover, use, and compose PacketFlow capabilities through industry-standard protocols.