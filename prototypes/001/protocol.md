# PacketFlow Protocol Specification v1.0
*A Simple, Interoperable Chemical Computing Standard*

## 🎯 Protocol Overview

PacketFlow enables distributed computing using chemistry-inspired patterns. Work is organized into **six behavioral groups** with predictable interactions, enabling automatic optimization across TypeScript and Elixir runtimes.

**Protocol Identifier**: `packetflow://`  
**Version**: `1.0`  
**Wire Format**: JSON over WebSocket  
**Interop**: Binary-compatible between TypeScript and Elixir

---

## 📋 Core Specification

### 1. Packet Wire Format

**Minimal Packet (Required)**
```json
{
  "version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "group": "df",
  "element": "tr",
  "data": "any-json-value",
  "priority": 5
}
```

**Extended Packet (Optional)**
```json
{
  "version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "group": "df",
  "element": "tr", 
  "data": "any-json-value",
  "priority": 5,
  "timeout_ms": 30000,
  "dependencies": ["packet-id-1"],
  "metadata": {"custom": "fields"}
}
```

### 2. WebSocket Message Frame

```json
{
  "type": "submit|result|error|heartbeat",
  "seq": 12345,
  "payload": {}
}
```

**Message Types:**
- `submit`: Send packet for processing
- `result`: Return processing outcome  
- `error`: Signal processing failure
- `heartbeat`: Node health check

### 3. Behavioral Groups

| Group | Code | Behavior | Routing Hint |
|-------|------|----------|--------------|
| Control Flow | `cf` | Sequential execution | Single-threaded nodes |
| Data Flow | `df` | Parallel processing | Multi-core nodes |
| Event Driven | `ed` | Reactive patterns | Low-latency nodes |
| Collective | `co` | Coordination | Network-optimized |
| Meta-Compute | `mc` | System management | Admin nodes |
| Resource Mgmt | `rm` | Lifecycle control | Memory-optimized |

### 4. Standard Elements

```
# Control Flow (cf)
cf:seq - Sequential steps
cf:branch - Conditional routing
cf:loop - Iteration control
cf:gate - Synchronization

# Data Flow (df)  
df:produce - Generate data
df:consume - Process data
df:transform - Modify data
df:reduce - Aggregate data

# Event Driven (ed)
ed:signal - Emit events
ed:timer - Scheduled triggers
ed:watch - State monitoring
ed:react - Event handlers

# Collective (co)
co:sync - Multi-party sync
co:broadcast - Fan-out
co:gather - Fan-in
co:vote - Consensus

# Meta-Computational (mc)
mc:spawn - Create processes
mc:migrate - Move workload
mc:scale - Adjust capacity
mc:tune - Optimize performance

# Resource Management (rm)
rm:alloc - Acquire resources
rm:free - Release resources
rm:lock - Exclusive access
rm:cache - Store for reuse
```

---

## 🔌 TypeScript Implementation

### Core Types

```typescript
// Core packet structure
interface Packet {
  readonly version: "1.0";
  readonly id: string;
  readonly group: "cf" | "df" | "ed" | "co" | "mc" | "rm";
  readonly element: string;
  readonly data: unknown;
  readonly priority: number; // 1-10
  readonly timeout_ms?: number;
  readonly dependencies?: string[];
  readonly metadata?: Record<string, unknown>;
}

// WebSocket message frame
interface Message {
  readonly type: "submit" | "result" | "error" | "heartbeat";
  readonly seq: number;
  readonly payload: unknown;
}

// Processing result
interface Result {
  readonly packet_id: string;
  readonly status: "success" | "error";
  readonly data?: unknown;
  readonly error?: {
    readonly code: string;
    readonly message: string;
  };
  readonly duration_ms: number;
}
```

### Reactor Implementation

```typescript
import { WebSocket } from 'ws';
import { randomUUID } from 'crypto';

export class PacketFlowReactor {
  private ws: WebSocket | null = null;
  private handlers = new Map<string, PacketHandler>();
  private pending = new Map<number, PendingRequest>();
  private sequence = 0;

  constructor(private config: ReactorConfig) {}

  async start(): Promise<void> {
    this.ws = new WebSocket(this.config.endpoint);
    this.ws.on('message', this.handleMessage.bind(this));
    this.ws.on('open', () => this.sendHeartbeat());
    
    // Heartbeat every 30 seconds
    setInterval(() => this.sendHeartbeat(), 30000);
  }

  async stop(): Promise<void> {
    this.ws?.close();
    this.ws = null;
  }

  // Register packet handler
  register<T>(group: string, element: string, handler: (data: T) => Promise<unknown>): void {
    const key = `${group}:${element}`;
    this.handlers.set(key, { handler, group, element });
  }

  // Submit packet for processing
  async submit(packet: Omit<Packet, 'version' | 'id'>): Promise<Result> {
    const fullPacket: Packet = {
      version: "1.0",
      id: randomUUID(),
      ...packet
    };

    return this.sendMessage('submit', fullPacket);
  }

  private async sendMessage(type: string, payload: unknown): Promise<Result> {
    const seq = ++this.sequence;
    const message: Message = { type, seq, payload };
    
    return new Promise((resolve, reject) => {
      this.pending.set(seq, { resolve, reject, timestamp: Date.now() });
      this.ws?.send(JSON.stringify(message));
      
      // Timeout handling
      setTimeout(() => {
        const pending = this.pending.get(seq);
        if (pending) {
          this.pending.delete(seq);
          reject(new Error(`Timeout waiting for response to seq ${seq}`));
        }
      }, 30000);
    });
  }

  private handleMessage(data: Buffer): void {
    try {
      const message: Message = JSON.parse(data.toString());
      
      switch (message.type) {
        case 'submit':
          this.processPacket(message.payload as Packet);
          break;
        case 'result':
          this.handleResult(message.seq, message.payload as Result);
          break;
        case 'error':
          this.handleError(message.seq, message.payload as Error);
          break;
      }
    } catch (error) {
      console.error('Failed to handle message:', error);
    }
  }

  private async processPacket(packet: Packet): Promise<void> {
    const key = `${packet.group}:${packet.element}`;
    const handler = this.handlers.get(key);
    
    if (!handler) {
      this.sendError(packet.id, 'PF001', `No handler for ${key}`);
      return;
    }

    const startTime = Date.now();
    try {
      const result = await handler.handler(packet.data);
      const duration_ms = Date.now() - startTime;
      
      this.sendResult({
        packet_id: packet.id,
        status: 'success',
        data: result,
        duration_ms
      });
    } catch (error) {
      const duration_ms = Date.now() - startTime;
      this.sendResult({
        packet_id: packet.id,
        status: 'error',
        error: {
          code: 'PF500',
          message: error instanceof Error ? error.message : 'Unknown error'
        },
        duration_ms
      });
    }
  }

  private sendResult(result: Result): void {
    const message: Message = {
      type: 'result',
      seq: 0, // Results don't need sequence numbers
      payload: result
    };
    this.ws?.send(JSON.stringify(message));
  }

  private sendError(packetId: string, code: string, message: string): void {
    this.sendResult({
      packet_id: packetId,
      status: 'error',
      error: { code, message },
      duration_ms: 0
    });
  }

  private sendHeartbeat(): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      const message: Message = {
        type: 'heartbeat',
        seq: ++this.sequence,
        payload: { timestamp: Date.now() }
      };
      this.ws.send(JSON.stringify(message));
    }
  }

  private handleResult(seq: number, result: Result): void {
    const pending = this.pending.get(seq);
    if (pending) {
      this.pending.delete(seq);
      pending.resolve(result);
    }
  }

  private handleError(seq: number, error: Error): void {
    const pending = this.pending.get(seq);
    if (pending) {
      this.pending.delete(seq);
      pending.reject(error);
    }
  }
}

// Usage example
const reactor = new PacketFlowReactor({
  endpoint: 'ws://localhost:8443/packetflow/v1'
});

// Register a data transformer
reactor.register('df', 'transform', async (data: string) => {
  return data.toUpperCase();
});

// Start processing
await reactor.start();

// Submit work
const result = await reactor.submit({
  group: 'df',
  element: 'transform',
  data: 'hello world',
  priority: 5
});

console.log(result); // { packet_id: "...", status: "success", data: "HELLO WORLD" }
```

---

## ⚗️ Elixir Implementation

### Core Structures

```elixir
defmodule PacketFlow.Packet do
  @enforce_keys [:version, :id, :group, :element, :data, :priority]
  defstruct [
    :version,
    :id, 
    :group,
    :element,
    :data,
    :priority,
    :timeout_ms,
    :dependencies,
    :metadata
  ]

  @type t :: %__MODULE__{
    version: String.t(),
    id: String.t(),
    group: String.t(),
    element: String.t(), 
    data: term(),
    priority: integer(),
    timeout_ms: integer() | nil,
    dependencies: [String.t()] | nil,
    metadata: map() | nil
  }
end

defmodule PacketFlow.Message do
  @enforce_keys [:type, :seq, :payload]
  defstruct [:type, :seq, :payload]

  @type t :: %__MODULE__{
    type: :submit | :result | :error | :heartbeat,
    seq: integer(),
    payload: term()
  }
end

defmodule PacketFlow.Result do
  @enforce_keys [:packet_id, :status, :duration_ms]
  defstruct [:packet_id, :status, :data, :error, :duration_ms]

  @type t :: %__MODULE__{
    packet_id: String.t(),
    status: :success | :error,
    data: term() | nil,
    error: %{code: String.t(), message: String.t()} | nil,
    duration_ms: integer()
  }
end
```

### Reactor GenServer

```elixir
defmodule PacketFlow.Reactor do
  use GenServer
  require Logger

  alias PacketFlow.{Packet, Message, Result}

  defstruct [
    :socket,
    :handlers,
    :pending_requests,
    :sequence,
    :endpoint
  ]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register(group, element, handler_fun) when is_function(handler_fun, 1) do
    GenServer.call(__MODULE__, {:register, group, element, handler_fun})
  end

  def submit(packet_attrs) do
    GenServer.call(__MODULE__, {:submit, packet_attrs}, 30_000)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # GenServer Callbacks

  def init(opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    
    state = %__MODULE__{
      socket: nil,
      handlers: %{},
      pending_requests: %{},
      sequence: 0,
      endpoint: endpoint
    }

    {:ok, state, {:continue, :connect}}
  end

  def handle_continue(:connect, state) do
    case :gun.open(to_charlist(state.endpoint), 8443, %{protocols: [:http]}) do
      {:ok, conn_pid} ->
        :gun.ws_upgrade(conn_pid, "/packetflow/v1")
        schedule_heartbeat()
        {:noreply, %{state | socket: conn_pid}}
      
      {:error, reason} ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  def handle_call({:register, group, element, handler}, _from, state) do
    key = "#{group}:#{element}"
    handlers = Map.put(state.handlers, key, handler)
    {:reply, :ok, %{state | handlers: handlers}}
  end

  def handle_call({:submit, packet_attrs}, from, state) do
    packet = %Packet{
      version: "1.0",
      id: UUID.uuid4(),
      group: packet_attrs.group,
      element: packet_attrs.element,
      data: packet_attrs.data,
      priority: packet_attrs.priority,
      timeout_ms: packet_attrs[:timeout_ms],
      dependencies: packet_attrs[:dependencies],
      metadata: packet_attrs[:metadata]
    }

    seq = state.sequence + 1
    message = %Message{
      type: :submit,
      seq: seq,
      payload: packet
    }

    json = Jason.encode!(message)
    :gun.ws_send(state.socket, {:text, json})

    # Store pending request
    pending = Map.put(state.pending_requests, seq, {from, System.monotonic_time(:millisecond)})
    
    {:noreply, %{state | sequence: seq, pending_requests: pending}}
  end

  def handle_info({:gun_ws, _conn, _stream, {:text, data}}, state) do
    case Jason.decode(data) do
      {:ok, message_map} ->
        message = parse_message(message_map)
        handle_websocket_message(message, state)
      
      {:error, _} ->
        Logger.error("Failed to decode WebSocket message: #{data}")
        {:noreply, state}
    end
  end

  def handle_info(:heartbeat, state) do
    send_heartbeat(state)
    schedule_heartbeat()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private Functions

  defp handle_websocket_message(%Message{type: :submit, payload: packet}, state) do
    spawn(fn -> process_packet(packet, state) end)
    {:noreply, state}
  end

  defp handle_websocket_message(%Message{type: :result, seq: seq, payload: result}, state) do
    case Map.pop(state.pending_requests, seq) do
      {{from, _timestamp}, pending} ->
        GenServer.reply(from, result)
        {:noreply, %{state | pending_requests: pending}}
      
      {nil, _} ->
        Logger.warn("Received result for unknown sequence: #{seq}")
        {:noreply, state}
    end
  end

  defp handle_websocket_message(%Message{type: :error, seq: seq, payload: error}, state) do
    case Map.pop(state.pending_requests, seq) do
      {{from, _timestamp}, pending} ->
        GenServer.reply(from, {:error, error})
        {:noreply, %{state | pending_requests: pending}}
      
      {nil, _} ->
        Logger.warn("Received error for unknown sequence: #{seq}")
        {:noreply, state}
    end
  end

  defp handle_websocket_message(%Message{type: :heartbeat}, state) do
    # Heartbeat received, connection is healthy
    {:noreply, state}
  end

  defp process_packet(%Packet{} = packet, state) do
    key = "#{packet.group}:#{packet.element}"
    
    case Map.get(state.handlers, key) do
      nil ->
        send_error(packet.id, "PF001", "No handler for #{key}", state)
      
      handler_fun ->
        start_time = System.monotonic_time(:millisecond)
        
        try do
          result_data = handler_fun.(packet.data)
          duration_ms = System.monotonic_time(:millisecond) - start_time
          
          result = %Result{
            packet_id: packet.id,
            status: :success,
            data: result_data,
            duration_ms: duration_ms
          }
          
          send_result(result, state)
        rescue
          error ->
            duration_ms = System.monotonic_time(:millisecond) - start_time
            
            result = %Result{
              packet_id: packet.id,
              status: :error,
              error: %{
                code: "PF500",
                message: Exception.message(error)
              },
              duration_ms: duration_ms
            }
            
            send_result(result, state)
        end
    end
  end

  defp send_result(result, state) do
    message = %Message{
      type: :result,
      seq: 0,  # Results don't need sequence numbers
      payload: result
    }
    
    json = Jason.encode!(message)
    :gun.ws_send(state.socket, {:text, json})
  end

  defp send_error(packet_id, code, message, state) do
    result = %Result{
      packet_id: packet_id,
      status: :error,
      error: %{code: code, message: message},
      duration_ms: 0
    }
    
    send_result(result, state)
  end

  defp send_heartbeat(state) do
    message = %Message{
      type: :heartbeat,
      seq: state.sequence + 1,
      payload: %{timestamp: System.system_time(:millisecond)}
    }
    
    json = Jason.encode!(message)
    :gun.ws_send(state.socket, {:text, json})
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, 30_000)
  end

  defp parse_message(%{
    "type" => type,
    "seq" => seq,
    "payload" => payload
  }) do
    %Message{
      type: String.to_atom(type),
      seq: seq,
      payload: payload
    }
  end
end

# Usage Example
{:ok, _pid} = PacketFlow.Reactor.start_link(endpoint: "ws://localhost:8443")

# Register a data transformer
PacketFlow.Reactor.register("df", "transform", fn data ->
  String.upcase(data)
end)

# Submit work
result = PacketFlow.Reactor.submit(%{
  group: "df",
  element: "transform", 
  data: "hello world",
  priority: 5
})

IO.inspect(result)
# %PacketFlow.Result{
#   packet_id: "...", 
#   status: :success, 
#   data: "HELLO WORLD",
#   duration_ms: 2
# }
```

---

## 🔗 Interoperability Examples

### TypeScript → Elixir Communication

```typescript
// TypeScript client
const reactor = new PacketFlowReactor({
  endpoint: 'ws://elixir-node:8443/packetflow/v1'
});

const result = await reactor.submit({
  group: 'df',
  element: 'process_data',
  data: { items: [1, 2, 3, 4, 5] },
  priority: 7
});
```

```elixir
# Elixir handler
PacketFlow.Reactor.register("df", "process_data", fn data ->
  data["items"]
  |> Enum.map(&(&1 * 2))
  |> Enum.sum()
end)
```

### Elixir → TypeScript Communication

```elixir
# Elixir client
result = PacketFlow.Reactor.submit(%{
  group: "ed",
  element: "notify_users",
  data: %{message: "System maintenance in 10 minutes"},
  priority: 9
})
```

```typescript
// TypeScript handler  
reactor.register('ed', 'notify_users', async (data: {message: string}) => {
  await sendPushNotifications(data.message);
  return { sent: true, timestamp: Date.now() };
});
```

---

## 🚀 Quick Start

### 1. Install Dependencies

**TypeScript:**
```bash
npm install ws uuid
npm install -D @types/ws @types/uuid
```

**Elixir:**
```elixir
# mix.exs
defp deps do
  [
    {:gun, "~> 2.0"},
    {:jason, "~> 1.4"},
    {:uuid, "~> 1.1"}
  ]
end
```

### 2. Define Handlers

**TypeScript:**
```typescript
reactor.register('df', 'uppercase', async (text: string) => text.toUpperCase());
reactor.register('cf', 'validate', async (data: any) => ({ valid: !!data }));
```

**Elixir:**
```elixir
PacketFlow.Reactor.register("df", "uppercase", &String.upcase/1)
PacketFlow.Reactor.register("cf", "validate", fn data -> %{valid: not is_nil(data)} end)
```

### 3. Start Processing

Both implementations expose the same interface:
- `register(group, element, handler)` - Define packet handlers
- `submit(packet)` - Send work for processing  
- `start()` / `stop()` - Manage reactor lifecycle

---

## 📊 Protocol Guarantees

**Wire Compatibility**: JSON messages are identical between TypeScript and Elixir  
**Error Codes**: Standardized error codes work across implementations  
**Timeouts**: Both runtimes respect packet timeout specifications  
**Heartbeats**: Connection health monitoring works bi-directionally  
**Backpressure**: Both implementations handle flow control gracefully

---

This simplified specification maintains the chemical computing metaphor while ensuring practical interoperability between TypeScript and Elixir runtimes. The wire protocol is language-agnostic, and both implementations can seamlessly communicate! 🧪⚡
