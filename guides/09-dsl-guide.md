# DSL Guide

## What is the DSL?

The **DSL (Domain-Specific Language)** is PacketFlow's rapid development layer. It provides macros for defining intents, contexts, capabilities, and reactors with automatic code generation and validation.

Think of it as the "developer productivity layer" that allows you to quickly define your domain models with minimal boilerplate code.

## Core Concepts

### DSL Macros

The DSL provides:
- **Intent macros** for defining operations with capability requirements
- **Context macros** for defining state and environment
- **Capability macros** for defining permissions and implications
- **Reactor macros** for defining stateful processors
- **Automatic code generation** for common patterns
- **Validation and type checking** at compile time

In PacketFlow, the DSL is enhanced with:
- **Capability-aware code generation**
- **Context propagation** patterns
- **Type-level constraints** and validation
- **Automatic effect system** integration

## Key Components

### 1. **Intent Macros** (Operation Definitions)
Intent macros define operations with automatic capability checking.

```elixir
defmodule FileSystem.DSL do
  use PacketFlow.DSL

  # Define a simple intent
  defsimple_intent ReadFileIntent, [:path, :user_id] do
    @capabilities [FileCap.read]
    @effect FileSystemEffect.read_file

    def new(path, user_id) do
      %__MODULE__{
        path: path,
        user_id: user_id
      }
    end

    def required_capabilities(intent) do
      [FileCap.read(intent.path)]
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
  end

  # Define a complex intent with validation
  defsimple_intent WriteFileIntent, [:path, :content, :user_id] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.write_file
    @constraints [
      {:path, &String.starts_with?(&1, "/")},
      {:content, &is_binary/1}
    ]

    def new(path, content, user_id) do
      %__MODULE__{
        path: path,
        content: content,
        user_id: user_id
      }
    end

    def required_capabilities(intent) do
      [FileCap.write(intent.path)]
    end

    def validate(intent) do
      with :ok <- validate_path(intent.path),
           :ok <- validate_content(intent.content) do
        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end

    defp validate_path(path) do
      if String.starts_with?(path, "/") do
        :ok
      else
        {:error, :invalid_path}
      end
    end

    defp validate_content(content) do
      if is_binary(content) do
        :ok
      else
        {:error, :invalid_content}
      end
    end
  end

  # Define an ADT intent with variants
  defadt_intent FileOperationIntent do
    defvariant ReadFile, [:path, :user_id]
    defvariant WriteFile, [:path, :content, :user_id]
    defvariant DeleteFile, [:path, :user_id]

    def required_capabilities(intent) do
      case intent do
        %{operation: :read_file, path: path} ->
          [FileCap.read(path)]
        
        %{operation: :write_file, path: path} ->
          [FileCap.write(path)]
        
        %{operation: :delete_file, path: path} ->
          [FileCap.delete(path)]
      end
    end
  end
end
```

### 2. **Context Macros** (State Definitions)
Context macros define state and environment with propagation strategies.

```elixir
defmodule FileSystem.DSL do
  use PacketFlow.DSL

  # Define a simple context
  defsimple_context UserContext, [:user_id, :session_id, :capabilities] do
    @propagation_strategy :inherit

    def new(user_id, session_id, capabilities) do
      %__MODULE__{
        user_id: user_id,
        session_id: session_id,
        capabilities: capabilities,
        timestamp: System.system_time()
      }
    end

    def merge(context1, context2) do
      %__MODULE__{
        user_id: context1.user_id,
        session_id: context1.session_id,
        capabilities: Enum.uniq(context1.capabilities ++ context2.capabilities),
        timestamp: System.system_time()
      }
    end

    def inherit(parent_context, fields) do
      %__MODULE__{
        user_id: parent_context.user_id,
        session_id: parent_context.session_id,
        capabilities: parent_context.capabilities,
        timestamp: System.system_time()
      }
    end
  end

  # Define a complex context with temporal constraints
  defsimple_context TemporalContext, [:user_id, :capabilities, :temporal_constraints] do
    @propagation_strategy :merge

    def new(user_id, capabilities, temporal_constraints \\ []) do
      %__MODULE__{
        user_id: user_id,
        capabilities: capabilities,
        temporal_constraints: temporal_constraints,
        timestamp: System.system_time()
      }
    end

    def validate_temporal_constraints(context) do
      current_time = System.system_time(:millisecond)
      
      Enum.reduce_while(context.temporal_constraints, :ok, fn constraint, _acc ->
        case validate_constraint(constraint, current_time) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end

    defp validate_constraint(constraint, current_time) do
      case constraint do
        {:business_hours} ->
          if FileSystem.TemporalLogic.business_hours?(current_time) do
            :ok
          else
            {:error, :outside_business_hours}
          end
        
        {:maintenance_window} ->
          if not FileSystem.TemporalLogic.maintenance_window?(current_time) do
            :ok
          else
            {:error, :during_maintenance_window}
          end
      end
    end
  end

  # Define an ADT context with variants
  defadt_context FileContext do
    @propagation_strategy :merge

    defvariant UserContext, [:user_id, :capabilities]
    defvariant SystemContext, [:system_id, :permissions]
    defvariant TemporalContext, [:user_id, :capabilities, :temporal_constraints]

    def merge(context1, context2) do
      case {context1, context2} do
        {%UserContext{} = user_ctx, %SystemContext{} = sys_ctx} ->
          %TemporalContext{
            user_id: user_ctx.user_id,
            capabilities: Enum.uniq(user_ctx.capabilities ++ sys_ctx.permissions),
            temporal_constraints: []
          }
        
        _ ->
          # Default merge behavior
          context1
      end
    end
  end
end
```

### 3. **Capability Macros** (Permission Definitions)
Capability macros define permissions with implication hierarchies.

```elixir
defmodule FileSystem.DSL do
  use PacketFlow.DSL

  # Define simple capabilities
  defsimple_capability FileCap, [:read, :write, :delete, :admin] do
    @implications [
      {FileCap.admin, [FileCap.read, FileCap.write, FileCap.delete]},
      {FileCap.write, [FileCap.read]}
    ]

    def read(path) do
      %__MODULE__{operation: :read, resource: path}
    end

    def write(path) do
      %__MODULE__{operation: :write, resource: path}
    end

    def delete(path) do
      %__MODULE__{operation: :delete, resource: path}
    end

    def admin(path) do
      %__MODULE__{operation: :admin, resource: path}
    end

    def implies?(cap1, cap2) do
      case {cap1, cap2} do
        {%{operation: :admin}, %{operation: op}} when op in [:read, :write, :delete] ->
          true
        
        {%{operation: :write}, %{operation: :read}} ->
          true
        
        _ ->
          false
      end
    end
  end

  # Define time-based capabilities
  defsimple_capability TimeBasedFileCap, [:read, :write, :delete] do
    @implications [
      {TimeBasedFileCap.delete, [TimeBasedFileCap.read, TimeBasedFileCap.write]},
      {TimeBasedFileCap.write, [TimeBasedFileCap.read]}
    ]

    def read(path, time_window) do
      %__MODULE__{operation: :read, resource: path, time_window: time_window}
    end

    def write(path, time_window) do
      %__MODULE__{operation: :write, resource: path, time_window: time_window}
    end

    def delete(path, time_window) do
      %__MODULE__{operation: :delete, resource: path, time_window: time_window}
    end

    def is_valid_at_time?(capability, current_time) do
      FileSystem.TemporalLogic.within_window?(current_time, capability.time_window.start, capability.time_window.end)
    end
  end
end
```

### 4. **Reactor Macros** (Stateful Processors)
Reactor macros define stateful processors with automatic message handling.

```elixir
defmodule FileSystem.DSL do
  use PacketFlow.DSL

  # Define a simple reactor
  defsimple_reactor FileReactor, [:files, :metrics] do
    def handle_intent(intent, context, state) do
      case intent do
        %ReadFileIntent{path: path, user_id: user_id} ->
          handle_read_file(path, user_id, context, state)
        
        %WriteFileIntent{path: path, content: content, user_id: user_id} ->
          handle_write_file(path, content, user_id, context, state)
        
        %DeleteFileIntent{path: path, user_id: user_id} ->
          handle_delete_file(path, user_id, context, state)
      end
    end

    defp handle_read_file(path, user_id, context, state) do
      # Check capabilities
      required_cap = FileCap.read(path)
      if has_capability?(context, required_cap) do
        # Read file
        case File.read(path) do
          {:ok, content} ->
            # Update metrics
            new_metrics = update_in(state.metrics.reads, &(&1 + 1))
            new_state = %{state | metrics: new_metrics}
            
            {:ok, new_state, [FileSystemEffect.file_read(path, content)]}
          
          {:error, reason} ->
            # Update error metrics
            new_metrics = update_in(state.metrics.errors, &(&1 + 1))
            new_state = %{state | metrics: new_metrics}
            
            {:error, reason, new_state}
        end
      else
        {:error, :insufficient_capabilities, state}
      end
    end

    defp handle_write_file(path, content, user_id, context, state) do
      # Check capabilities
      required_cap = FileCap.write(path)
      if has_capability?(context, required_cap) do
        # Write file
        case File.write(path, content) do
          :ok ->
            # Update metrics
            new_metrics = update_in(state.metrics.writes, &(&1 + 1))
            new_state = %{state | metrics: new_metrics}
            
            {:ok, new_state, [FileSystemEffect.file_written(path)]}
          
          {:error, reason} ->
            # Update error metrics
            new_metrics = update_in(state.metrics.errors, &(&1 + 1))
            new_state = %{state | metrics: new_metrics}
            
            {:error, reason, new_state}
        end
      else
        {:error, :insufficient_capabilities, state}
      end
    end

    defp handle_delete_file(path, user_id, context, state) do
      # Check capabilities
      required_cap = FileCap.delete(path)
      if has_capability?(context, required_cap) do
        # Delete file
        case File.rm(path) do
          :ok ->
            # Update metrics
            new_metrics = update_in(state.metrics.deletes, &(&1 + 1))
            new_state = %{state | metrics: new_metrics}
            
            {:ok, new_state, [FileSystemEffect.file_deleted(path)]}
          
          {:error, reason} ->
            # Update error metrics
            new_metrics = update_in(state.metrics.errors, &(&1 + 1))
            new_state = %{state | metrics: new_metrics}
            
            {:error, reason, new_state}
        end
      else
        {:error, :insufficient_capabilities, state}
      end
    end
  end

  # Define a temporal reactor
  defsimple_reactor TemporalFileReactor, [:files, :metrics, :temporal_state] do
    def handle_intent(intent, context, state) do
      # Validate temporal constraints
      case validate_temporal_constraints(context) do
        :ok ->
          # Process intent normally
          super(intent, context, state)
        
        {:error, reason} ->
          # Handle temporal constraint violation
          handle_temporal_violation(intent, context, reason, state)
      end
    end

    defp validate_temporal_constraints(context) do
      current_time = System.system_time(:millisecond)
      
      # Check business hours
      if FileSystem.TemporalLogic.business_hours?(current_time) do
        :ok
      else
        {:error, :outside_business_hours}
      end
    end

    defp handle_temporal_violation(intent, context, reason, state) do
      case reason do
        :outside_business_hours ->
          # Schedule for next business hour
          schedule_intent_for_business_hours(intent, context)
          {:ok, state, []}
        
        :during_maintenance_window ->
          # Queue for after maintenance
          queue_intent_for_after_maintenance(intent, context)
          {:ok, state, []}
      end
    end
  end
end
```

## How It Works

### 1. **Automatic Code Generation**
The DSL automatically generates common patterns:

```elixir
# Define a simple intent
defsimple_intent ReadFileIntent, [:path, :user_id] do
  @capabilities [FileCap.read]
  @effect FileSystemEffect.read_file
end

# DSL automatically generates:
# - new/2 function for creating intents
# - required_capabilities/1 function
# - to_reactor_message/2 function
# - to_effect/2 function
# - validation functions
# - serialization functions

# Use the generated code
intent = ReadFileIntent.new("/file.txt", "user123")
message = intent.to_reactor_message()
effect = intent.to_effect()
```

### 2. **Capability-Aware Code Generation**
The DSL generates capability-aware code:

```elixir
# Define capability with implications
defsimple_capability FileCap, [:read, :write, :delete, :admin] do
  @implications [
    {FileCap.admin, [FileCap.read, FileCap.write, FileCap.delete]},
    {FileCap.write, [FileCap.read]}
  ]
end

# DSL automatically generates:
# - implies?/2 function for capability checking
# - hierarchy validation
# - automatic capability propagation

# Use the generated capability checking
admin_cap = FileCap.admin("/")
read_cap = FileCap.read("/file.txt")

FileCap.implies?(admin_cap, read_cap)  # => true
```

### 3. **Context Propagation Patterns**
The DSL generates context propagation code:

```elixir
# Define context with propagation strategy
defsimple_context UserContext, [:user_id, :capabilities] do
  @propagation_strategy :inherit
end

# DSL automatically generates:
# - merge/2 function for combining contexts
# - inherit/2 function for context inheritance
# - validation functions
# - serialization functions

# Use the generated context functions
context1 = UserContext.new("user123", [FileCap.read("/")])
context2 = UserContext.new("user456", [FileCap.write("/")])

merged = UserContext.merge(context1, context2)
inherited = UserContext.inherit(context1, [:user_id])
```

### 4. **Reactor State Management**
The DSL generates reactor state management:

```elixir
# Define reactor with state
defsimple_reactor FileReactor, [:files, :metrics] do
  def handle_intent(intent, context, state) do
    # Handle intent
  end
end

# DSL automatically generates:
# - init/1 function for state initialization
# - handle_call/3 for message handling
# - handle_cast/2 for async messages
# - terminate/2 for cleanup
# - state serialization functions

# Use the generated reactor
{:ok, reactor_pid} = FileReactor.start_link()
GenServer.call(reactor_pid, {:process_intent, intent, context})
```

## Advanced Features

### Custom DSL Macros

```elixir
defmodule FileSystem.CustomDSL do
  use PacketFlow.DSL

  # Define custom macro for file operations
  defmacro def_file_operation(name, fields, do: body) do
    quote do
      defsimple_intent unquote(name), unquote(fields) do
        @capabilities [FileCap.read, FileCap.write]
        @effect FileSystemEffect.file_operation

        unquote(body)

        # Custom validation
        def validate_file_path(intent) do
          if String.starts_with?(intent.path, "/") do
            :ok
          else
            {:error, :invalid_path}
          end
        end
      end
    end
  end

  # Use custom macro
  def_file_operation CustomFileIntent, [:path, :operation] do
    def new(path, operation) do
      %__MODULE__{
        path: path,
        operation: operation
      }
    end
  end
end
```

### DSL Composition

```elixir
defmodule FileSystem.ComposedDSL do
  use PacketFlow.DSL

  # Compose multiple DSL patterns
  defmacro def_temporal_file_operation(name, fields, do: body) do
    quote do
      defsimple_intent unquote(name), unquote(fields) do
        @capabilities [FileCap.read, FileCap.write]
        @effect FileSystemEffect.file_operation
        @temporal_constraints [:business_hours]

        unquote(body)

        # Add temporal validation
        def validate_temporal_constraints(intent, context) do
          current_time = System.system_time(:millisecond)
          
          if FileSystem.TemporalLogic.business_hours?(current_time) do
            :ok
          else
            {:error, :outside_business_hours}
          end
        end
      end

      defsimple_reactor unquote(:"#{name}Reactor"), [:files, :temporal_state] do
        def handle_intent(intent, context, state) do
          # Validate temporal constraints first
          case validate_temporal_constraints(intent, context) do
            :ok ->
              # Process intent
              process_file_operation(intent, context, state)
            
            {:error, reason} ->
              # Handle temporal violation
              handle_temporal_violation(intent, context, reason, state)
          end
        end
      end
    end
  end
end
```

## Best Practices

### 1. **Design Clear DSL Patterns**
Create intuitive DSL patterns:

```elixir
# Good: Clear and descriptive
defsimple_intent ReadFileIntent, [:path, :user_id] do
  @capabilities [FileCap.read]
  @effect FileSystemEffect.read_file
end

# Avoid: Vague or confusing patterns
defsimple_intent DoSomethingIntent, [:data] do
  @capabilities [:something]
  @effect :unknown_effect
end
```

### 2. **Use Appropriate Capability Hierarchies**
Design clear capability implications:

```elixir
# Good: Clear hierarchy
defsimple_capability FileCap, [:read, :write, :delete, :admin] do
  @implications [
    {FileCap.admin, [FileCap.read, FileCap.write, FileCap.delete]},
    {FileCap.write, [FileCap.read]}
  ]
end

# Avoid: Circular or unclear implications
defsimple_capability BadCap, [:read, :write] do
  @implications [
    {BadCap.read, [BadCap.write]},  # Circular!
    {BadCap.write, [BadCap.read]}
  ]
end
```

### 3. **Validate at Compile Time**
Use constraints for early error detection:

```elixir
# Good: Compile-time validation
defsimple_intent ValidatedIntent, [:path, :content] do
  @capabilities [FileCap.write]
  @constraints [
    {:path, &String.starts_with?(&1, "/")},
    {:content, &is_binary/1}
  ]
end

# Avoid: Runtime-only validation
defsimple_intent UnvalidatedIntent, [:path, :content] do
  @capabilities [FileCap.write]
  # No constraints - errors only found at runtime
end
```

## Common Patterns

### 1. **CRUD DSL Pattern**
```elixir
defmodule FileSystem.CRUDDSL do
  use PacketFlow.DSL

  # Define CRUD operations
  defsimple_intent CreateFileIntent, [:path, :content, :user_id] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.file_created
  end

  defsimple_intent ReadFileIntent, [:path, :user_id] do
    @capabilities [FileCap.read]
    @effect FileSystemEffect.file_read
  end

  defsimple_intent UpdateFileIntent, [:path, :content, :user_id] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.file_updated
  end

  defsimple_intent DeleteFileIntent, [:path, :user_id] do
    @capabilities [FileCap.delete]
    @effect FileSystemEffect.file_deleted
  end

  # Define CRUD reactor
  defsimple_reactor CRUDReactor, [:files, :metrics] do
    def handle_intent(intent, context, state) do
      case intent do
        %CreateFileIntent{} -> handle_create(intent, context, state)
        %ReadFileIntent{} -> handle_read(intent, context, state)
        %UpdateFileIntent{} -> handle_update(intent, context, state)
        %DeleteFileIntent{} -> handle_delete(intent, context, state)
      end
    end
  end
end
```

### 2. **Event Sourcing DSL Pattern**
```elixir
defmodule FileSystem.EventSourcingDSL do
  use PacketFlow.DSL

  # Define events
  defsimple_intent FileCreatedEvent, [:path, :content, :user_id, :timestamp] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.event_stored
  end

  defsimple_intent FileUpdatedEvent, [:path, :content, :user_id, :timestamp] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.event_stored
  end

  defsimple_intent FileDeletedEvent, [:path, :user_id, :timestamp] do
    @capabilities [FileCap.delete]
    @effect FileSystemEffect.event_stored
  end

  # Define event store reactor
  defsimple_reactor EventStoreReactor, [:events, :snapshots] do
    def handle_intent(intent, context, state) do
      # Store event
      new_events = [intent | state.events]
      
      # Create snapshot if needed
      new_state = maybe_create_snapshot(new_events, state)
      
      {:ok, new_state, [FileSystemEffect.event_stored(intent)]}
    end
  end
end
```

### 3. **CQRS DSL Pattern**
```elixir
defmodule FileSystem.CQRSDSL do
  use PacketFlow.DSL

  # Define commands (write side)
  defsimple_intent CreateFileCommand, [:path, :content, :user_id] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.command_processed
  end

  defsimple_intent UpdateFileCommand, [:path, :content, :user_id] do
    @capabilities [FileCap.write]
    @effect FileSystemEffect.command_processed
  end

  # Define queries (read side)
  defsimple_intent GetFileQuery, [:path, :user_id] do
    @capabilities [FileCap.read]
    @effect FileSystemEffect.query_executed
  end

  defsimple_intent ListFilesQuery, [:directory, :user_id] do
    @capabilities [FileCap.read]
    @effect FileSystemEffect.query_executed
  end

  # Define command handler
  defsimple_reactor CommandHandler, [:write_model] do
    def handle_intent(intent, context, state) do
      case intent do
        %CreateFileCommand{} -> handle_create_command(intent, context, state)
        %UpdateFileCommand{} -> handle_update_command(intent, context, state)
      end
    end
  end

  # Define query handler
  defsimple_reactor QueryHandler, [:read_model] do
    def handle_intent(intent, context, state) do
      case intent do
        %GetFileQuery{} -> handle_get_query(intent, context, state)
        %ListFilesQuery{} -> handle_list_query(intent, context, state)
      end
    end
  end
end
```

## Testing Your DSL

```elixir
defmodule FileSystem.DSLTest do
  use ExUnit.Case
  use PacketFlow.Testing

  test "DSL generates correct intent code" do
    # Test generated intent
    intent = ReadFileIntent.new("/test.txt", "user123")
    
    # Test capability requirements
    capabilities = intent.required_capabilities()
    assert Enum.any?(capabilities, fn cap ->
      cap.operation == :read and cap.resource == "/test.txt"
    end)
    
    # Test reactor message generation
    message = intent.to_reactor_message()
    assert message.intent == intent
    assert message.capabilities == capabilities
  end

  test "DSL generates correct context code" do
    # Test context creation
    context = UserContext.new("user123", [FileCap.read("/")])
    
    # Test context merging
    context2 = UserContext.new("user456", [FileCap.write("/")])
    merged = UserContext.merge(context, context2)
    
    assert merged.user_id == "user123"  # First context takes precedence
    assert length(merged.capabilities) == 2
  end

  test "DSL generates correct capability code" do
    # Test capability creation
    read_cap = FileCap.read("/file.txt")
    admin_cap = FileCap.admin("/")
    
    # Test capability implications
    assert FileCap.implies?(admin_cap, read_cap)
    refute FileCap.implies?(read_cap, admin_cap)
  end
end
```

## Next Steps

Now that you understand the DSL, you can:

1. **Create Domain-Specific Languages**: Build custom DSLs for your domains
2. **Generate Boilerplate Code**: Automate common patterns
3. **Enforce Best Practices**: Use DSLs to enforce architectural patterns
4. **Improve Developer Productivity**: Reduce repetitive code

The DSL is your productivity foundation - it makes development faster and more consistent!
