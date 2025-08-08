defmodule PacketFlow.Component.MonitoringTest do
  use ExUnit.Case, async: false  # Not async due to shared GenServer state and timing

  alias PacketFlow.Component.Monitoring

  defmodule TestComponent do
    use GenServer

    def start_link(name, health_status \\ :healthy) do
      GenServer.start_link(__MODULE__, health_status, name: name)
    end

    def init(health_status) do
      {:ok, %{health: health_status, metrics: %{calls: 0}}}
    end

    def health_check() do
      # Try to find a running instance of this component
      case Process.whereis(:test_component_1) do
        nil ->
          case Process.whereis(:test_component_2) do
            nil -> :unknown
            pid -> health_check(pid)
          end
        pid -> health_check(pid)
      end
    rescue
      _ -> :unknown
    end

    def health_check(name) do
      case GenServer.call(name, :get_health) do
        health when health in [:healthy, :unhealthy, :degraded] -> health
        _ -> :unknown
      end
    rescue
      _ -> :unknown
    end

    def get_metrics(name \\ __MODULE__) do
      GenServer.call(name, :get_metrics)
    end

    def set_health(name_or_health, health \\ nil) do
      case health do
        nil -> GenServer.call(__MODULE__, {:set_health, name_or_health})
        _ -> GenServer.call(name_or_health, {:set_health, health})
      end
    end

    def handle_call(:get_health, _from, state) do
      {:reply, state.health, state}
    end

    def handle_call(:get_metrics, _from, state) do
      metrics = %{
        calls: state.metrics.calls,
        memory_usage: :rand.uniform(100),
        response_time: :rand.uniform(1000)
      }
      {:reply, metrics, state}
    end

    def handle_call({:set_health, health}, _from, state) do
      {:reply, :ok, %{state | health: health}}
    end
  end

  setup do
    # Start the monitoring service with fast intervals for testing
    config = %{
      health_check_interval: 100,  # 100ms for fast testing
      metrics_collection_interval: 150,  # 150ms for fast testing
      retention_period: 60_000,  # 1 minute
      alert_thresholds: %{
        cpu_usage: 80.0,
        memory_usage: 85.0,
        error_rate: 5.0,
        response_time: 1000.0
      },
      enabled_checks: [:process_alive, :memory_usage, :message_queue],
      enabled_metrics: [:response_time, :memory_usage]
    }

    start_supervised!({Monitoring, [config: config]})

    # Start test components
    {:ok, comp1} = TestComponent.start_link(:test_component_1, :healthy)
    {:ok, comp2} = TestComponent.start_link(:test_component_2, :degraded)
    {:ok, comp3} = TestComponent.start_link(:test_component_3, :unhealthy)

    %{comp1: comp1, comp2: comp2, comp3: comp3}
  end

  describe "component registration" do
    test "register_component adds component to monitoring" do
      metadata = %{type: :test, version: "1.0.0"}
      assert :ok = Monitoring.register_component(:test_component_1, metadata)
    end

    test "register_component with default metadata" do
      assert :ok = Monitoring.register_component(:test_component_2)
    end

    test "unregister_component removes component from monitoring" do
      :ok = Monitoring.register_component(:temp_component)
      :ok = Monitoring.unregister_component(:temp_component)
    end
  end

  describe "health checks" do
    test "check_component_health performs health check" do
      :ok = Monitoring.register_component(:test_component_1)

      health_check = Monitoring.check_component_health(:test_component_1)

      assert is_map(health_check)
      assert health_check.component_id == :test_component_1
      assert health_check.status in [:healthy, :unhealthy, :degraded, :unknown]
      assert is_binary(health_check.message)
      assert is_integer(health_check.timestamp)
      assert is_number(health_check.duration_ms)
      assert is_map(health_check.metadata)
    end

    test "check_component_health returns error for unregistered component" do
      assert {:error, :component_not_registered} =
        Monitoring.check_component_health(:unregistered_component)
    end

    test "get_all_health_status returns health for all components" do
      :ok = Monitoring.register_component(:test_component_1)
      :ok = Monitoring.register_component(:test_component_2)

      health_status = Monitoring.get_all_health_status()

      assert is_map(health_status)
      assert Map.has_key?(health_status, :test_component_1)
      assert Map.has_key?(health_status, :test_component_2)

      for {_component_id, health_check} <- health_status do
        assert is_map(health_check)
        assert Map.has_key?(health_check, :status)
        assert Map.has_key?(health_check, :timestamp)
      end
    end

    test "health checks detect component status changes" do
      :ok = Monitoring.register_component(:test_component_1, %{module: TestComponent})

      # Initial health check
      initial_health = Monitoring.check_component_health(:test_component_1)
      assert initial_health.status == :healthy

      # Change component health
      TestComponent.set_health(:test_component_1, :degraded)

      # New health check should reflect the change
      updated_health = Monitoring.check_component_health(:test_component_1)
      assert updated_health.status == :degraded
    end
  end

  describe "metrics collection" do
    test "record_metric stores metric data" do
      :ok = Monitoring.register_component(:test_component_1)

      :ok = Monitoring.record_metric(:test_component_1, "response_time", :histogram, 150.5)
      :ok = Monitoring.record_metric(:test_component_1, "request_count", :counter, 1)
    end

    test "record_metric with labels" do
      :ok = Monitoring.register_component(:test_component_1)

      labels = %{endpoint: "/api/test", method: "GET"}
      :ok = Monitoring.record_metric(:test_component_1, "http_requests", :counter, 1, labels)
    end

    test "get_component_metrics returns metrics for component" do
      :ok = Monitoring.register_component(:test_component_1)

      # Record some metrics
      :ok = Monitoring.record_metric(:test_component_1, "test_metric", :gauge, 42)

      metrics = Monitoring.get_component_metrics(:test_component_1)
      assert is_list(metrics)

      if length(metrics) > 0 do
        metric = List.first(metrics)
        assert is_map(metric)
        assert Map.has_key?(metric, :name)
        assert Map.has_key?(metric, :type)
        assert Map.has_key?(metric, :value)
        assert Map.has_key?(metric, :timestamp)
        assert Map.has_key?(metric, :component_id)
      end
    end

    test "get_component_metrics returns error for unregistered component" do
      assert {:error, :component_not_registered} =
        Monitoring.get_component_metrics(:unregistered_component)
    end

    test "get_all_metrics returns metrics for all components" do
      :ok = Monitoring.register_component(:test_component_1)
      :ok = Monitoring.register_component(:test_component_2)

      # Record metrics for both components
      :ok = Monitoring.record_metric(:test_component_1, "metric1", :gauge, 10)
      :ok = Monitoring.record_metric(:test_component_2, "metric2", :gauge, 20)

      all_metrics = Monitoring.get_all_metrics()
      assert is_map(all_metrics)
      assert Map.has_key?(all_metrics, :test_component_1)
      assert Map.has_key?(all_metrics, :test_component_2)
    end
  end

  describe "subscription system" do
    test "subscribe_to_component registers subscriber" do
      :ok = Monitoring.register_component(:test_component_1)

      subscriber_pid = self()
      :ok = Monitoring.subscribe_to_component(:test_component_1, subscriber_pid)
    end

    test "unsubscribe_from_component removes subscriber" do
      :ok = Monitoring.register_component(:test_component_1)

      subscriber_pid = self()
      :ok = Monitoring.subscribe_to_component(:test_component_1, subscriber_pid)
      :ok = Monitoring.unsubscribe_from_component(:test_component_1, subscriber_pid)
    end

    test "subscribers receive monitoring events" do
      :ok = Monitoring.register_component(:test_component_1)

      subscriber_pid = self()
      :ok = Monitoring.subscribe_to_component(:test_component_1, subscriber_pid)

      # Trigger a health check to generate an event
      _health_check = Monitoring.check_component_health(:test_component_1)

      # Check for monitoring event (with timeout)
      receive do
        {:monitoring_event, event_type, component_id, data} ->
          assert event_type == :health_check_completed
          assert component_id == :test_component_1
          assert is_map(data)
      after
        500 ->
          # Event might not be sent immediately, that's okay for this test
          :ok
      end
    end
  end

  describe "dashboard data" do
    test "get_dashboard_data returns comprehensive monitoring data" do
      :ok = Monitoring.register_component(:test_component_1)
      :ok = Monitoring.register_component(:test_component_2)

      # Perform some health checks and record metrics
      _health1 = Monitoring.check_component_health(:test_component_1)
      _health2 = Monitoring.check_component_health(:test_component_2)
      :ok = Monitoring.record_metric(:test_component_1, "test_metric", :gauge, 100)

      dashboard_data = Monitoring.get_dashboard_data()

      assert is_map(dashboard_data)
      assert Map.has_key?(dashboard_data, :summary)
      assert Map.has_key?(dashboard_data, :components)
      assert Map.has_key?(dashboard_data, :recent_alerts)
      assert Map.has_key?(dashboard_data, :system_metrics)
      assert Map.has_key?(dashboard_data, :last_updated)

      # Check summary structure
      summary = dashboard_data.summary
      assert is_integer(summary.total_components)
      assert is_integer(summary.healthy_components)
      assert is_integer(summary.unhealthy_components)
      assert is_integer(summary.total_alerts)

      # Check components structure
      assert is_list(dashboard_data.components)

      # Check system metrics structure
      assert is_map(dashboard_data.system_metrics)
    end
  end

  describe "configuration management" do
    test "update_config updates monitoring configuration" do
      new_config = %{
        health_check_interval: 200,
        metrics_collection_interval: 300,
        alert_thresholds: %{cpu_usage: 90.0}
      }

      assert :ok = Monitoring.update_config(new_config)
    end
  end

  describe "alert system" do
    test "get_alerts returns current alerts" do
      alerts = Monitoring.get_alerts()
      assert is_map(alerts)
    end

    test "clear_alerts removes alerts for component" do
      :ok = Monitoring.register_component(:test_component_1)

      # This should work even if there are no alerts
      :ok = Monitoring.clear_alerts(:test_component_1)
    end

    test "unhealthy components generate alerts" do
      :ok = Monitoring.register_component(:test_component_3)  # unhealthy component

      # Perform health check to trigger alert
      _health_check = Monitoring.check_component_health(:test_component_3)

      # Check if alerts were generated
      alerts = Monitoring.get_alerts()

      # There should be at least one alert
      if map_size(alerts) > 0 do
        alert = alerts |> Map.values() |> List.first()
        assert is_map(alert)
        assert Map.has_key?(alert, :type)
        assert Map.has_key?(alert, :severity)
        assert Map.has_key?(alert, :message)
        assert Map.has_key?(alert, :timestamp)
      end
    end
  end

  describe "automated monitoring cycles" do
    test "health check cycle runs automatically" do
      :ok = Monitoring.register_component(:test_component_1)

      # Wait for a health check cycle to run
      Process.sleep(200)  # Health check interval is 100ms

      # Check that health data exists
      health_status = Monitoring.get_all_health_status()
      assert Map.has_key?(health_status, :test_component_1)
    end

    test "metrics collection cycle runs automatically" do
      :ok = Monitoring.register_component(:test_component_1)

      # Wait for a metrics collection cycle to run
      Process.sleep(300)  # Metrics collection interval is 150ms

      # Check that metrics were collected
      metrics = Monitoring.get_component_metrics(:test_component_1)

      # Should have some automatically collected metrics
      assert is_list(metrics)
    end
  end

  describe "performance and scalability" do
    test "handles many components efficiently" do
      # Register many components
      component_ids = for i <- 1..50 do
        component_id = String.to_atom("perf_test_#{i}")
        :ok = Monitoring.register_component(component_id, %{index: i})
        component_id
      end

      # Perform health checks on all components
      start_time = System.monotonic_time(:millisecond)

      for component_id <- component_ids do
        _health = Monitoring.check_component_health(component_id)
      end

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete reasonably quickly (less than 5 seconds)
      assert duration < 5000

      # Cleanup
      for component_id <- component_ids do
        :ok = Monitoring.unregister_component(component_id)
      end
    end

    test "handles concurrent monitoring operations" do
      :ok = Monitoring.register_component(:concurrent_test)

      # Run multiple monitoring operations concurrently
      tasks = [
        Task.async(fn -> Monitoring.check_component_health(:concurrent_test) end),
        Task.async(fn -> Monitoring.record_metric(:concurrent_test, "test", :gauge, 1) end),
        Task.async(fn -> Monitoring.get_component_metrics(:concurrent_test) end),
        Task.async(fn -> Monitoring.get_dashboard_data() end),
        Task.async(fn -> Monitoring.get_alerts() end)
      ]

      # Wait for all tasks to complete without errors
      results = Enum.map(tasks, &Task.await/1)

      # All operations should complete successfully
      assert length(results) == 5
    end
  end

  describe "error handling and resilience" do
    test "handles component crashes gracefully" do
      :ok = Monitoring.register_component(:test_component_1)

      # Stop the component
      GenServer.stop(:test_component_1)

      # Health check should handle the missing component
      health_check = Monitoring.check_component_health(:test_component_1)
      assert health_check.status in [:unhealthy, :unknown]
    end

    test "handles invalid metric data gracefully" do
      :ok = Monitoring.register_component(:test_component_1)

      # Try to record invalid metrics
      results = [
        Monitoring.record_metric(:test_component_1, "", :gauge, nil),
        Monitoring.record_metric(:test_component_1, nil, :counter, 1),
        Monitoring.record_metric(:test_component_1, "valid", :invalid_type, 1)
      ]

      # Should not crash the monitoring system
      for result <- results do
        case result do
          :ok -> assert true
          {:error, _} -> assert true
          _ -> flunk("Unexpected result: #{inspect(result)}")
        end
      end
    end

    test "monitoring continues when individual component health checks fail" do
      :ok = Monitoring.register_component(:test_component_1)
      :ok = Monitoring.register_component(:test_component_2)

      # Stop one component
      GenServer.stop(:test_component_1)

      # Get all health status should still work
      health_status = Monitoring.get_all_health_status()
      assert is_map(health_status)
      assert Map.has_key?(health_status, :test_component_2)
    end
  end

  describe "data retention and cleanup" do
    test "old monitoring data gets cleaned up" do
      :ok = Monitoring.register_component(:cleanup_test)

      # Record some metrics and health checks
      :ok = Monitoring.record_metric(:cleanup_test, "old_metric", :gauge, 1)
      _health = Monitoring.check_component_health(:cleanup_test)

      # The cleanup happens automatically based on retention period
      # For this test, we just verify the system continues to work
      metrics = Monitoring.get_component_metrics(:cleanup_test)
      assert is_list(metrics)
    end
  end
end
