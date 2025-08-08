# Actor Substrate Guide

## What is the Actor Substrate?

The **Actor Substrate** is PacketFlow's distributed processing layer. It builds on top of the ADT substrate to provide distributed actor orchestration with supervision, clustering, and cross-node capability propagation.

Think of it as the "distributed computing layer" that allows your ADT intents to be processed across multiple nodes in a fault-tolerant way.

## Core Concepts

### Actor Model

The actor model is a computational model where:
- **Actors** are the universal primitives of computation
- Each actor has its own **state** and **behavior**
- Actors communicate only through **messages**
- Actors can create other actors and supervise them

In PacketFlow, actors are enhanced with:
- **Capability-aware message passing**
- **Distributed supervision strategies**
- **Cross-node context propagation**
- **Fault tolerance and recovery**

## Key Components

### 1. **Actors** (Distributed Workers)
Actors are the workers that process your intents. They can be distributed across multiple nodes.

```elixir
defmodule FileSystem.FileActor do
  use PacketFlow.Actor

  # Define a file processing actor
  defactor FileActor do
    # Actor state
    @actor_state %{
      files: %{},
      metrics: %{reads: 0, writes: 0, errors: 0}
    }

    # Handle incoming intents
    def handle_intent(intent, context, state) do
      case intent do
        %FileSystem.Intents.ReadFile{path: path, user_id: user_id} ->
          case read_file(path, user_id, context) do
            {:ok, content} ->
              new_state = update_in(state.metrics.reads, &(&1 + 1))
              {:ok, new_state, [FileSystemEffect.file_read(path, content)]}
            
            {:error, reason} ->
              new_state = update_in(state.metrics.errors, &(&1 + 1))
              {:error, reason, new_state}
          end

        %FileSystem.Intents.WriteFile{path: path, content: content, user_id: user_id} ->
          case write_file(path, content, user_id, context) do
            {:ok, _} ->
              new_state = update_in(state.metrics.writes, &(&1 + 1))
              {:ok, new_state, [FileSystemEffect.file_written(path)]}
            
            {:error, reason} ->
              new_state = update_in(state.metrics.errors, &(&1 + 1))
              {:error, reason, new_state}
          end
      end
    end

    # Private helper functions
    defp read_file(path, user_id, context) do
      # Check capabilities
      required_cap = FileCap.read(path)
      if has_capability?(context, required_cap) do
        File.read(path)
      else
        {:error, :insufficient_capabilities}
      end
    end

    defp write_file(path, content, user_id, context) do
      # Check capabilities
      required_cap = FileCap.write(path)
      if has_capability?(context, required_cap) do
        File.write(path, content)
      else
        {:error, :insufficient_capabilities}
      end
    end
  end
end
```

### 2. **Supervisors** (Fault Tolerance)
Supervisors manage actors and handle failures. They can restart actors when they crash.

```elixir
defmodule FileSystem.FileSupervisor do
  use PacketFlow.Actor

  # Define a supervisor for file actors
  defsupervisor FileSupervisor do
    @supervision_strategy :one_for_one
    @max_restarts 3
    @max_seconds 5

    def init(_args) do
      children = [
        {FileSystem.FileActor, name: :file_actor_1},
        {FileSystem.FileActor, name: :file_actor_2},
        {FileSystem.FileActor, name: :file_actor_3}
      ]

      Supervisor.init(children, strategy: @supervision_strategy)
    end

    # Handle actor failures
    def handle_actor_failure(actor_pid, reason, state) do
      Logger.warning("Actor #{inspect(actor_pid)} failed: #{inspect(reason)}")
      
      # Restart the actor
      case restart_actor(actor_pid) do
        {:ok, new_pid} ->
          {:ok, Map.put(state, :actors, Map.put(state.actors, actor_pid, new_pid))}
        
        {:error, reason} ->
          {:error, reason, state}
      end
    end
  end
end
```

### 3. **Clustering** (Distributed Coordination)
Actors can form clusters across multiple nodes for load balancing and fault tolerance.

```elixir
defmodule FileSystem.FileCluster do
  use PacketFlow.Actor

  # Define a cluster of file actors
  defcluster FileCluster do
    @cluster_strategy :round_robin
    @node_discovery :automatic

    def init(_args) do
      # Discover nodes in the cluster
      nodes = discover_nodes()
      
      # Start actors on each node
      actors = Enum.map(nodes, fn node ->
        start_actor_on_node(node, FileSystem.FileActor)
      end)

      {:ok, %{actors: actors, nodes: nodes}}
    end

    # Route intents to appropriate actors
    def route_intent(intent, context, state) do
      # Use round-robin strategy to select an actor
      actor = select_actor_round_robin(state.actors)
      
      # Send intent to the selected actor
      PacketFlow.Actor.send_message(actor, {:process_intent, intent, context})
    end

    # Handle node failures
    def handle_node_failure(node, state) do
      Logger.warning("Node #{node} failed, redistributing actors")
      
      # Redistribute actors to remaining nodes
      new_state = redistribute_actors(state, node)
      {:ok, new_state}
    end
  end
end
```

## How It Works

### 1. **Actor Creation and Distribution**
Actors are created and distributed across nodes:

```elixir
# Start actors on different nodes
{:ok, actor1} = PacketFlow.Actor.start_link(FileSystem.FileActor, 
  node: :node1@host, 
  name: :file_actor_1
)

{:ok, actor2} = PacketFlow.Actor.start_link(FileSystem.FileActor, 
  node: :node2@host, 
  name: :file_actor_2
)

# Actors are automatically registered for discovery
PacketFlow.Registry.register_actor(:file_actor_1, actor1)
PacketFlow.Registry.register_actor(:file_actor_2, actor2)
```

### 2. **Message Passing with Capabilities**
Intents are sent to actors with capability checking:

```elixir
# Create an intent
intent = FileSystem.Intents.ReadFile.new("/file.txt", "user123")
context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/file.txt")])

# Send to actor
{:ok, result} = PacketFlow.Actor.send_message(:file_actor_1, {:process_intent, intent, context})

# The actor checks capabilities before processing
# If capabilities are insufficient, it returns an error
```

### 3. **Supervision and Fault Tolerance**
When an actor fails, the supervisor handles it:

```elixir
# If an actor crashes
Process.exit(actor_pid, :kill)

# The supervisor automatically detects the failure
# and restarts the actor with the same state
{:ok, new_actor_pid} = PacketFlow.Actor.Supervisor.restart_actor(actor_pid)
```

### 4. **Cross-Node Communication**
Actors can communicate across nodes:

```elixir
# Send message to actor on different node
{:ok, result} = PacketFlow.Actor.send_message(
  {:file_actor_1, :node2@host}, 
  {:process_intent, intent, context}
)

# Context and capabilities are automatically propagated
# across node boundaries
```

## Advanced Features

### Actor Lifecycle Management

```elixir
defmodule FileSystem.ManagedActor do
  use PacketFlow.Actor

  defactor ManagedActor do
    # Actor initialization
    def init(opts) do
      # Load initial state
      state = load_initial_state(opts)
      
      # Register with registry
      PacketFlow.Registry.register_actor(__MODULE__, self())
      
      {:ok, state}
    end

    # Actor termination
    def terminate(reason, state) do
      # Save state before termination
      save_state(state)
      
      # Unregister from registry
      PacketFlow.Registry.unregister_actor(__MODULE__)
      
      :ok
    end

    # Actor migration (move to different node)
    def migrate(target_node, state) do
      # Save current state
      saved_state = save_state(state)
      
      # Start actor on target node
      {:ok, new_pid} = PacketFlow.Actor.start_link(__MODULE__, 
        node: target_node, 
        state: saved_state
      )
      
      # Stop current actor
      stop_actor()
      
      {:ok, new_pid}
    end
  end
end
```

### Load Balancing

```elixir
defmodule FileSystem.LoadBalancer do
  use PacketFlow.Actor

  defactor LoadBalancer do
    @load_balancing_strategy :least_connections

    def init(_args) do
      # Get all available actors
      actors = PacketFlow.Registry.list_actors(FileSystem.FileActor)
      
      {:ok, %{actors: actors, metrics: %{}}}
    end

    def route_intent(intent, context, state) do
      # Select actor based on load balancing strategy
      actor = select_actor_by_load(state.actors, @load_balancing_strategy)
      
      # Update metrics
      new_metrics = update_metrics(state.metrics, actor)
      
      # Send to selected actor
      PacketFlow.Actor.send_message(actor, {:process_intent, intent, context})
      
      {:ok, %{state | metrics: new_metrics}}
    end

    defp select_actor_by_load(actors, :least_connections) do
      # Select actor with least active connections
      Enum.min_by(actors, &get_connection_count/1)
    end

    defp select_actor_by_load(actors, :round_robin) do
      # Round-robin selection
      Enum.random(actors)
    end
  end
end
```

### Actor State Persistence

```elixir
defmodule FileSystem.PersistentActor do
  use PacketFlow.Actor

  defactor PersistentActor do
    def init(opts) do
      # Load state from persistent storage
      state = load_persistent_state(opts[:actor_id])
      
      # Start periodic state saving
      schedule_state_save()
      
      {:ok, state}
    end

    def handle_info({:save_state}, state) do
      # Save state to persistent storage
      save_persistent_state(state)
      
      # Schedule next save
      schedule_state_save()
      
      {:noreply, state}
    end

    defp schedule_state_save do
      Process.send_after(self(), {:save_state}, 30000)  # Every 30 seconds
    end
  end
end
```

## Integration with Other Substrates

The Actor substrate integrates with other substrates:

- **ADT Substrate**: Actors process ADT intents and contexts
- **Stream Substrate**: Actors can be stream processors
- **Temporal Substrate**: Actors can be scheduled and time-aware
- **Web Framework**: Actors can handle web requests

## Best Practices

### 1. **Design Actor Boundaries**
Think carefully about what each actor should handle:

```elixir
# Good: Clear actor responsibilities
defactor FileActor do
  # Handles file operations only
end

defactor UserActor do
  # Handles user operations only
end

# Avoid: Monolithic actors
defactor MonolithicActor do
  # Handles everything - too complex!
end
```

### 2. **Use Supervision Strategies**
Choose the right supervision strategy for your use case:

```elixir
# One-for-one: Restart only the failed actor
@supervision_strategy :one_for_one

# One-for-all: Restart all actors when one fails
@supervision_strategy :one_for_all

# Rest-for-one: Restart the failed actor and all actors started after it
@supervision_strategy :rest_for_one
```

### 3. **Handle Failures Gracefully**
Always handle actor failures:

```elixir
def handle_actor_failure(actor_pid, reason, state) do
  Logger.warning("Actor failed: #{inspect(reason)}")
  
  # Log the failure
  log_failure(actor_pid, reason)
  
  # Try to restart
  case restart_actor(actor_pid) do
    {:ok, new_pid} -> {:ok, state}
    {:error, reason} -> 
      # Escalate to parent supervisor
      {:error, reason, state}
  end
end
```

### 4. **Monitor Actor Health**
Keep track of actor health:

```elixir
def monitor_actor_health(actor_pid) do
  # Check if actor is alive
  if Process.alive?(actor_pid) do
    # Get actor metrics
    case PacketFlow.Actor.get_metrics(actor_pid) do
      {:ok, metrics} -> 
        # Check if metrics are healthy
        if metrics.health == :healthy do
          :ok
        else
          {:error, :unhealthy_metrics}
        end
      
      {:error, reason} -> 
        {:error, reason}
    end
  else
    {:error, :actor_dead}
  end
end
```

## Common Patterns

### 1. **Worker Pool Pattern**
```elixir
defmodule FileSystem.WorkerPool do
  use PacketFlow.Actor

  defactor WorkerPool do
    def init(_args) do
      # Create pool of workers
      workers = for i <- 1..10 do
        {:ok, pid} = PacketFlow.Actor.start_link(FileSystem.Worker)
        {i, pid}
      end

      {:ok, %{workers: workers, current: 1}}
    end

    def route_intent(intent, context, state) do
      # Round-robin through workers
      {worker_id, worker_pid} = Enum.at(state.workers, state.current - 1)
      
      # Send to worker
      PacketFlow.Actor.send_message(worker_pid, {:process_intent, intent, context})
      
      # Update current worker
      new_current = rem(state.current, length(state.workers)) + 1
      {:ok, %{state | current: new_current}}
    end
  end
end
```

### 2. **Master-Worker Pattern**
```elixir
defmodule FileSystem.MasterWorker do
  use PacketFlow.Actor

  defactor Master do
    def init(_args) do
      # Start workers
      workers = for i <- 1..5 do
        {:ok, pid} = PacketFlow.Actor.start_link(FileSystem.Worker)
        {i, pid}
      end

      {:ok, %{workers: workers, tasks: %{}}}
    end

    def handle_intent(intent, context, state) do
      # Assign task to available worker
      {worker_id, worker_pid} = find_available_worker(state.workers)
      
      # Send task to worker
      task_id = generate_task_id()
      PacketFlow.Actor.send_message(worker_pid, {:process_task, task_id, intent, context})
      
      # Track task
      new_tasks = Map.put(state.tasks, task_id, {worker_id, :pending})
      {:ok, %{state | tasks: new_tasks}}
    end
  end

  defactor Worker do
    def handle_message({:process_task, task_id, intent, context}, state) do
      # Process the task
      result = process_intent(intent, context, state)
      
      # Send result back to master
      PacketFlow.Actor.send_message(:master, {:task_completed, task_id, result})
      
      {:ok, state}
    end
  end
end
```

### 3. **Event Sourcing Pattern**
```elixir
defmodule FileSystem.EventSourcedActor do
  use PacketFlow.Actor

  defactor EventSourcedActor do
    def init(_args) do
      # Load events from event store
      events = load_events()
      
      # Replay events to build state
      state = replay_events(events, %{})
      
      {:ok, state}
    end

    def handle_intent(intent, context, state) do
      # Generate event from intent
      event = intent_to_event(intent, context)
      
      # Apply event to state
      new_state = apply_event(event, state)
      
      # Store event
      store_event(event)
      
      {:ok, new_state, [event]}
    end

    defp intent_to_event(intent, context) do
      case intent do
        %FileSystem.Intents.WriteFile{path: path, content: content} ->
          %FileWritten{path: path, content: content, timestamp: System.system_time()}
        
        %FileSystem.Intents.DeleteFile{path: path} ->
          %FileDeleted{path: path, timestamp: System.system_time()}
      end
    end
  end
end
```

## Testing Your Actor Components

```elixir
defmodule FileSystem.ActorTest do
  use ExUnit.Case
  use PacketFlow.Testing

  test "actor processes intent correctly" do
    # Start test actor
    {:ok, actor_pid} = PacketFlow.Actor.start_link(FileSystem.FileActor)
    
    # Create test intent
    intent = FileSystem.Intents.ReadFile.new("/test.txt", "user123")
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/test.txt")])
    
    # Send intent to actor
    {:ok, result} = PacketFlow.Actor.send_message(actor_pid, {:process_intent, intent, context})
    
    # Verify result
    assert result.status == :ok
    assert result.effects == [FileSystemEffect.file_read("/test.txt", "content")]
  end

  test "actor handles capability failures" do
    # Start test actor
    {:ok, actor_pid} = PacketFlow.Actor.start_link(FileSystem.FileActor)
    
    # Create intent without required capabilities
    intent = FileSystem.Intents.ReadFile.new("/protected.txt", "user123")
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [])  # No capabilities
    
    # Send intent to actor
    {:error, reason} = PacketFlow.Actor.send_message(actor_pid, {:process_intent, intent, context})
    
    # Verify error
    assert reason == :insufficient_capabilities
  end
end
```

## Next Steps

Now that you understand the Actor substrate, you can:

1. **Add Stream Processing**: Process intents in real-time streams across actors
2. **Add Temporal Logic**: Schedule actor operations based on time
3. **Build Web Applications**: Use actors to handle web requests
4. **Scale Your System**: Distribute actors across multiple nodes for high availability

The Actor substrate is your distributed computing foundation - it makes your system scalable and fault-tolerant!
