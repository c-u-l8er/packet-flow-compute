# ADT Substrate Guide

## What is the ADT Substrate?

The **ADT (Algebraic Data Types) Substrate** is the foundation layer of PacketFlow. It provides the basic building blocks for modeling your domain using algebraic data types with capability-aware constraints and validation.

Think of it as the "data layer" that everything else builds upon. It's where you define your intents, contexts, and capabilities in a type-safe way.

## Core Concepts

### Algebraic Data Types

ADTs are a way to model data structures using two fundamental operations:
- **Sum types** (like enums): `type Result = Success(data) | Error(message)`
- **Product types** (like structs): `type User = {id: int, name: string, email: string}`

In PacketFlow, we enhance these with:
- **Capability requirements**: What permissions are needed
- **Context propagation**: How data flows through the system
- **Type-level constraints**: Validation at compile time

## Key Components

### 1. **Intents** (Sum Types)
Intents represent "what you want to do" in your system. They're like commands or requests.

```elixir
defmodule FileSystem.Intents do
  use PacketFlow.ADT

  # Define an intent for file operations
  defadt_intent FileOperationIntent do
    # Read a file
    defvariant ReadFile, [:path, :user_id]
    
    # Write to a file
    defvariant WriteFile, [:path, :content, :user_id]
    
    # Delete a file
    defvariant DeleteFile, [:path, :user_id]
  end
end
```

### 2. **Contexts** (Product Types)
Contexts carry the current state and environment. They're like the "session" or "environment" of your system.

```elixir
defmodule FileSystem.Contexts do
  use PacketFlow.ADT

  # Define a context for file operations
  defadt_context FileContext do
    @propagation_strategy :merge
    
    defstruct [
      :user_id,
      :session_id,
      :capabilities,
      :current_directory,
      :timestamp
    ]
    
    def new(user_id, session_id, capabilities) do
      %__MODULE__{
        user_id: user_id,
        session_id: session_id,
        capabilities: capabilities,
        current_directory: "/",
        timestamp: System.system_time()
      }
    end
  end
end
```

### 3. **Capabilities** (Security Model)
Capabilities define what operations are allowed. They're like permissions but more flexible.

```elixir
defmodule FileSystem.Capabilities do
  use PacketFlow.ADT

  # Define file system capabilities
  defsimple_capability FileCap, [:read, :write, :delete, :admin] do
    @implications [
      {FileCap.admin, [FileCap.read, FileCap.write, FileCap.delete]},
      {FileCap.write, [FileCap.read]}
    ]
    
    # Define path-specific capabilities
    def read(path) do
      %__MODULE__{operation: :read, resource: path}
    end
    
    def write(path) do
      %__MODULE__{operation: :write, resource: path}
    end
  end
end
```

## How It Works

### 1. **Intent Creation**
When you want to perform an operation, you create an intent:

```elixir
# Create a read file intent
intent = FileSystem.Intents.ReadFile.new("/home/user/file.txt", "user123")

# The intent automatically includes capability requirements
message = intent.to_reactor_message()
# => %PacketFlow.Reactor.Message{
#      intent: intent,
#      capabilities: [FileCap.read("/home/user/file.txt")],
#      context: PacketFlow.Context.empty(),
#      metadata: %{type: :file_operation, timestamp: ...},
#      timestamp: ...
#    }
```

### 2. **Context Propagation**
Contexts carry information through your system:

```elixir
# Create a context
context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/home")])

# The context propagates through the system
# and gets merged with other contexts as needed
```

### 3. **Capability Checking**
Before any operation, capabilities are checked:

```elixir
# Check if the user has the required capability
required_cap = FileCap.read("/home/user/file.txt")
user_caps = context.capabilities

if Enum.any?(user_caps, &capability_implies?(&1, required_cap)) do
  # Proceed with operation
  {:ok, file_content}
else
  # Access denied
  {:error, :insufficient_capabilities}
end
```

## Advanced Features

### Type-Level Constraints

You can add compile-time constraints to your types:

```elixir
defadt_intent ValidatedFileIntent do
  @constraints [
    {:path, &String.starts_with?(&1, "/")},
    {:user_id, &is_binary/1}
  ]
  
  defvariant ReadFile, [:path, :user_id]
end
```

### Context Composition

Contexts can be composed and merged:

```elixir
# Merge two contexts
merged_context = PacketFlow.Context.merge(context1, context2)

# Inherit context from parent
child_context = PacketFlow.Context.inherit(parent_context, [:user_id, :capabilities])
```

### Effect System

Intents can specify what effects they produce:

```elixir
defadt_intent FileIntent do
  @effect FileSystemEffect.read_file
  
  defvariant ReadFile, [:path, :user_id]
end
```

## Integration with Other Substrates

The ADT substrate is the foundation that other substrates build upon:

- **Actor Substrate**: Uses ADT intents for message passing
- **Stream Substrate**: Processes ADT intents in real-time streams
- **Temporal Substrate**: Schedules ADT intents based on time
- **Web Framework**: Renders ADT contexts in UI components

## Best Practices

### 1. **Design Your Intents First**
Start by modeling what operations your system needs to perform:

```elixir
# Good: Clear, specific intents
defadt_intent UserManagementIntent do
  defvariant CreateUser, [:email, :password, :admin_id]
  defvariant UpdateUser, [:user_id, :changes, :admin_id]
  defvariant DeleteUser, [:user_id, :admin_id]
end

# Avoid: Vague, generic intents
defadt_intent GenericIntent do
  defvariant DoSomething, [:data]  # Too generic!
end
```

### 2. **Use Meaningful Contexts**
Contexts should carry relevant information:

```elixir
# Good: Specific context with relevant fields
defadt_context UserContext do
  defstruct [:user_id, :capabilities, :session_id, :preferences]
end

# Avoid: Generic context with everything
defadt_context GenericContext do
  defstruct [:data]  # Too generic!
end
```

### 3. **Design Capability Hierarchies**
Think about how capabilities relate to each other:

```elixir
# Good: Clear hierarchy with implications
defsimple_capability UserCap, [:basic, :admin, :super_admin] do
  @implications [
    {UserCap.super_admin, [UserCap.admin]},
    {UserCap.admin, [UserCap.basic]}
  ]
end
```

### 4. **Validate at the Type Level**
Use constraints to catch errors early:

```elixir
defadt_intent ValidatedIntent do
  @constraints [
    {:email, &String.contains?(&1, "@")},
    {:age, &(&1 >= 0 and &1 <= 150)}
  ]
  
  defvariant CreateUser, [:email, :age]
end
```

## Common Patterns

### 1. **CRUD Operations**
```elixir
defadt_intent CRUDIntent do
  defvariant Create, [:data, :user_id]
  defvariant Read, [:id, :user_id]
  defvariant Update, [:id, :changes, :user_id]
  defvariant Delete, [:id, :user_id]
end
```

### 2. **Command-Query Separation**
```elixir
# Commands (change state)
defadt_intent CommandIntent do
  defvariant CreateUser, [:email, :password]
  defvariant UpdateUser, [:id, :changes]
  defvariant DeleteUser, [:id]
end

# Queries (read state)
defadt_intent QueryIntent do
  defvariant GetUser, [:id]
  defvariant ListUsers, [:filters]
  defvariant SearchUsers, [:query]
end
```

### 3. **Domain Events**
```elixir
defadt_intent EventIntent do
  defvariant UserCreated, [:user_id, :email, :timestamp]
  defvariant UserUpdated, [:user_id, :changes, :timestamp]
  defvariant UserDeleted, [:user_id, :timestamp]
end
```

## Testing Your ADT Components

```elixir
defmodule FileSystem.IntentsTest do
  use ExUnit.Case
  use PacketFlow.Testing

  test "read file intent requires read capability" do
    intent = FileSystem.Intents.ReadFile.new("/file.txt", "user123")
    capabilities = intent.required_capabilities()
    
    assert Enum.any?(capabilities, fn cap ->
      cap.operation == :read and cap.resource == "/file.txt"
    end)
  end

  test "context propagation works correctly" do
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [])
    message = intent.to_reactor_message(context: context)
    
    assert message.context.user_id == "user123"
    assert message.context.session_id == "session456"
  end
end
```

## Next Steps

Now that you understand the ADT substrate, you can:

1. **Move to Actor Substrate**: Learn how to distribute your ADT intents across multiple nodes
2. **Add Stream Processing**: Process your ADT intents in real-time streams
3. **Add Temporal Logic**: Schedule and time your ADT intents
4. **Build Web Applications**: Use your ADT components in web interfaces

The ADT substrate is your foundation - everything else builds on top of it!
