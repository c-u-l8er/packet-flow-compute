defmodule PacketFlow.StreamTest do
  use ExUnit.Case
  use PacketFlow.Stream

  # Test stream processor
  defstream TestFileStream do
    def process_event(event, _context, state) do
      case event do
        %{type: :file_read, path: path} ->
          {:ok, Map.put(state, :last_read, path), []}

        %{type: :file_write, path: path, content: content} ->
          {:ok, Map.put(state, :last_written, {path, content}), []}

        %{type: :file_delete, path: path} ->
          {:ok, Map.put(state, :last_deleted, path), []}

        _ ->
          {:error, :unknown_event_type}
      end
    end

    def handle_backpressure(_event, state) do
      # Custom backpressure handling
      Map.put(state, :backpressure_handled, true)
    end

    def process_window_tick(state) do
      # Custom window processing
      Map.put(state, :window_processed, true)
    end
  end

  # Test stream transformation
  deftransform TestFileTransform do
    def transform(event, context, state) do
      case event do
        %{type: :file_read, path: path} ->
          # Transform read events
          transformed = %{event | path: String.upcase(path)}
          {:ok, transformed, state}

        %{type: :file_write, path: path, content: content} ->
          # Transform write events
          transformed = %{event | content: String.upcase(content)}
          {:ok, transformed, state}

        _ ->
          {:ok, event, state}
      end
    end

    defp transform_event(event) do
      # Default transformation
      event
    end
  end

  # Test windowing operation
  defwindow TestTimeWindow, %{type: :time, duration: 5000} do
    defp process_window_contents(window) do
      # Process window contents
      Enum.map(window.events, fn event ->
        case event do
          %{type: :file_read} -> Map.put(event, :processed, true)
          %{type: :file_write} -> Map.put(event, :processed, true)
          _ -> Map.put(event, :processed, false)
        end
      end)
    end
  end

  # Test backpressure strategy
  defbackpressure TestDropOldestStrategy, :drop_oldest do
    def handle_drop_oldest(event, state) do
      # Custom drop oldest implementation
      buffer = state.buffer
      max_size = Map.get(state.config, :max_buffer_size, 5)

      if length(buffer) >= max_size do
        [_oldest | rest] = buffer
        %{state | buffer: [event | rest], dropped_count: Map.get(state, :dropped_count, 0) + 1}
      else
        %{state | buffer: [event | buffer]}
      end
    end
  end

  # Test stream monitor
  defmonitor TestFileMonitor do
    def collect_metrics(stream_state) do
      %{
        buffer_size: length(stream_state.buffer),
        processing_rate: calculate_processing_rate(stream_state),
        error_rate: calculate_error_rate(stream_state),
        latency: calculate_latency(stream_state),
        custom_metric: Map.get(stream_state.metrics, :custom_metric, 0)
      }
    end

    defp calculate_processing_rate(state) do
      # Custom processing rate calculation
      processed = Map.get(state.metrics, :processed_count, 0)
      if processed > 0, do: processed * 2, else: 0
    end

    defp calculate_error_rate(state) do
      # Custom error rate calculation
      errors = Map.get(state.metrics, :error_count, 0)
      total = Map.get(state.metrics, :processed_count, 0) + errors
      if total > 0, do: errors / total * 100, else: 0
    end

    defp calculate_latency(state) do
      # Custom latency calculation
      Map.get(state.metrics, :avg_latency, 0) * 1.5
    end
  end

  describe "Stream Processing" do
    test "defstream creates stream processor with processing pipeline" do
      # Test stream creation
      assert Code.ensure_loaded?(TestFileStream)

      # Test event processing
      event = %{type: :file_read, path: "/test/file"}
      context = %{user_id: "user123"}
      state = %{config: %{}, buffer: [], metrics: %{}}

      {:ok, new_state, effects} = TestFileStream.process_event(event, context, state)
      assert new_state.last_read == "/test/file"
      assert effects == []

      # Test write event
      event2 = %{type: :file_write, path: "/test/file2", content: "content"}
      {:ok, new_state2, effects2} = TestFileStream.process_event(event2, context, new_state)
      assert new_state2.last_written == {"/test/file2", "content"}
      assert effects2 == []

      # Test unknown event
      event3 = %{type: :unknown, path: "/test/file3"}
      {:error, reason} = TestFileStream.process_event(event3, context, new_state2)
      assert reason == :unknown_event_type
    end

    test "deftransform creates stream transformation" do
      # Test transform creation
      assert Code.ensure_loaded?(TestFileTransform)

      # Test single event transformation
      event = %{type: :file_read, path: "/test/file"}
      context = %{user_id: "user123"}
      state = %{}

      {:ok, transformed, new_state} = TestFileTransform.transform(event, context, state)
      assert transformed.path == "/TEST/FILE"
      assert new_state == state

      # Test write transformation
      event2 = %{type: :file_write, path: "/test/file2", content: "content"}
      {:ok, transformed2, _new_state2} = TestFileTransform.transform(event2, context, state)
      assert transformed2.content == "CONTENT"

      # Test batch transformation
      events = [
        %{type: :file_read, path: "/test/file1"},
        %{type: :file_write, path: "/test/file2", content: "content"}
      ]
      {:ok, transformed_batch, _new_state3} = TestFileTransform.transform_batch(events, context, state)
      assert length(transformed_batch) == 2
      # Note: transform_batch uses transform_event which doesn't transform
      assert Enum.at(transformed_batch, 0).path == "/test/file1"
      assert Enum.at(transformed_batch, 1).content == "content"
    end
  end

  describe "Stream Windowing" do
    test "defwindow creates windowing operation" do
      # Test window creation
      assert Code.ensure_loaded?(TestTimeWindow)

      # Test time window creation
      {:ok, time_window} = TestTimeWindow.create_window(:time, 5000)
      assert time_window.type == :time
      assert time_window.size == 5000
      assert Map.has_key?(time_window, :start_time)
      assert time_window.events == []

      # Test count window creation
      {:ok, count_window} = TestTimeWindow.create_window(:count, 100)
      assert count_window.type == :count
      assert count_window.size == 100
      assert count_window.events == []

      # Test session window creation
      {:ok, session_window} = TestTimeWindow.create_window(:session, 30000)
      assert session_window.type == :session
      assert session_window.timeout == 30000
      assert Map.has_key?(session_window, :last_event_time)
      assert session_window.events == []

      # Test unknown window type
      {:error, reason} = TestTimeWindow.create_window(:unknown, 100)
      assert reason == :unknown_window_type
    end

    test "window supports adding events" do
      # Test adding events to time window
      {:ok, window} = TestTimeWindow.create_window(:time, 5000)
      event = %{type: :file_read, path: "/test/file"}

      {:ok, updated_window} = TestTimeWindow.add_to_window(window, event)
      assert length(updated_window.events) == 1
      assert Enum.at(updated_window.events, 0) == event

      # Test adding multiple events
      event2 = %{type: :file_write, path: "/test/file2", content: "content"}
      {:ok, updated_window2} = TestTimeWindow.add_to_window(updated_window, event2)
      assert length(updated_window2.events) == 2
    end

    test "window supports processing contents" do
      # Test window processing
      {:ok, window} = TestTimeWindow.create_window(:time, 5000)
      events = [
        %{type: :file_read, path: "/test/file1"},
        %{type: :file_write, path: "/test/file2", content: "content"}
      ]

      # Add events to window
      updated_window = Enum.reduce(events, window, fn event, acc ->
        {:ok, acc} = TestTimeWindow.add_to_window(acc, event)
        acc
      end)

      # Process window
      {:ok, result} = TestTimeWindow.process_window(updated_window)
      assert length(result) == 2
      # Check that events were processed (have :processed key set to true)
      assert Enum.all?(result, fn event ->
        Map.get(event, :processed, false) == true
      end)
    end
  end

  describe "Stream Backpressure" do
    test "defbackpressure creates backpressure strategy" do
      # Test backpressure creation
      assert Code.ensure_loaded?(TestDropOldestStrategy)

      # Test drop oldest strategy
      event = %{type: :file_read, path: "/test/file"}
      state = %{
        config: %{max_buffer_size: 3},
        buffer: [%{old1: true}, %{old2: true}, %{old3: true}],
        metrics: %{},
        dropped_count: 0
      }

      new_state = TestDropOldestStrategy.handle_backpressure(event, state)
      assert length(new_state.buffer) == 3
      assert Map.get(new_state, :dropped_count, 0) == 1
      assert Enum.at(new_state.buffer, 0) == event

      # Test buffer not full
      state2 = %{
        config: %{max_buffer_size: 5},
        buffer: [%{old1: true}],
        metrics: %{}
      }

      new_state2 = TestDropOldestStrategy.handle_backpressure(event, state2)
      assert length(new_state2.buffer) == 2
      assert Map.get(new_state2, :dropped_count) == nil
    end

    test "backpressure supports different strategies" do
      # Test drop newest strategy
      event = %{type: :file_read, path: "/test/file"}
      state = %{
        config: %{max_buffer_size: 3},
        buffer: [%{old1: true}, %{old2: true}, %{old3: true}],
        metrics: %{}
      }

      new_state = TestDropOldestStrategy.handle_drop_newest(event, state)
      assert length(new_state.buffer) == 3
      assert Enum.at(new_state.buffer, 0) == %{old1: true}

      # Test block strategy
      {:error, reason} = TestDropOldestStrategy.handle_block(event, state)
      assert reason == :backpressure_blocked

      # Test buffer strategy
      new_state2 = TestDropOldestStrategy.handle_buffer(event, state)
      assert length(new_state2.buffer) == 4
    end
  end

  describe "Stream Monitoring" do
    test "defmonitor creates stream monitor" do
      # Test monitor creation
      assert Code.ensure_loaded?(TestFileMonitor)

      # Test metrics collection
      stream_state = %{
        buffer: [%{event1: true}, %{event2: true}],
        metrics: %{
          processed_count: 100,
          error_count: 5,
          avg_latency: 50,
          custom_metric: 42
        }
      }

      metrics = TestFileMonitor.collect_metrics(stream_state)
      assert metrics.buffer_size == 2
      assert metrics.processing_rate == 200  # processed_count * 2
      assert_in_delta metrics.error_rate, 4.76, 0.01  # (5 / 105) * 100
      assert metrics.latency == 75  # avg_latency * 1.5
      assert metrics.custom_metric == 42
    end

    test "monitor supports metrics updates" do
      # Test metrics updates
      stream_state = %{
        buffer: [],
        metrics: %{processed_count: 10, error_count: 2}
      }

      # Test processed event update
      updated_state = TestFileMonitor.update_metrics(stream_state, :processed)
      assert updated_state.metrics.processed_count == 11

      # Test error event update
      updated_state2 = TestFileMonitor.update_metrics(updated_state, :error)
      assert updated_state2.metrics.error_count == 3

      # Test backpressure event update
      updated_state3 = TestFileMonitor.update_metrics(updated_state2, :backpressure)
      assert updated_state3.metrics.backpressure_count == 1
    end
  end

  describe "Stream Integration with Actor" do
    test "streams can process actor events" do
      # Test stream processing actor events
      event = %{type: :file_read, path: "/test/file", actor_id: "actor1"}
      context = %{user_id: "user123", session_id: "session123"}
      state = %{config: %{}, buffer: [], metrics: %{}}

      {:ok, new_state, effects} = TestFileStream.process_event(event, context, state)
      assert new_state.last_read == "/test/file"
      assert effects == []
    end

    test "streams support capability-aware processing" do
      # Test capability-aware stream processing
      event = %{
        type: :file_write,
        path: "/test/file",
        content: "content",
        capabilities: [:write]
      }
      context = %{user_id: "user123", capabilities: [:read, :write]}
      state = %{config: %{}, buffer: [], metrics: %{}}

      {:ok, new_state, effects} = TestFileStream.process_event(event, context, state)
      assert new_state.last_written == {"/test/file", "content"}
      assert effects == []
    end
  end
end
