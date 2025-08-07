# PacketFlow

PacketFlow is an Elixir library that provides a domain-specific language (DSL) for building intent-context-capability oriented systems. It offers a clean, declarative approach to modeling complex domain logic with capability-based security, context propagation, and reactor pattern integration.

## Features

- **DSL Macros**: Rich domain-specific language for rapid development
- **Capability-Based Security**: Fine-grained permission control with implication hierarchies
- **Context Propagation**: Automatic context management with propagation strategies
- **Reactor Pattern**: Stateful message processing with effect system integration
- **Simple Abstractions**: Easy-to-use macros for common patterns
- **Registry Integration**: Component discovery and management
- **Production Ready**: Comprehensive testing, error handling, and documentation

## Installation

Add PacketFlow to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:packetflow, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
defmodule MyApp do
  use PacketFlow.DSL

  # Define capabilities with implications
  defsimple_capability UserCap, [:basic, :admin] do
    @implications [
      {UserCap.admin, [UserCap.basic]}
    ]
  end

  # Define context with propagation strategy
  defsimple_context UserContext, [:user_id, :capabilities] do
    @propagation_strategy :inherit
  end

  # Define intents with capability requirements
  defsimple_intent IncrementIntent, [:user_id] do
    @capabilities [UserCap.basic]
    @effect CounterEffect.increment
  end

  defsimple_intent ResetIntent, [:user_id] do
    @capabilities [UserCap.admin]
    @effect CounterEffect.reset
  end

  # Define reactor with state management
  defsimple_reactor CounterReactor, [:count] do
    def process_intent(intent, state) do
      case intent do
        %IncrementIntent{} ->
          new_state = %{state | count: state.count + 1}
          {:ok, new_state, []}
        %ResetIntent{} ->
          new_state = %{state | count: 0}
          {:ok, new_state, []}
        _ ->
          {:error, :unsupported_intent}
      end
    end
  end

  # Define effects
  defmodule CounterEffect do
    def increment(intent) do
      IO.puts("Incrementing counter for user: #{intent.user_id}")
      {:ok, :incremented}
    end

    def reset(intent) do
      IO.puts("Resetting counter for user: #{intent.user_id}")
      {:ok, :reset}
    end
  end
end
```

## Usage

### Basic DSL Macros

PacketFlow provides several DSL macros for common patterns:

#### Simple Capabilities

```elixir
defsimple_capability FileCap, [:read, :write, :admin] do
  @implications [
    {FileCap.admin, [FileCap.read, FileCap.write]},
    {FileCap.write, [FileCap.read]}
  ]
end

# Usage
read_cap = FileCap.read("/path/to/file")
admin_cap = FileCap.admin()
FileCap.implies?(admin_cap, read_cap) # true
```

#### Simple Contexts

```elixir
defsimple_context RequestContext, [:user_id, :session_id, :capabilities] do
  @propagation_strategy :inherit
end

# Usage
context = RequestContext.new(user_id: "user123", session_id: "session456")
propagated = RequestContext.propagate(context, SomeModule)
```

#### Simple Intents

```elixir
defsimple_intent FileReadIntent, [:path, :user_id] do
  @capabilities [FileCap.read]
  @effect FileSystemEffect.read_file
end

# Usage
intent = FileReadIntent.new("/path/to/file", "user123")
capabilities = FileReadIntent.required_capabilities(intent)
```

#### Simple Reactors

```elixir
defsimple_reactor FileReactor, [:files] do
  def process_intent(intent, state) do
    case intent do
      %FileReadIntent{path: path} ->
        content = "Content of #{path}"
        new_state = Map.put(state.files, path, content)
        {:ok, %{state | files: new_state}, []}
      _ ->
        {:error, :unsupported_intent}
    end
  end
end
```

### Advanced DSL Macros

For more complex scenarios, use the full DSL macros:

#### Capabilities

```elixir
defcapability FileSystemCap do
  @implications [
    {FileSystemCap.admin, [FileSystemCap.read, FileSystemCap.write, FileSystemCap.delete]},
    {FileSystemCap.delete, [FileSystemCap.read, FileSystemCap.write]},
    {FileSystemCap.write, [FileSystemCap.read]}
  ]

  def read(path), do: {:read, path}
  def write(path), do: {:write, path}
  def delete(path), do: {:delete, path}
  def admin(), do: {:admin}

  def implies?(cap1, cap2) do
    implications = @implications
    |> Enum.find(fn {cap, _} -> cap == cap1 end)
    |> case do
      {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
      _ -> cap1 == cap2
    end
  end
end
```

#### Contexts

```elixir
defcontext UserContext do
  @propagation_strategy :inherit
  @composition_strategy :merge

  defstruct [:user_id, :session_id, :request_id, :capabilities, :trace]

  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
    |> compute_capabilities()
    |> ensure_request_id()
  end

  def propagate(context, target_module) do
    case @propagation_strategy do
      :inherit ->
        %__MODULE__{
          user_id: context.user_id,
          session_id: context.session_id,
          request_id: generate_request_id(),
          capabilities: context.capabilities,
          trace: [target_module | (context.trace || [])]
        }
    end
  end

  def compose(context1, context2, strategy \\ @composition_strategy) do
    case strategy do
      :merge ->
        %__MODULE__{
          user_id: context2.user_id,
          session_id: context2.session_id,
          request_id: generate_request_id(),
          capabilities: MapSet.union(context1.capabilities, context2.capabilities),
          trace: (context1.trace || []) ++ (context2.trace || [])
        }
    end
  end

  defp compute_capabilities(context) do
    capabilities = case context.user_id do
      "admin" -> MapSet.new([FileSystemCap.admin()])
      "user" -> MapSet.new([FileSystemCap.read(:any), FileSystemCap.write(:any)])
      _ -> MapSet.new([FileSystemCap.read(:any)])
    end
    %{context | capabilities: capabilities}
  end

  defp generate_request_id, do: "req_#{:rand.uniform(1000)}"
  defp ensure_request_id(context) do
    if context.request_id == nil do
      %{context | request_id: generate_request_id()}
    else
      context
    end
  end
end
```

#### Intents

```elixir
defintent FileReadIntent do
  @capabilities [FileSystemCap.read]
  @effect FileSystemEffect.read_file

  defstruct [:path, :user_id, :session_id]

  def new(path, user_id, session_id) do
    %__MODULE__{
      path: path,
      user_id: user_id,
      session_id: session_id
    }
  end

  def required_capabilities(intent) do
    [FileSystemCap.read(intent.path)]
  end

  def to_reactor_message(intent, opts \\ []) do
    %PacketFlow.Reactor.Message{
      intent: intent,
      capabilities: required_capabilities(intent),
      context: opts[:context] || PacketFlow.Context.empty(),
      metadata: %{type: :file_read, timestamp: System.system_time()},
      timestamp: System.system_time()
    }
  end

  def to_effect(intent, opts \\ []) do
    PacketFlow.Effect.new(
      intent: intent,
      capabilities: required_capabilities(intent),
      context: opts[:context] || PacketFlow.Context.empty(),
      continuation: &FileSystemEffect.read_file/1
    )
  end
end
```

#### Reactors

```elixir
defreactor FileReactor do
  @initial_state %{files: %{}, operations: []}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, Keyword.get(opts, :initial_state, @initial_state)}
  end

  def handle_call({:process_intent, intent}, _from, state) do
    case process_intent(intent, state) do
      {:ok, new_state, effects} ->
        schedule_effects(effects)
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp process_intent(intent, state) do
    case intent do
      %FileReadIntent{path: path} ->
        content = Map.get(state.files, path, "Content of #{path}")
        new_state = %{state | operations: [{:read, path} | state.operations]}
        {:ok, new_state, [{:file_read, path, content}]}
      _ ->
        {:error, :unsupported_intent}
    end
  end

  defp schedule_effects(effects) do
    Enum.each(effects, fn effect ->
      spawn(fn -> execute_effect(effect) end)
    end)
  end

  defp execute_effect(effect) do
    IO.puts("Executing effect: #{inspect(effect)}")
    PacketFlow.Effect.execute(effect)
  end
end
```

### Registry Integration

```elixir
# Register components
:ok = PacketFlow.Registry.register_reactor("file_reactor", %{id: "file_reactor"})
:ok = PacketFlow.Registry.register_capability("file_cap", %{id: "file_cap"})

# Look up components
reactor_info = PacketFlow.Registry.lookup_reactor("file_reactor")
capability_info = PacketFlow.Registry.lookup_capability("file_cap")

# List all components
reactors = PacketFlow.Registry.list_reactors()
capabilities = PacketFlow.Registry.list_capabilities()
```

## Testing

Run the test suite:

```bash
mix test
```

Run with coverage:

```bash
mix coveralls
```

## Examples

See the `examples/` directory for comprehensive examples:

- `simple_example.exs` - Basic DSL usage demonstration
- `file_system_example.exs` - Advanced file system implementation

## Architecture

### Core Components

1. **DSL Macros**: Provide declarative syntax for common patterns
2. **Capabilities**: Define permissions with implication hierarchies
3. **Contexts**: Carry request state with propagation semantics
4. **Intents**: Represent domain actions with capability requirements
5. **Reactors**: Process intents with state management
6. **Effects**: Manage side effects with monadic composition
7. **Registry**: Manage component discovery and lifecycle

### Design Principles

- **Simplicity**: Easy-to-use macros for common patterns
- **Type Safety**: All components implement well-defined behaviours
- **Capability Security**: Fine-grained permission control
- **Composability**: Components can be combined and extended
- **Testability**: Comprehensive test coverage and mocking support
- **Production Ready**: Error handling, logging, and monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by algebraic data types and capability-based security
- Built on Elixir's excellent concurrency primitives
- Leverages the reactor pattern for scalable processing