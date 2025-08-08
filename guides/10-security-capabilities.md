# Security & Capabilities Guide

## What is the Security & Capabilities System?

The **Security & Capabilities System** is PacketFlow's capability-based security layer. It provides fine-grained permission control with implication hierarchies, context propagation, and runtime validation.

Think of it as the "security foundation" that ensures your system is secure by default, with permissions that are explicit, composable, and auditable.

## Core Concepts

### Capability-Based Security

The Security & Capabilities System provides:
- **Fine-grained permissions** with explicit capabilities
- **Implication hierarchies** for permission inheritance
- **Context propagation** for security state
- **Runtime validation** with automatic checking
- **Audit trails** for security events

In PacketFlow, security is enhanced with:
- **Type-level capability checking**
- **Automatic context propagation**
- **Temporal capability validation**
- **Plugin-based capability extensions**

## Key Components

### 1. **Capability Definitions** (Permission Models)
Capabilities define what operations are allowed with implication hierarchies.

```elixir
defmodule FileSystem.Security.Capabilities do
  use PacketFlow.Security

  # Define file system capabilities
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

  # Define user capabilities
  defsimple_capability UserCap, [:basic, :admin, :super_admin] do
    @implications [
      {UserCap.super_admin, [UserCap.admin, UserCap.basic]},
      {UserCap.admin, [UserCap.basic]}
    ]

    def basic do
      %__MODULE__{level: :basic}
    end

    def admin do
      %__MODULE__{level: :admin}
    end

    def super_admin do
      %__MODULE__{level: :super_admin}
    end
  end
end
```

### 2. **Capability Validation** (Runtime Checking)
Capability validation ensures operations are allowed at runtime.

```elixir
defmodule FileSystem.Security.Validation do
  use PacketFlow.Security

  # Define capability validator
  defvalidator CapabilityValidator do
    def validate_capability(required_capability, user_capabilities) do
      # Check if user has the required capability
      Enum.any?(user_capabilities, fn user_cap ->
        capability_implies?(user_cap, required_capability)
      end)
      |> case do
        true -> :ok
        false -> {:error, :insufficient_capabilities}
      end
    end

    def validate_capabilities(required_capabilities, user_capabilities) do
      # Check if user has all required capabilities
      Enum.all?(required_capabilities, fn required_cap ->
        Enum.any?(user_capabilities, fn user_cap ->
          capability_implies?(user_cap, required_cap)
        end)
      end)
      |> case do
        true -> :ok
        false -> {:error, :insufficient_capabilities}
      end
    end

    def validate_temporal_capability(capability, user_capabilities, current_time) do
      # Check if capability is valid at current time
      case validate_capability(capability, user_capabilities) do
        :ok ->
          if is_temporal_capability_valid?(capability, current_time) do
            :ok
          else
            {:error, :temporal_constraint_violation}
          end
        
        {:error, reason} ->
          {:error, reason}
      end
    end

    defp is_temporal_capability_valid?(capability, current_time) do
      case capability do
        %TimeBasedFileCap{time_window: window} ->
          FileSystem.TemporalLogic.within_window?(current_time, window.start, window.end)
        
        _ ->
          true  # Non-temporal capabilities are always valid
      end
    end
  end

  # Define context validator
  defvalidator ContextValidator do
    def validate_context(context) do
      # Validate context has required fields
      with :ok <- validate_user_id(context.user_id),
           :ok <- validate_capabilities(context.capabilities),
           :ok <- validate_temporal_constraints(context) do
        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end

    defp validate_user_id(user_id) do
      if is_binary(user_id) and user_id != "" do
        :ok
      else
        {:error, :invalid_user_id}
      end
    end

    defp validate_capabilities(capabilities) do
      if is_list(capabilities) do
        :ok
      else
        {:error, :invalid_capabilities}
      end
    end

    defp validate_temporal_constraints(context) do
      case context do
        %{temporal_constraints: constraints} when is_list(constraints) ->
          :ok
        
        _ ->
          :ok  # No temporal constraints
      end
    end
  end
end
```

### 3. **Security Context** (State Propagation)
Security context carries security state through the system.

```elixir
defmodule FileSystem.Security.Context do
  use PacketFlow.Security

  # Define security context
  defsimple_context SecurityContext, [:user_id, :capabilities, :session_id, :audit_trail] do
    @propagation_strategy :merge

    def new(user_id, capabilities, session_id \\ nil) do
      %__MODULE__{
        user_id: user_id,
        capabilities: capabilities,
        session_id: session_id || generate_session_id(),
        audit_trail: [],
        timestamp: System.system_time()
      }
    end

    def add_audit_event(context, event) do
      audit_event = %{
        event: event,
        timestamp: System.system_time(),
        user_id: context.user_id,
        session_id: context.session_id
      }
      
      %{context | audit_trail: [audit_event | context.audit_trail]}
    end

    def merge(context1, context2) do
      %__MODULE__{
        user_id: context1.user_id,
        capabilities: Enum.uniq(context1.capabilities ++ context2.capabilities),
        session_id: context1.session_id,
        audit_trail: context1.audit_trail ++ context2.audit_trail,
        timestamp: System.system_time()
      }
    end

    def inherit(parent_context, fields) do
      %__MODULE__{
        user_id: parent_context.user_id,
        capabilities: parent_context.capabilities,
        session_id: parent_context.session_id,
        audit_trail: parent_context.audit_trail,
        timestamp: System.system_time()
      }
    end

    defp generate_session_id do
      :crypto.strong_rand_bytes(16) |> Base.encode16()
    end
  end

  # Define temporal security context
  defsimple_context TemporalSecurityContext, [:user_id, :capabilities, :temporal_constraints] do
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
end
```

## How It Works

### 1. **Capability Checking**
Capabilities are checked automatically throughout the system:

```elixir
# Define intent with capability requirements
defsimple_intent ReadFileIntent, [:path, :user_id] do
  @capabilities [FileCap.read]
  @effect FileSystemEffect.read_file
end

# Create intent and context
intent = ReadFileIntent.new("/secret.txt", "user123")
context = SecurityContext.new("user123", [FileCap.read("/secret.txt")])

# Capability checking happens automatically
case PacketFlow.Security.validate_capability(FileCap.read("/secret.txt"), context.capabilities) do
  :ok ->
    # Proceed with operation
    process_intent(intent, context)
  
  {:error, :insufficient_capabilities} ->
    # Access denied
    {:error, :access_denied}
end
```

### 2. **Capability Implications**
Capabilities can imply other capabilities:

```elixir
# Admin capability implies read, write, and delete
admin_cap = FileCap.admin("/")
read_cap = FileCap.read("/file.txt")

# Check if admin capability implies read capability
FileCap.implies?(admin_cap, read_cap)  # => true

# This means users with admin capability can read files
# without needing explicit read capability
```

### 3. **Temporal Capabilities**
Capabilities can be time-based:

```elixir
# Create time-based capability
business_hours_cap = TimeBasedFileCap.write("/file.txt", %{
  start: 9,  # 9 AM
  end: 17    # 5 PM
})

current_time = System.system_time(:millisecond)

# Check if capability is valid at current time
if TimeBasedFileCap.is_valid_at_time?(business_hours_cap, current_time) do
  # Capability is valid, proceed with operation
  process_write_operation()
else
  # Capability is not valid at this time
  {:error, :outside_business_hours}
end
```

### 4. **Context Propagation**
Security context propagates through the system:

```elixir
# Create security context
context = SecurityContext.new("user123", [FileCap.read("/"), FileCap.write("/user/")])

# Context propagates through operations
intent = ReadFileIntent.new("/file.txt", "user123")
message = intent.to_reactor_message(context: context)

# Context is automatically validated and propagated
# to all components that process the intent
```

## Advanced Features

### Capability Delegation

```elixir
defmodule FileSystem.Security.Delegation do
  use PacketFlow.Security

  # Define capability delegation
  defdelegator CapabilityDelegator do
    def delegate_capability(from_user, to_user, capability, duration) do
      # Create delegated capability
      delegated_cap = %DelegatedCapability{
        original_user: from_user,
        delegated_user: to_user,
        capability: capability,
        delegated_at: System.system_time(),
        expires_at: System.system_time() + duration
      }
      
      # Store delegation
      store_delegation(delegated_cap)
      
      # Notify audit system
      audit_delegation(delegated_cap)
      
      {:ok, delegated_cap}
    end

    def validate_delegated_capability(user_id, capability) do
      # Check if user has delegated capability
      case find_delegation(user_id, capability) do
        nil ->
          {:error, :no_delegation}
        
        delegation ->
          if delegation.expires_at > System.system_time() do
            {:ok, delegation}
          else
            # Delegation has expired
            revoke_delegation(delegation)
            {:error, :delegation_expired}
          end
      end
    end

    def revoke_delegation(delegation) do
      # Remove delegation
      remove_delegation(delegation)
      
      # Notify audit system
      audit_revocation(delegation)
      
      :ok
    end
  end
end
```

### Capability Auditing

```elixir
defmodule FileSystem.Security.Auditing do
  use PacketFlow.Security

  # Define capability auditor
  defauditor CapabilityAuditor do
    def audit_capability_check(user_id, capability, result) do
      audit_event = %{
        type: :capability_check,
        user_id: user_id,
        capability: capability,
        result: result,
        timestamp: System.system_time()
      }
      
      store_audit_event(audit_event)
      
      # Alert on security violations
      case result do
        {:error, :insufficient_capabilities} ->
          alert_security_violation(audit_event)
        
        _ ->
          :ok
      end
    end

    def audit_capability_grant(user_id, capability, granted_by) do
      audit_event = %{
        type: :capability_grant,
        user_id: user_id,
        capability: capability,
        granted_by: granted_by,
        timestamp: System.system_time()
      }
      
      store_audit_event(audit_event)
    end

    def audit_capability_revoke(user_id, capability, revoked_by) do
      audit_event = %{
        type: :capability_revoke,
        user_id: user_id,
        capability: capability,
        revoked_by: revoked_by,
        timestamp: System.system_time()
      }
      
      store_audit_event(audit_event)
    end

    def get_audit_trail(user_id, time_range) do
      # Retrieve audit events for user
      query_audit_events(user_id, time_range)
    end
  end
end
```

### Capability Plugins

```elixir
defmodule FileSystem.Security.Plugins do
  use PacketFlow.Security

  # Define encryption capability plugin
  defcapability_plugin EncryptionCapabilityPlugin do
    def plugin_info do
      %{
        name: "encryption_capability",
        version: "1.0.0",
        capabilities: [FileCap.encrypt("/"), FileCap.decrypt("/")]
      }
    end

    def handle_capability_check(capability, context) do
      case capability do
        %{operation: :encrypt, resource: path} ->
          check_encryption_capability(path, context)
        
        %{operation: :decrypt, resource: path} ->
          check_decryption_capability(path, context)
        
        _ ->
          :ok  # Not handled by this plugin
      end
    end

    defp check_encryption_capability(path, context) do
      # Check if user has encryption capability
      if has_capability?(context, FileCap.write(path)) do
        :ok
      else
        {:error, :insufficient_capabilities}
      end
    end

    defp check_decryption_capability(path, context) do
      # Check if user has decryption capability
      if has_capability?(context, FileCap.read(path)) do
        :ok
      else
        {:error, :insufficient_capabilities}
      end
    end
  end
end
```

## Best Practices

### 1. **Design Clear Capability Hierarchies**
Create intuitive capability implications:

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

### 2. **Use Principle of Least Privilege**
Grant minimal necessary capabilities:

```elixir
# Good: Minimal capabilities
def simple_user_context(user_id) do
  SecurityContext.new(user_id, [
    FileCap.read("/user/#{user_id}/"),
    FileCap.write("/user/#{user_id}/")
  ])
end

# Avoid: Overly broad capabilities
def admin_user_context(user_id) do
  SecurityContext.new(user_id, [
    FileCap.admin("/")  # Too broad!
  ])
end
```

### 3. **Validate Capabilities at Runtime**
Always check capabilities before operations:

```elixir
# Good: Runtime capability checking
def process_file_operation(intent, context) do
  required_cap = get_required_capability(intent)
  
  case PacketFlow.Security.validate_capability(required_cap, context.capabilities) do
    :ok ->
      perform_operation(intent)
    
    {:error, reason} ->
      {:error, reason}
  end
end

# Avoid: Assuming capabilities
def process_file_operation(intent, context) do
  # No capability checking - security risk!
  perform_operation(intent)
end
```

### 4. **Audit Security Events**
Keep track of security-related events:

```elixir
# Good: Comprehensive auditing
def audit_security_event(event_type, user_id, details) do
  audit_event = %{
    type: event_type,
    user_id: user_id,
    details: details,
    timestamp: System.system_time()
  }
  
  PacketFlow.Security.Auditing.store_audit_event(audit_event)
end

# Use in operations
def read_file(path, user_id, context) do
  audit_security_event(:file_read_attempt, user_id, %{path: path})
  
  case validate_capability(FileCap.read(path), context.capabilities) do
    :ok ->
      audit_security_event(:file_read_success, user_id, %{path: path})
      File.read(path)
    
    {:error, reason} ->
      audit_security_event(:file_read_denied, user_id, %{path: path, reason: reason})
      {:error, reason}
  end
end
```

## Common Patterns

### 1. **Role-Based Capabilities**
```elixir
defmodule FileSystem.Security.Roles do
  use PacketFlow.Security

  # Define role-based capabilities
  def role_capabilities(:user) do
    [
      FileCap.read("/user/"),
      FileCap.write("/user/")
    ]
  end

  def role_capabilities(:admin) do
    [
      FileCap.read("/"),
      FileCap.write("/"),
      FileCap.delete("/")
    ]
  end

  def role_capabilities(:super_admin) do
    [
      FileCap.admin("/")
    ]
  end

  # Create context based on role
  def create_role_context(user_id, role) do
    capabilities = role_capabilities(role)
    SecurityContext.new(user_id, capabilities)
  end
end
```

### 2. **Time-Based Capabilities**
```elixir
defmodule FileSystem.Security.TimeBased do
  use PacketFlow.Security

  # Define time-based capabilities
  def business_hours_capabilities(user_id) do
    [
      TimeBasedFileCap.read("/", business_hours_window()),
      TimeBasedFileCap.write("/user/#{user_id}/", business_hours_window())
    ]
  end

  def after_hours_capabilities(user_id) do
    [
      TimeBasedFileCap.read("/user/#{user_id}/", after_hours_window())
    ]
  end

  defp business_hours_window do
    %{start: 9, end: 17}  # 9 AM to 5 PM
  end

  defp after_hours_window do
    %{start: 17, end: 9}  # 5 PM to 9 AM
  end
end
```

### 3. **Delegated Capabilities**
```elixir
defmodule FileSystem.Security.Delegation do
  use PacketFlow.Security

  # Define capability delegation
  def delegate_file_access(from_user, to_user, path, duration) do
    capability = FileCap.read(path)
    
    PacketFlow.Security.Delegation.delegate_capability(
      from_user, to_user, capability, duration
    )
  end

  def revoke_file_access(from_user, to_user, path) do
    capability = FileCap.read(path)
    
    PacketFlow.Security.Delegation.revoke_delegation(
      from_user, to_user, capability
    )
  end
end
```

## Testing Your Security System

```elixir
defmodule FileSystem.Security.Test do
  use ExUnit.Case
  use PacketFlow.Testing

  test "capability validation works correctly" do
    # Test valid capability
    user_capabilities = [FileCap.read("/file.txt")]
    required_capability = FileCap.read("/file.txt")
    
    assert PacketFlow.Security.validate_capability(required_capability, user_capabilities) == :ok
    
    # Test invalid capability
    required_capability = FileCap.write("/file.txt")
    
    assert PacketFlow.Security.validate_capability(required_capability, user_capabilities) == 
      {:error, :insufficient_capabilities}
  end

  test "capability implications work correctly" do
    # Test admin implies read
    admin_cap = FileCap.admin("/")
    read_cap = FileCap.read("/file.txt")
    
    assert FileCap.implies?(admin_cap, read_cap)
    
    # Test read doesn't imply admin
    refute FileCap.implies?(read_cap, admin_cap)
  end

  test "temporal capabilities work correctly" do
    # Test business hours capability
    business_cap = TimeBasedFileCap.write("/file.txt", %{start: 9, end: 17})
    
    # Test during business hours
    business_time = %DateTime{hour: 10, minute: 0, second: 0}
    assert TimeBasedFileCap.is_valid_at_time?(business_cap, business_time)
    
    # Test outside business hours
    after_hours_time = %DateTime{hour: 20, minute: 0, second: 0}
    refute TimeBasedFileCap.is_valid_at_time?(business_cap, after_hours_time)
  end
end
```

## Next Steps

Now that you understand the Security & Capabilities system, you can:

1. **Implement Secure Systems**: Build systems with capability-based security
2. **Create Role-Based Access**: Define roles with appropriate capabilities
3. **Add Temporal Security**: Implement time-based access control
4. **Audit Security Events**: Track and monitor security-related activities

The Security & Capabilities system is your security foundation - it makes your system secure by default!
