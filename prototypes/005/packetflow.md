# PacketFlow ADT Protocol Design Document

## Overview

PacketFlow ADT is an Intent-Context-Capability oriented algebraic data type system for Elixir that provides a substrate for building reactive, capability-aware applications. The system integrates four core abstractions through a unified DSL:

- **Intents**: Capability-aware sum types representing user intentions
- **Contexts**: Product types with propagation semantics for request/session data  
- **Capabilities**: Permission-based security constraints at the type level
- **Reactors**: Streaming fold processors with effect system integration

## Core Protocol Components

### 1. Intent Protocol

Intents represent typed actions that require specific capabilities to execute.

**Declaration Syntax:**
```elixir
defintent FileOp requires [FileSystem.Read, FileSystem.Write] do
  ReadFile(path :: String.t(), context :: Context.t())
  WriteFile(path :: String.t(), content :: binary(), context :: Context.t())
  DeleteFile(path :: String.t(), context :: Context.t()) requires [FileSystem.Delete]
end
```

**Protocol Semantics:**
- Each intent variant can specify additional capability requirements
- Global capabilities apply to all variants unless overridden
- Automatic constructor generation with capability validation
- Context extraction for downstream processing

**Usage Pattern:**
```elixir
# Create intent (validates capabilities at construction)
intent = FileOp.ReadFile("/etc/passwd", user_context)

# Convert to reactor message for processing
message = FileOp.to_reactor_message(intent, metadata: %{priority: :high})

# Convert to effect for monadic composition
effect = FileOp.to_effect(intent, continuation: &process_result/1)
```

### 2. Context Protocol

Contexts are structured data containers with propagation and composition semantics.

**Declaration Syntax:**
```elixir
defcontext RequestContext propagates [:user_id, :session_id] do
  user_id :: String.t()
  session_id :: String.t()  
  request_id :: String.t(), default: &generate_request_id/0
  trace :: list(String.t()), default: []
  capabilities :: MapSet.t(), computed: &compute_capabilities/1
end
```

**Protocol Semantics:**
- **Propagation**: Specified fields automatically flow to child contexts
- **Defaults**: Function-based or static default value resolution
- **Computed Fields**: Dynamic fields calculated from other context data
- **Composition**: Merge strategies for combining contexts
- **Lenses**: Functional updates with automatic computed field recalculation

**Usage Pattern:**
```elixir
# Create context with defaults
ctx = RequestContext.new(user_id: "user123", session_id: "sess456")

# Propagate to child context
child_ctx = RequestContext.propagate(ctx, DatabaseContext)

# Compose contexts
merged = RequestContext.compose(ctx1, ctx2, :merge)

# Lens-based updates
{get_user, set_user} = RequestContext.lens_user_id()
new_ctx = set_user.(ctx, "new_user_id")
```

### 3. Capability Protocol

Capabilities define fine-grained permissions with implication relationships.

**Declaration Syntax:**
```elixir
defcapability FileSystemCap do
  Read(path_pattern :: Regex.t())
  Write(path_pattern :: Regex.t()) 
  Execute(path_pattern :: Regex.t()) grants [Read]
  Delete(path_pattern :: Regex.t()) grants [Read, Write]
end
```

**Protocol Semantics:**
- **Implication**: Higher capabilities can imply lower ones
- **Composition**: Capability sets can be merged and analyzed
- **Pattern Matching**: Parameter-based capability matching
- **Grant Relationships**: Explicit capability inheritance

**Usage Pattern:**
```elixir
# Create capabilities
read_cap = FileSystemCap.Read(~r/\/home\/user\/.*/)
delete_cap = FileSystemCap.Delete(~r/\/home\/user\/docs\/.*/)

# Check implications
FileSystemCap.implies?(delete_cap, read_cap) # true

# Compose capability sets
caps = FileSystemCap.compose([delete_cap, read_cap])
```

### 4. Reactor Protocol

Reactors are stateful message processors with streaming fold semantics.

**Declaration Syntax:**
```elixir
defreactor FileProcessor state: ProcessorState do
  on_intent FileOp.ReadFile(path, context) requires [FileSystem.Read] do
    effect do
      content <- File.read(path)
      emit({:file_content, content, context})
    end
  end
  
  on_intent FileOp.WriteFile(path, content, context) requires [FileSystem.Write] do
    effect do
      :ok <- File.write(path, content)
      emit({:file_written, path, context})
    end
  end
  
  on_error FileSystemError do
    effect do
      log_error(error)
      emit({:error, error})
    end
  end
end
```

**Protocol Semantics:**
- **Intent Handlers**: Pattern match on intent types with capability checking
- **Effect Blocks**: Monadic composition for side effects
- **Error Handlers**: Typed error recovery patterns
- **State Management**: Functional state updates with persistence
- **Streaming**: Emit-based message propagation

**Usage Pattern:**
```elixir
# Start reactor with initial state and capabilities
{:ok, pid} = FileProcessor.start_link(
  initial_state: %ProcessorState{},
  capabilities: file_caps,
  context: request_context
)

# Send intent for processing
GenServer.call(pid, {:process_intent, file_intent})
```

## Protocol Integration Patterns

### 1. Intent → Context → Capability Flow

```elixir
# Intent carries context and requires capabilities
intent = UserOp.Login(credentials, session_context)

# Context propagation to services
auth_context = SessionContext.propagate(session_context, AuthContext)

# Capability validation before processing
required_caps = UserOp.required_capabilities(intent)
available_caps = AuthContext.get_capabilities(auth_context)
```

### 2. Reactor Processing Pipeline

```elixir
# Message creation from intent
message = intent
|> UserOp.to_reactor_message(metadata: %{source: :api})
|> ReactorMessage.enrich_context(additional_context)

# Reactor processing with capability checking
AuthReactor.process_message(message)
|> handle_auth_result()
```

### 3. Effect Composition

```elixir
# Effect creation and chaining
effect = intent
|> UserOp.to_effect()
|> Effect.chain(&validate_user/1)
|> Effect.chain(&authorize_user/1)
|> Effect.chain(&log_access/1)

# Effect execution with error handling
Effect.execute(effect)
```

## Protocol Guarantees

### Type Safety
- Intent variants are statically typed with parameter validation
- Context fields have declared types with runtime checking
- Capability parameters enable fine-grained permission modeling

### Capability Security
- All intent processing requires explicit capability validation
- Capability implications prevent privilege escalation
- Missing capabilities result in explicit errors

### Context Propagation
- Marked context fields automatically flow through call chains
- Context composition enables request-scoped data accumulation
- Computed fields maintain consistency during updates

### Effect Management
- Reactor effects are scheduled asynchronously with proper error isolation
- Effect chains enable monadic error handling
- Effect state tracking prevents duplicate execution

## Implementation Considerations

### Performance
- DSL macros generate optimized runtime code
- Capability checking uses efficient implication trees
- Context updates use structural sharing where possible

### Debugging
- Generated code includes source location metadata
- Intent/capability mismatches produce detailed error messages
- Reactor state can be introspected for debugging

### Extensibility
- New intent variants can be added without breaking existing code
- Capability hierarchies can be extended through composition
- Reactor handlers support plugin patterns

## Usage Guidelines

1. **Intent Design**: Keep intents focused on single concerns with clear capability requirements
2. **Context Structure**: Include only propagatable data; avoid heavy computation in contexts
3. **Capability Modeling**: Use specific patterns rather than broad permissions
4. **Reactor Patterns**: Prefer small, focused reactors over monolithic processors
5. **Effect Composition**: Chain effects for complex workflows rather than embedding logic in handlers

This protocol provides a foundation for building distributed, capability-aware systems with strong typing and clear separation of concerns.