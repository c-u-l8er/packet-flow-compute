# Temporal Substrate Guide

## What is the Temporal Substrate?

The **Temporal Substrate** is PacketFlow's time-aware computation layer. It builds on top of the Stream substrate to provide time-aware intent modeling, temporal reasoning, scheduling, and time-based capability validation.

Think of it as the "time-aware layer" that allows your intents to be scheduled, validated against time constraints, and processed with temporal logic.

## Core Concepts

### Temporal Computing

Temporal computing is a paradigm where:
- **Time is a first-class citizen** in your computations
- **Scheduling** determines when operations should happen
- **Temporal reasoning** validates time-based constraints
- **Time-aware capabilities** change based on time
- **Temporal logic** handles time-based business rules

In PacketFlow, temporal computing is enhanced with:
- **Time-aware intent modeling**
- **Temporal capability validation**
- **Intent scheduling and execution**
- **Temporal reactor processing**

## Key Components

### 1. **Temporal Logic** (Time-based Reasoning)
Temporal logic provides operators for time-based reasoning and validation.

```elixir
defmodule FileSystem.TemporalLogic do
  use PacketFlow.Temporal

  # Define temporal logic for file operations
  deftemporal_logic FileTemporalLogic do
    # Time-based constraints
    @business_hours_start 9   # 9 AM
    @business_hours_end 17    # 5 PM
    @maintenance_window_start 2  # 2 AM
    @maintenance_window_end 4    # 4 AM

    # Check if current time is during business hours
    def business_hours?(time \\ now()) do
      hour = time.hour
      hour >= @business_hours_start and hour < @business_hours_end
    end

    # Check if current time is during maintenance window
    def maintenance_window?(time \\ now()) do
      hour = time.hour
      hour >= @maintenance_window_start and hour < @maintenance_window_end
    end

    # Check if file operation is allowed at current time
    def file_operation_allowed?(operation, time \\ now()) do
      case operation do
        :read -> true  # Read operations always allowed
        :write -> business_hours?(time)  # Write only during business hours
        :delete -> business_hours?(time) and not maintenance_window?(time)
        :admin -> business_hours?(time) and not maintenance_window?(time)
      end
    end

    # Check if time is in the future
    def future?(time) do
      time > now()
    end

    # Check if time is in the past
    def past?(time) do
      time < now()
    end

    # Calculate time difference
    def time_diff(time1, time2) do
      time2 - time1
    end

    # Check if time is within a window
    def within_window?(time, start_time, end_time) do
      time >= start_time and time <= end_time
    end
  end
end
```

### 2. **Temporal Constraints** (Time-based Validation)
Temporal constraints define time-based rules that must be satisfied.

```elixir
defmodule FileSystem.TemporalConstraints do
  use PacketFlow.Temporal

  # Define temporal constraints for file operations
  deftemporal_constraint FileOperationConstraint, {:business_hours, :no_maintenance} do
    def validate_constraint(time, context) do
      # Check business hours constraint
      business_hours_ok = FileSystem.TemporalLogic.business_hours?(time)
      
      # Check maintenance window constraint
      maintenance_ok = not FileSystem.TemporalLogic.maintenance_window?(time)
      
      business_hours_ok and maintenance_ok
    end

    def get_constraint_description do
      "File operations must be performed during business hours (9 AM - 5 PM) and not during maintenance window (2 AM - 4 AM)"
    end
  end

  # Define time-based capability constraints
  deftemporal_constraint TimeBasedCapabilityConstraint, {:time_window, :capability} do
    def validate_constraint(time, context) do
      # Check if user has time-based capabilities
      user_capabilities = context.capabilities
      
      Enum.any?(user_capabilities, fn cap ->
        case cap do
          %FileCap{operation: :admin, time_window: window} ->
            FileSystem.TemporalLogic.within_window?(time, window.start, window.end)
          
          %FileCap{operation: :write, time_window: window} ->
            FileSystem.TemporalLogic.within_window?(time, window.start, window.end)
          
          _ -> true  # Other capabilities not time-constrained
        end
      end)
    end
  end

  # Define scheduled operation constraints
  deftemporal_constraint ScheduledOperationConstraint, {:scheduled_time, :deadline} do
    def validate_constraint(time, context) do
      # Check if operation is within scheduled time window
      scheduled_time = context.scheduled_time
      deadline = context.deadline
      
      if scheduled_time and deadline do
        FileSystem.TemporalLogic.within_window?(time, scheduled_time, deadline)
      else
        true  # No time constraints
      end
    end
  end
end
```

### 3. **Temporal Scheduling** (Time-based Execution)
Temporal scheduling manages when intents should be executed.

```elixir
defmodule FileSystem.TemporalScheduling do
  use PacketFlow.Temporal

  # Define temporal scheduler for file operations
  deftemporal_scheduler FileScheduler do
    @scheduling_strategy :immediate
    @max_scheduled_operations 1000
    @cleanup_interval 3600000  # 1 hour

    def init(_args) do
      # Initialize scheduler state
      {:ok, %{
        scheduled_operations: %{},
        next_operation_id: 1,
        metrics: %{scheduled: 0, executed: 0, failed: 0}
      }}
    end

    # Schedule an intent for future execution
    def schedule_intent(intent, context, execution_time) do
      # Validate temporal constraints
      case validate_temporal_constraints(intent, context, execution_time) do
        :ok ->
          # Create scheduled operation
          operation_id = generate_operation_id()
          scheduled_operation = %ScheduledOperation{
            id: operation_id,
            intent: intent,
            context: context,
            execution_time: execution_time,
            status: :scheduled
          }
          
          # Add to scheduled operations
          new_operations = Map.put(state.scheduled_operations, operation_id, scheduled_operation)
          new_metrics = update_in(state.metrics.scheduled, &(&1 + 1))
          
          # Schedule execution
          schedule_execution(operation_id, execution_time)
          
          {:ok, %{state | scheduled_operations: new_operations, metrics: new_metrics}}
        
        {:error, reason} ->
          {:error, reason, state}
      end
    end

    # Execute scheduled operation
    def execute_scheduled_operation(operation_id, state) do
      case Map.get(state.scheduled_operations, operation_id) do
        nil ->
          {:error, :operation_not_found, state}
        
        operation ->
          # Check if it's time to execute
          current_time = System.system_time(:millisecond)
          
          if current_time >= operation.execution_time do
            # Execute the operation
            case execute_intent(operation.intent, operation.context) do
              {:ok, result} ->
                # Mark as executed
                updated_operation = %{operation | status: :executed, result: result}
                new_operations = Map.put(state.scheduled_operations, operation_id, updated_operation)
                new_metrics = update_in(state.metrics.executed, &(&1 + 1))
                
                {:ok, %{state | scheduled_operations: new_operations, metrics: new_metrics}}
              
              {:error, reason} ->
                # Mark as failed
                updated_operation = %{operation | status: :failed, error: reason}
                new_operations = Map.put(state.scheduled_operations, operation_id, updated_operation)
                new_metrics = update_in(state.metrics.failed, &(&1 + 1))
                
                {:error, reason, %{state | scheduled_operations: new_operations, metrics: new_metrics}}
            end
          else
            # Not time to execute yet
            {:error, :too_early, state}
          end
      end
    end

    # Clean up completed operations
    def cleanup_completed_operations(state) do
      current_time = System.system_time(:millisecond)
      cleanup_threshold = current_time - 24 * 3600 * 1000  # 24 hours ago
      
      # Remove old completed operations
      new_operations = Map.filter(state.scheduled_operations, fn {_id, operation} ->
        case operation.status do
          :executed -> operation.execution_time > cleanup_threshold
          :failed -> operation.execution_time > cleanup_threshold
          :scheduled -> true  # Keep scheduled operations
        end
      end)
      
      %{state | scheduled_operations: new_operations}
    end

    # Private helper functions
    defp validate_temporal_constraints(intent, context, execution_time) do
      # Check business hours constraint
      if not FileSystem.TemporalLogic.business_hours?(execution_time) do
        {:error, :outside_business_hours}
      else
        # Check maintenance window constraint
        if FileSystem.TemporalLogic.maintenance_window?(execution_time) do
          {:error, :during_maintenance_window}
        else
          :ok
        end
      end
    end

    defp execute_intent(intent, context) do
      # Execute the intent through the normal processing pipeline
      PacketFlow.Actor.send_message(:file_actor, {:process_intent, intent, context})
    end

    defp schedule_execution(operation_id, execution_time) do
      # Schedule execution using Process.send_after
      delay = execution_time - System.system_time(:millisecond)
      if delay > 0 do
        Process.send_after(self(), {:execute_operation, operation_id}, delay)
      else
        # Execute immediately if time has passed
        send(self(), {:execute_operation, operation_id})
      end
    end
  end
end
```

## How It Works

### 1. **Temporal Intent Creation**
Intents can be created with temporal constraints:

```elixir
# Create a temporal intent for file operation
intent = FileSystem.Intents.WriteFile.new("/important.txt", "content", "user123")
context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.write("/")])

# Add temporal constraints
temporal_context = %{context | 
  temporal_constraints: [
    FileSystem.TemporalConstraints.FileOperationConstraint,
    FileSystem.TemporalConstraints.TimeBasedCapabilityConstraint
  ],
  scheduled_time: DateTime.utc_now(),
  deadline: DateTime.add(DateTime.utc_now(), 3600, :second)  # 1 hour from now
}

# The intent will be validated against temporal constraints
# before being processed
```

### 2. **Temporal Validation**
Before processing, intents are validated against temporal constraints:

```elixir
# Validate temporal constraints
case PacketFlow.Temporal.validate_constraints(intent, temporal_context) do
  :ok ->
    # Proceed with processing
    PacketFlow.Actor.send_message(:file_actor, {:process_intent, intent, temporal_context})
  
  {:error, reason} ->
    # Temporal constraint violation
    Logger.warning("Temporal constraint violated: #{inspect(reason)}")
    {:error, reason}
end
```

### 3. **Temporal Scheduling**
Intents can be scheduled for future execution:

```elixir
# Schedule intent for future execution
execution_time = DateTime.add(DateTime.utc_now(), 300, :second)  # 5 minutes from now

{:ok, operation_id} = PacketFlow.Temporal.Scheduling.schedule_intent(
  intent, 
  temporal_context, 
  execution_time
)

# The intent will be executed automatically at the specified time
# if all temporal constraints are satisfied
```

### 4. **Temporal Reactor Processing**
Reactors can be time-aware and handle temporal logic:

```elixir
# Time-aware reactor processing
def handle_temporal_intent(intent, context, state) do
  current_time = System.system_time(:millisecond)
  
  # Check temporal constraints
  case validate_temporal_constraints(intent, context, current_time) do
    :ok ->
      # Process the intent
      process_intent(intent, context, state)
    
    {:error, reason} ->
      # Handle temporal constraint violation
      handle_temporal_violation(intent, context, reason, state)
  end
end
```

## Advanced Features

### Temporal Reasoning

```elixir
defmodule FileSystem.TemporalReasoning do
  use PacketFlow.Temporal

  # Define temporal reasoning for complex time-based logic
  deftemporal_reasoning FileTemporalReasoning do
    # Check if operation is allowed based on time patterns
    def operation_allowed?(operation, time, context) do
      # Check business hours
      business_hours_ok = FileSystem.TemporalLogic.business_hours?(time)
      
      # Check day of week
      day_ok = not weekend?(time)
      
      # Check holiday schedule
      holiday_ok = not holiday?(time)
      
      # Check user's time-based capabilities
      capability_ok = check_time_based_capabilities(context.capabilities, time)
      
      business_hours_ok and day_ok and holiday_ok and capability_ok
    end

    # Predict optimal execution time
    def predict_optimal_time(operation, context) do
      # Find next available time slot
      current_time = System.system_time(:millisecond)
      
      # Look ahead for next business hour
      next_business_hour = find_next_business_hour(current_time)
      
      # Check for maintenance windows
      if maintenance_window_coming?(next_business_hour) do
        find_next_business_hour_after_maintenance(next_business_hour)
      else
        next_business_hour
      end
    end

    # Calculate time-based priority
    def calculate_temporal_priority(intent, context) do
      deadline = context.deadline
      current_time = System.system_time(:millisecond)
      
      if deadline do
        time_remaining = deadline - current_time
        
        case time_remaining do
          remaining when remaining < 300000 -> :critical    # < 5 minutes
          remaining when remaining < 3600000 -> :high       # < 1 hour
          remaining when remaining < 86400000 -> :medium    # < 1 day
          _ -> :low
        end
      else
        :normal
      end
    end
  end
end
```

### Time-based Capabilities

```elixir
defmodule FileSystem.TimeBasedCapabilities do
  use PacketFlow.Temporal

  # Define time-based capabilities
  deftemporal_capability TimeBasedFileCap do
    # Capabilities that change based on time
    def read_capability(path, time) do
      case time do
        time when FileSystem.TemporalLogic.business_hours?(time) ->
          %FileCap{operation: :read, resource: path, time_window: business_hours_window()}
        
        time when FileSystem.TemporalLogic.maintenance_window?(time) ->
          %FileCap{operation: :read, resource: path, time_window: maintenance_window(), priority: :low}
        
        _ ->
          %FileCap{operation: :read, resource: path, time_window: after_hours_window(), priority: :emergency_only}
      end
    end

    def write_capability(path, time) do
      case time do
        time when FileSystem.TemporalLogic.business_hours?(time) ->
          %FileCap{operation: :write, resource: path, time_window: business_hours_window()}
        
        _ ->
          {:error, :write_not_allowed_outside_business_hours}
      end
    end

    def admin_capability(path, time) do
      case time do
        time when FileSystem.TemporalLogic.business_hours?(time) and not FileSystem.TemporalLogic.maintenance_window?(time) ->
          %FileCap{operation: :admin, resource: path, time_window: business_hours_window()}
        
        _ ->
          {:error, :admin_not_allowed_outside_business_hours_or_during_maintenance}
      end
    end

    defp business_hours_window do
      %{start: 9, end: 17}  # 9 AM to 5 PM
    end

    defp maintenance_window do
      %{start: 2, end: 4}   # 2 AM to 4 AM
    end

    defp after_hours_window do
      %{start: 17, end: 9}  # 5 PM to 9 AM
    end
  end
end
```

### Temporal Monitoring

```elixir
defmodule FileSystem.TemporalMonitoring do
  use PacketFlow.Temporal

  # Define temporal monitoring
  deftemporal_monitor FileTemporalMonitor do
    def init(_args) do
      # Start monitoring temporal metrics
      schedule_temporal_metrics_collection()
      
      {:ok, %{
        temporal_metrics: %{},
        constraint_violations: [],
        scheduled_operations: %{}
      }}
    end

    # Monitor temporal constraint violations
    def monitor_constraint_violation(intent, context, constraint, reason) do
      violation = %TemporalConstraintViolation{
        intent: intent,
        context: context,
        constraint: constraint,
        reason: reason,
        timestamp: System.system_time(:millisecond)
      }
      
      # Log violation
      Logger.warning("Temporal constraint violation: #{inspect(violation)}")
      
      # Store violation for analysis
      new_violations = [violation | state.constraint_violations]
      
      # Keep only recent violations
      recent_violations = Enum.take(new_violations, 100)
      
      {:ok, %{state | constraint_violations: recent_violations}}
    end

    # Monitor scheduled operation execution
    def monitor_scheduled_execution(operation_id, execution_time, actual_time) do
      delay = actual_time - execution_time
      
      # Update metrics
      new_metrics = update_in(state.temporal_metrics.scheduled_executions, fn metrics ->
        Map.update(metrics, :total_delay, delay, &(&1 + delay))
        |> Map.update(:count, 1, &(&1 + 1))
        |> Map.update(:avg_delay, delay, fn avg -> (avg + delay) / 2 end)
      end)
      
      {:ok, %{state | temporal_metrics: new_metrics}}
    end

    # Collect temporal metrics
    def collect_temporal_metrics(state) do
      current_time = System.system_time(:millisecond)
      
      # Calculate temporal metrics
      metrics = %{
        current_time: current_time,
        business_hours_active: FileSystem.TemporalLogic.business_hours?(current_time),
        maintenance_window_active: FileSystem.TemporalLogic.maintenance_window?(current_time),
        scheduled_operations_count: map_size(state.scheduled_operations),
        constraint_violations_count: length(state.constraint_violations)
      }
      
      # Emit metrics
      emit_temporal_metrics(metrics)
      
      # Schedule next collection
      schedule_temporal_metrics_collection()
      
      {:ok, %{state | temporal_metrics: metrics}}
    end

    defp schedule_temporal_metrics_collection do
      Process.send_after(self(), {:collect_temporal_metrics}, 60000)  # Every minute
    end
  end
end
```

## Integration with Other Substrates

The Temporal substrate integrates with other substrates:

- **ADT Substrate**: Temporal intents and contexts with time constraints
- **Actor Substrate**: Time-aware actors with temporal scheduling
- **Stream Substrate**: Time-based stream processing with temporal windows
- **Web Framework**: Time-aware web interfaces with temporal validation

## Best Practices

### 1. **Design Temporal Constraints Carefully**
Think about time-based business rules:

```elixir
# Good: Clear temporal constraints
deftemporal_constraint BusinessHoursConstraint, {:business_hours} do
  def validate_constraint(time, _context) do
    FileSystem.TemporalLogic.business_hours?(time)
  end
end

# Avoid: Complex temporal logic in constraints
deftemporal_constraint ComplexConstraint, {:complex_logic} do
  def validate_constraint(time, context) do
    # Too much logic in constraint - hard to test and maintain
    complex_temporal_logic(time, context)
  end
end
```

### 2. **Use Appropriate Scheduling Strategies**
Choose the right scheduling strategy:

```elixir
# Immediate execution (for real-time operations)
@scheduling_strategy :immediate

# Batch execution (for efficiency)
@scheduling_strategy :batch

# Priority-based execution (for critical operations)
@scheduling_strategy :priority
```

### 3. **Handle Temporal Failures Gracefully**
Always handle temporal constraint violations:

```elixir
def handle_temporal_violation(intent, context, reason, state) do
  case reason do
    :outside_business_hours ->
      # Schedule for next business hour
      next_business_hour = find_next_business_hour()
      schedule_intent(intent, context, next_business_hour)
    
    :during_maintenance_window ->
      # Queue for after maintenance
      after_maintenance = find_time_after_maintenance()
      schedule_intent(intent, context, after_maintenance)
    
    :deadline_passed ->
      # Handle missed deadline
      notify_deadline_missed(intent, context)
      {:error, :deadline_passed}
  end
end
```

### 4. **Monitor Temporal Performance**
Keep track of temporal metrics:

```elixir
def monitor_temporal_performance(scheduler_pid) do
  # Get temporal metrics
  case PacketFlow.Temporal.get_metrics(scheduler_pid) do
    {:ok, metrics} ->
      # Check scheduled operations
      if metrics.scheduled_operations > 1000 do
        Logger.warning("Too many scheduled operations: #{metrics.scheduled_operations}")
      end
      
      # Check constraint violations
      if metrics.constraint_violations > 10 do
        Logger.error("Too many temporal constraint violations: #{metrics.constraint_violations}")
      end
      
      # Check execution delays
      if metrics.avg_execution_delay > 5000 do
        Logger.warning("High execution delay: #{metrics.avg_execution_delay}ms")
      end
    
    {:error, reason} ->
      Logger.error("Failed to get temporal metrics: #{inspect(reason)}")
  end
end
```

## Common Patterns

### 1. **Time-based Access Control**
```elixir
defmodule FileSystem.TimeBasedAccess do
  use PacketFlow.Temporal

  defmodule TimeBasedAccess do
    def check_access(user_id, operation, resource, time) do
      # Check user's time-based capabilities
      user_capabilities = get_user_capabilities(user_id)
      
      # Find applicable time-based capability
      applicable_capability = Enum.find(user_capabilities, fn cap ->
        cap.resource == resource and 
        cap.operation == operation and
        FileSystem.TemporalLogic.within_window?(time, cap.time_window.start, cap.time_window.end)
      end)
      
      case applicable_capability do
        nil -> {:error, :no_time_based_capability}
        cap -> {:ok, cap}
      end
    end
  end
end
```

### 2. **Scheduled Maintenance**
```elixir
defmodule FileSystem.ScheduledMaintenance do
  use PacketFlow.Temporal

  defmodule MaintenanceScheduler do
    def schedule_maintenance(maintenance_window, operations) do
      # Schedule maintenance operations
      Enum.each(operations, fn operation ->
        execution_time = find_optimal_maintenance_time(maintenance_window)
        schedule_intent(operation.intent, operation.context, execution_time)
      end)
    end

    defp find_optimal_maintenance_time(window) do
      # Find time within maintenance window with least impact
      current_time = System.system_time(:millisecond)
      
      if FileSystem.TemporalLogic.within_window?(current_time, window.start, window.end) do
        current_time
      else
        window.start
      end
    end
  end
end
```

### 3. **Time-based Analytics**
```elixir
defmodule FileSystem.TimeBasedAnalytics do
  use PacketFlow.Temporal

  defmodule TemporalAnalytics do
    def analyze_temporal_patterns(operations, time_range) do
      # Group operations by time periods
      grouped_operations = Enum.group_by(operations, fn op ->
        categorize_time_period(op.timestamp)
      end)
      
      # Calculate patterns
      patterns = Enum.map(grouped_operations, fn {period, ops} ->
        %{
          period: period,
          count: length(ops),
          avg_duration: calculate_avg_duration(ops),
          success_rate: calculate_success_rate(ops)
        }
      end)
      
      patterns
    end

    defp categorize_time_period(timestamp) do
      hour = timestamp.hour
      
      cond do
        hour >= 9 and hour < 17 -> :business_hours
        hour >= 2 and hour < 4 -> :maintenance_window
        hour >= 17 or hour < 9 -> :after_hours
        true -> :other
      end
    end
  end
end
```

## Testing Your Temporal Components

```elixir
defmodule FileSystem.TemporalTest do
  use ExUnit.Case
  use PacketFlow.Testing

  test "temporal constraints are validated correctly" do
    # Test business hours constraint
    business_time = %DateTime{hour: 10, minute: 0, second: 0}
    after_hours_time = %DateTime{hour: 20, minute: 0, second: 0}
    
    # Should pass during business hours
    assert FileSystem.TemporalLogic.business_hours?(business_time)
    
    # Should fail after business hours
    refute FileSystem.TemporalLogic.business_hours?(after_hours_time)
  end

  test "scheduled operations execute at correct time" do
    # Start temporal scheduler
    {:ok, scheduler_pid} = PacketFlow.Temporal.Scheduling.start_link(FileSystem.TemporalScheduling.FileScheduler)
    
    # Create test intent
    intent = FileSystem.Intents.WriteFile.new("/test.txt", "content", "user123")
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.write("/")])
    
    # Schedule for 1 second from now
    execution_time = System.system_time(:millisecond) + 1000
    
    {:ok, operation_id} = PacketFlow.Temporal.Scheduling.schedule_intent(
      scheduler_pid, intent, context, execution_time
    )
    
    # Wait for execution
    Process.sleep(1100)
    
    # Verify operation was executed
    {:ok, metrics} = PacketFlow.Temporal.Scheduling.get_metrics(scheduler_pid)
    assert metrics.executed > 0
  end
end
```

## Next Steps

Now that you understand the Temporal substrate, you can:

1. **Build Web Applications**: Use temporal logic in web interfaces
2. **Scale Your System**: Distribute temporal processing across nodes
3. **Add Analytics**: Use temporal patterns for business intelligence
4. **Implement Business Rules**: Use temporal logic for complex business requirements

The Temporal substrate is your time-aware foundation - it makes your system intelligent about when operations should happen!
