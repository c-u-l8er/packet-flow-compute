# Stream Substrate Guide

## What is the Stream Substrate?

The **Stream Substrate** is PacketFlow's real-time processing layer. It builds on top of the Actor substrate to provide real-time stream processing with backpressure handling, windowing operations, and capability-aware stream composition.

Think of it as the "real-time processing layer" that allows your intents to be processed as continuous streams of data with automatic flow control and time-based operations.

## Core Concepts

### Stream Processing

Stream processing is a paradigm where:
- **Data flows continuously** as a stream of events
- **Processing happens in real-time** as data arrives
- **Backpressure** prevents overwhelming the system
- **Windowing** groups events by time or count
- **Transformations** modify the stream as it flows

In PacketFlow, streams are enhanced with:
- **Capability-aware processing**
- **Real-time context propagation**
- **Automatic backpressure handling**
- **Time and count-based windowing**

## Key Components

### 1. **Stream Processors** (Real-time Workers)
Stream processors handle continuous flows of intents and events.

```elixir
defmodule FileSystem.FileStream do
  use PacketFlow.Stream

  # Define a file processing stream
  defstream FileStream do
    @stream_config %{
      backpressure_strategy: :drop_oldest,
      window_size: 1000,
      processing_timeout: 5000,
      buffer_size: 10000,
      batch_size: 100
    }

    # Process incoming events
    def process_event(event, context, state) do
      case event do
        %FileSystem.Intents.ReadFile{path: path, user_id: user_id} ->
          case read_file_stream(path, user_id, context) do
            {:ok, content} ->
              # Update metrics
              new_metrics = update_in(state.metrics.reads, &(&1 + 1))
              
              # Emit processed event
              emit_event(%FileReadEvent{
                path: path,
                content: content,
                timestamp: System.system_time()
              })
              
              {:ok, %{state | metrics: new_metrics}, [FileSystemEffect.file_read(path, content)]}
            
            {:error, reason} ->
              new_metrics = update_in(state.metrics.errors, &(&1 + 1))
              {:error, reason, %{state | metrics: new_metrics}}
          end

        %FileSystem.Intents.WriteFile{path: path, content: content, user_id: user_id} ->
          case write_file_stream(path, content, user_id, context) do
            {:ok, _} ->
              new_metrics = update_in(state.metrics.writes, &(&1 + 1))
              
              emit_event(%FileWriteEvent{
                path: path,
                timestamp: System.system_time()
              })
              
              {:ok, %{state | metrics: new_metrics}, [FileSystemEffect.file_written(path)]}
            
            {:error, reason} ->
              new_metrics = update_in(state.metrics.errors, &(&1 + 1))
              {:error, reason, %{state | metrics: new_metrics}}
          end
      end
    end

    # Handle backpressure events
    def handle_backpressure(event, state) do
      case event do
        {:buffer_full, count} ->
          Logger.warning("Stream buffer full, dropping oldest #{count} events")
          # Drop oldest events from buffer
          new_buffer = drop_oldest_events(state.buffer, count)
          %{state | buffer: new_buffer}
        
        {:processing_slow, avg_time} ->
          Logger.warning("Stream processing slow, avg time: #{avg_time}ms")
          # Adjust processing strategy
          new_config = adjust_processing_config(state.config, avg_time)
          %{state | config: new_config}
      end
    end

    # Handle window tick events
    def process_window_tick(state) do
      # Process accumulated events in window
      window_events = get_window_events(state.buffer, state.config.window_size)
      
      case process_window(window_events, state) do
        {:ok, results} ->
          # Emit window results
          emit_window_results(results)
          %{state | buffer: clear_window_events(state.buffer)}
        
        {:error, reason} ->
          Logger.error("Window processing failed: #{inspect(reason)}")
          state
      end
    end

    # Private helper functions
    defp read_file_stream(path, user_id, context) do
      # Check capabilities
      required_cap = FileCap.read(path)
      if has_capability?(context, required_cap) do
        File.read(path)
      else
        {:error, :insufficient_capabilities}
      end
    end

    defp write_file_stream(path, content, user_id, context) do
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

### 2. **Windowing Operations** (Time and Count-based)
Windowing groups events by time or count for batch processing.

```elixir
defmodule FileSystem.FileWindowing do
  use PacketFlow.Stream

  # Define time-based windowing
  defwindow TimeWindow do
    @window_type :time
    @window_size 60000  # 1 minute

    def process_window(events, state) do
      # Group events by file path
      grouped_events = Enum.group_by(events, & &1.path)
      
      # Process each group
      results = Enum.map(grouped_events, fn {path, path_events} ->
        process_file_events(path, path_events)
      end)
      
      {:ok, results}
    end

    defp process_file_events(path, events) do
      # Count operations by type
      read_count = Enum.count(events, &match?(%FileSystem.Intents.ReadFile{}, &1))
      write_count = Enum.count(events, &match?(%FileSystem.Intents.WriteFile{}, &1))
      
      %FileActivitySummary{
        path: path,
        read_count: read_count,
        write_count: write_count,
        timestamp: System.system_time()
      }
    end
  end

  # Define count-based windowing
  defwindow CountWindow do
    @window_type :count
    @window_size 100  # 100 events

    def process_window(events, state) do
      # Calculate processing statistics
      total_events = length(events)
      avg_processing_time = calculate_avg_processing_time(events)
      
      %ProcessingStats{
        total_events: total_events,
        avg_processing_time: avg_processing_time,
        timestamp: System.system_time()
      }
    end
  end
end
```

### 3. **Backpressure Handling** (Flow Control)
Backpressure prevents the system from being overwhelmed by incoming data.

```elixir
defmodule FileSystem.FileBackpressure do
  use PacketFlow.Stream

  # Define backpressure strategies
  defbackpressure AdaptiveBackpressure do
    @strategy :adaptive
    @max_buffer_size 10000
    @min_processing_rate 100

    def handle_backpressure(event, state) do
      case event do
        {:buffer_full, count} ->
          # Adaptive strategy: adjust processing rate
          new_rate = calculate_adaptive_rate(state.metrics, count)
          new_config = %{state.config | processing_rate: new_rate}
          %{state | config: new_config}
        
        {:processing_slow, avg_time} ->
          # Reduce batch size to improve responsiveness
          new_batch_size = max(state.config.batch_size div 2, 10)
          new_config = %{state.config | batch_size: new_batch_size}
          %{state | config: new_config}
        
        {:memory_pressure, usage} ->
          # Drop oldest events to free memory
          events_to_drop = calculate_drop_count(usage)
          new_buffer = drop_oldest_events(state.buffer, events_to_drop)
          %{state | buffer: new_buffer}
      end
    end

    defp calculate_adaptive_rate(metrics, buffer_count) do
      # Calculate optimal processing rate based on metrics
      current_rate = metrics.processing_rate
      target_rate = max(current_rate * 0.8, @min_processing_rate)
      
      if buffer_count > @max_buffer_size * 0.8 do
        target_rate * 0.9  # Reduce rate when buffer is getting full
      else
        target_rate * 1.1  # Increase rate when buffer has space
      end
    end
  end
end
```

## How It Works

### 1. **Stream Creation and Configuration**
Streams are created with specific configurations:

```elixir
# Create a file processing stream
{:ok, stream_pid} = PacketFlow.Stream.start_link(FileSystem.FileStream, 
  backpressure_strategy: :drop_oldest,
  window_size: 1000,
  processing_timeout: 5000,
  buffer_size: 10000,
  batch_size: 100
)

# Register stream for discovery
PacketFlow.Registry.register_stream(:file_stream, stream_pid)
```

### 2. **Event Processing with Backpressure**
Events flow through the stream with automatic backpressure handling:

```elixir
# Send events to stream
events = [
  FileSystem.Intents.ReadFile.new("/file1.txt", "user123"),
  FileSystem.Intents.WriteFile.new("/file2.txt", "content", "user123"),
  FileSystem.Intents.ReadFile.new("/file3.txt", "user123")
]

# Stream processes events with backpressure control
Enum.each(events, fn event ->
  context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/")])
  PacketFlow.Stream.send_event(stream_pid, event, context)
end)

# If the stream gets overwhelmed, backpressure kicks in
# and events are dropped or processing is slowed down
```

### 3. **Windowing and Batch Processing**
Events are grouped into windows for batch processing:

```elixir
# Time-based windowing (process every minute)
{:ok, time_window} = PacketFlow.Stream.Windowing.start_link(FileSystem.FileWindowing.TimeWindow)

# Count-based windowing (process every 100 events)
{:ok, count_window} = PacketFlow.Stream.Windowing.start_link(FileSystem.FileWindowing.CountWindow)

# Windows automatically trigger processing
# and emit aggregated results
```

### 4. **Real-time Monitoring and Metrics**
Streams provide real-time metrics and monitoring:

```elixir
# Get stream metrics
{:ok, metrics} = PacketFlow.Stream.get_metrics(stream_pid)

# Metrics include:
# - Processing rate (events/second)
# - Buffer utilization
# - Average processing time
# - Error rate
# - Backpressure events

# Monitor stream health
health = PacketFlow.Stream.health_check(stream_pid)
# => :healthy | :unhealthy | :degraded
```

## Advanced Features

### Stream Composition

```elixir
defmodule FileSystem.ComposedStream do
  use PacketFlow.Stream

  # Compose multiple streams
  defcompose FileProcessingPipeline do
    @streams [
      FileSystem.FileStream,
      FileSystem.FileWindowing.TimeWindow,
      FileSystem.FileBackpressure.AdaptiveBackpressure
    ]

    def init(_args) do
      # Start all component streams
      streams = Enum.map(@streams, fn stream_module ->
        {:ok, pid} = PacketFlow.Stream.start_link(stream_module)
        {stream_module, pid}
      end)

      {:ok, %{streams: streams}}
    end

    def process_event(event, context, state) do
      # Process through pipeline
      Enum.reduce_while(state.streams, {event, context}, fn {_module, pid}, {event, context} ->
        case PacketFlow.Stream.send_event(pid, event, context) do
          {:ok, processed_event, new_context} ->
            {:cont, {processed_event, new_context}}
          
          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end
  end
end
```

### Stream Transformations

```elixir
defmodule FileSystem.StreamTransformations do
  use PacketFlow.Stream

  # Transform stream events
  deftransform FileEventTransformer do
    def transform_event(event, context) do
      case event do
        %FileSystem.Intents.ReadFile{path: path} ->
          # Add metadata to read events
          %{event | metadata: %{operation: :read, timestamp: System.system_time()}}
        
        %FileSystem.Intents.WriteFile{path: path, content: content} ->
          # Validate content before processing
          case validate_content(content) do
            :ok -> 
              %{event | metadata: %{operation: :write, timestamp: System.system_time()}}
            
            {:error, reason} ->
              {:error, reason}
          end
      end
    end

    defp validate_content(content) do
      if byte_size(content) > 1024 * 1024 do  # 1MB limit
        {:error, :content_too_large}
      else
        :ok
      end
    end
  end
end
```

### Stream Filtering

```elixir
defmodule FileSystem.StreamFilters do
  use PacketFlow.Stream

  # Filter stream events
  defilter FileEventFilter do
    def filter_event(event, context) do
      case event do
        %FileSystem.Intents.ReadFile{path: path} ->
          # Only process files in allowed directories
          if String.starts_with?(path, "/allowed/") do
            {:ok, event}
          else
            {:error, :access_denied}
          end
        
        %FileSystem.Intents.WriteFile{path: path} ->
          # Block writes to system directories
          if String.starts_with?(path, "/system/") do
            {:error, :system_directory_protected}
          else
            {:ok, event}
          end
      end
    end
  end
end
```

## Integration with Other Substrates

The Stream substrate integrates with other substrates:

- **ADT Substrate**: Streams process ADT intents and contexts
- **Actor Substrate**: Streams can be distributed across actors
- **Temporal Substrate**: Streams can be time-aware and scheduled
- **Web Framework**: Streams can provide real-time updates to web interfaces

## Best Practices

### 1. **Design Stream Boundaries**
Think carefully about what each stream should handle:

```elixir
# Good: Clear stream responsibilities
defstream FileReadStream do
  # Handles file read operations only
end

defstream FileWriteStream do
  # Handles file write operations only
end

# Avoid: Monolithic streams
defstream MonolithicStream do
  # Handles everything - too complex!
end
```

### 2. **Configure Backpressure Appropriately**
Choose the right backpressure strategy for your use case:

```elixir
# Drop oldest events (for real-time processing)
@backpressure_strategy :drop_oldest

# Block and wait (for critical data)
@backpressure_strategy :block

# Adaptive (for dynamic workloads)
@backpressure_strategy :adaptive
```

### 3. **Use Appropriate Windowing**
Choose the right windowing strategy:

```elixir
# Time-based windowing (for time-series data)
@window_type :time
@window_size 60000  # 1 minute

# Count-based windowing (for batch processing)
@window_type :count
@window_size 1000   # 1000 events

# Session-based windowing (for user sessions)
@window_type :session
@window_size 3600000  # 1 hour
```

### 4. **Monitor Stream Performance**
Keep track of stream health and performance:

```elixir
def monitor_stream_performance(stream_pid) do
  # Get stream metrics
  case PacketFlow.Stream.get_metrics(stream_pid) do
    {:ok, metrics} ->
      # Check processing rate
      if metrics.processing_rate < 100 do
        Logger.warning("Stream processing rate too low: #{metrics.processing_rate}")
      end
      
      # Check buffer utilization
      if metrics.buffer_utilization > 0.8 do
        Logger.warning("Stream buffer utilization high: #{metrics.buffer_utilization}")
      end
      
      # Check error rate
      if metrics.error_rate > 0.05 do
        Logger.error("Stream error rate too high: #{metrics.error_rate}")
      end
    
    {:error, reason} ->
      Logger.error("Failed to get stream metrics: #{inspect(reason)}")
  end
end
```

## Common Patterns

### 1. **Event Sourcing Stream**
```elixir
defmodule FileSystem.EventSourcingStream do
  use PacketFlow.Stream

  defstream EventSourcingStream do
    def process_event(event, context, state) do
      # Convert intent to event
      domain_event = intent_to_event(event)
      
      # Store event
      store_event(domain_event)
      
      # Apply event to state
      new_state = apply_event(domain_event, state)
      
      # Emit event
      emit_event(domain_event)
      
      {:ok, new_state, [domain_event]}
    end

    defp intent_to_event(intent) do
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

### 2. **CQRS Stream**
```elixir
defmodule FileSystem.CQRSStream do
  use PacketFlow.Stream

  defstream CQRSStream do
    def process_event(event, context, state) do
      case event do
        # Commands (write side)
        %FileSystem.Intents.WriteFile{} ->
          # Process command
          {:ok, new_state, [command_processed_event(event)]}
        
        # Queries (read side)
        %FileSystem.Intents.ReadFile{} ->
          # Handle query
          {:ok, state, [query_result_event(event)]}
      end
    end
  end
end
```

### 3. **Real-time Analytics Stream**
```elixir
defmodule FileSystem.AnalyticsStream do
  use PacketFlow.Stream

  defstream AnalyticsStream do
    def process_event(event, context, state) do
      # Update real-time metrics
      new_metrics = update_metrics(state.metrics, event)
      
      # Emit analytics event
      analytics_event = %FileAnalyticsEvent{
        operation: get_operation_type(event),
        user_id: context.user_id,
        timestamp: System.system_time(),
        metrics: new_metrics
      }
      
      emit_event(analytics_event)
      
      {:ok, %{state | metrics: new_metrics}, [analytics_event]}
    end

    defp get_operation_type(event) do
      case event do
        %FileSystem.Intents.ReadFile{} -> :read
        %FileSystem.Intents.WriteFile{} -> :write
        %FileSystem.Intents.DeleteFile{} -> :delete
      end
    end
  end
end
```

## Testing Your Stream Components

```elixir
defmodule FileSystem.StreamTest do
  use ExUnit.Case
  use PacketFlow.Testing

  test "stream processes events correctly" do
    # Start test stream
    {:ok, stream_pid} = PacketFlow.Stream.start_link(FileSystem.FileStream)
    
    # Send test events
    events = [
      FileSystem.Intents.ReadFile.new("/test1.txt", "user123"),
      FileSystem.Intents.WriteFile.new("/test2.txt", "content", "user123"),
      FileSystem.Intents.ReadFile.new("/test3.txt", "user123")
    ]
    
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/"), FileCap.write("/")])
    
    # Process events
    results = Enum.map(events, fn event ->
      PacketFlow.Stream.send_event(stream_pid, event, context)
    end)
    
    # Verify results
    assert Enum.all?(results, fn {:ok, _} -> true; _ -> false end)
  end

  test "stream handles backpressure correctly" do
    # Start test stream with small buffer
    {:ok, stream_pid} = PacketFlow.Stream.start_link(FileSystem.FileStream, buffer_size: 5)
    
    # Send more events than buffer can handle
    events = for i <- 1..10 do
      FileSystem.Intents.ReadFile.new("/test#{i}.txt", "user123")
    end
    
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/")])
    
    # Send events rapidly
    Enum.each(events, fn event ->
      PacketFlow.Stream.send_event(stream_pid, event, context)
    end)
    
    # Verify backpressure was handled
    {:ok, metrics} = PacketFlow.Stream.get_metrics(stream_pid)
    assert metrics.backpressure_events > 0
  end
end
```

## Next Steps

Now that you understand the Stream substrate, you can:

1. **Add Temporal Logic**: Make your streams time-aware with scheduling
2. **Build Web Applications**: Use streams for real-time web updates
3. **Scale Your System**: Distribute streams across multiple nodes
4. **Add Analytics**: Use streams for real-time analytics and monitoring

The Stream substrate is your real-time processing foundation - it makes your system responsive and data-driven!
