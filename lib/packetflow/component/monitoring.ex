defmodule PacketFlow.Component.Monitoring do
  @moduledoc """
  Component monitoring interfaces for health checks and metrics

  This module provides:
  - Health check interfaces and implementations
  - Metrics collection and reporting
  - Performance monitoring
  - Resource usage tracking
  - Alert and notification systems
  - Monitoring dashboard data
  """

  use GenServer

  @type health_status :: :healthy | :unhealthy | :degraded | :unknown
  @type metric_type :: :counter | :gauge | :histogram | :summary
  @type metric_value :: number() | %{count: integer(), sum: number(), buckets: map()}

  @type health_check :: %{
    component_id: atom(),
    status: health_status(),
    message: String.t(),
    timestamp: integer(),
    duration_ms: number(),
    metadata: map()
  }

  @type metric :: %{
    name: String.t(),
    type: metric_type(),
    value: metric_value(),
    labels: map(),
    timestamp: integer(),
    component_id: atom()
  }

  @type monitoring_config :: %{
    health_check_interval: integer(),
    metrics_collection_interval: integer(),
    retention_period: integer(),
    alert_thresholds: map(),
    enabled_checks: [atom()],
    enabled_metrics: [atom()]
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    config = Keyword.get(opts, :config, default_monitoring_config())

    # Schedule periodic health checks and metrics collection
    if config.health_check_interval > 0 do
      Process.send_after(self(), :health_check_cycle, config.health_check_interval)
    end

    if config.metrics_collection_interval > 0 do
      Process.send_after(self(), :metrics_collection_cycle, config.metrics_collection_interval)
    end

    {:ok, %{
      config: config,
      components: %{},
      health_history: %{},
      metrics_history: %{},
      alerts: %{},
      subscribers: %{},
      last_health_check: System.system_time(:millisecond),
      last_metrics_collection: System.system_time(:millisecond)
    }}
  end

  @doc """
  Register a component for monitoring
  """
  @spec register_component(atom(), map()) :: :ok | {:error, term()}
  def register_component(component_id, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register_component, component_id, metadata})
  end

  @doc """
  Unregister a component from monitoring
  """
  @spec unregister_component(atom()) :: :ok
  def unregister_component(component_id) do
    GenServer.call(__MODULE__, {:unregister_component, component_id})
  end

  @doc """
  Perform health check for a specific component
  """
  @spec check_component_health(atom()) :: health_check() | {:error, term()}
  def check_component_health(component_id) do
    GenServer.call(__MODULE__, {:check_component_health, component_id})
  end

  @doc """
  Get current health status for all components
  """
  @spec get_all_health_status() :: %{atom() => health_check()}
  def get_all_health_status() do
    GenServer.call(__MODULE__, :get_all_health_status)
  end

  @doc """
  Record a metric for a component
  """
  @spec record_metric(atom(), String.t(), metric_type(), metric_value(), map()) :: :ok
  def record_metric(component_id, name, type, value, labels \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, component_id, name, type, value, labels})
  end

  @doc """
  Get metrics for a specific component
  """
  @spec get_component_metrics(atom()) :: [metric()] | {:error, term()}
  def get_component_metrics(component_id) do
    GenServer.call(__MODULE__, {:get_component_metrics, component_id})
  end

  @doc """
  Get all current metrics
  """
  @spec get_all_metrics() :: %{atom() => [metric()]}
  def get_all_metrics() do
    GenServer.call(__MODULE__, :get_all_metrics)
  end

  @doc """
  Subscribe to monitoring events for a component
  """
  @spec subscribe_to_component(atom(), pid()) :: :ok
  def subscribe_to_component(component_id, subscriber_pid) do
    GenServer.call(__MODULE__, {:subscribe_to_component, component_id, subscriber_pid})
  end

  @doc """
  Unsubscribe from monitoring events
  """
  @spec unsubscribe_from_component(atom(), pid()) :: :ok
  def unsubscribe_from_component(component_id, subscriber_pid) do
    GenServer.call(__MODULE__, {:unsubscribe_from_component, component_id, subscriber_pid})
  end

  @doc """
  Get monitoring dashboard data
  """
  @spec get_dashboard_data() :: map()
  def get_dashboard_data() do
    GenServer.call(__MODULE__, :get_dashboard_data)
  end

  @doc """
  Update monitoring configuration
  """
  @spec update_config(monitoring_config()) :: :ok | {:error, term()}
  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end

  @doc """
  Get current alerts
  """
  @spec get_alerts() :: map()
  def get_alerts() do
    GenServer.call(__MODULE__, :get_alerts)
  end

  @doc """
  Clear alerts for a component
  """
  @spec clear_alerts(atom()) :: :ok
  def clear_alerts(component_id) do
    GenServer.call(__MODULE__, {:clear_alerts, component_id})
  end

  # GenServer callbacks

  def handle_call({:register_component, component_id, metadata}, _from, state) do
    enhanced_metadata = enhance_monitoring_metadata(component_id, metadata)
    new_components = Map.put(state.components, component_id, enhanced_metadata)
    new_state = %{state | components: new_components}

    # Initialize health and metrics history
    new_health_history = Map.put(state.health_history, component_id, [])
    new_metrics_history = Map.put(state.metrics_history, component_id, [])

    final_state = %{new_state |
      health_history: new_health_history,
      metrics_history: new_metrics_history
    }

    {:reply, :ok, final_state}
  end

  def handle_call({:unregister_component, component_id}, _from, state) do
    new_components = Map.delete(state.components, component_id)
    new_health_history = Map.delete(state.health_history, component_id)
    new_metrics_history = Map.delete(state.metrics_history, component_id)
    new_alerts = Map.delete(state.alerts, component_id)
    new_subscribers = Map.delete(state.subscribers, component_id)

    new_state = %{state |
      components: new_components,
      health_history: new_health_history,
      metrics_history: new_metrics_history,
      alerts: new_alerts,
      subscribers: new_subscribers
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:check_component_health, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :component_not_registered}, state}

      metadata ->
        health_check = perform_health_check(component_id, metadata)
        new_state = record_health_check(health_check, state)
        {:reply, health_check, new_state}
    end
  end

  def handle_call(:get_all_health_status, _from, state) do
    health_status = Enum.reduce(state.components, %{}, fn {component_id, _metadata}, acc ->
      latest_health = get_latest_health_check(component_id, state.health_history)
      Map.put(acc, component_id, latest_health)
    end)

    {:reply, health_status, state}
  end

  def handle_call({:get_component_metrics, component_id}, _from, state) do
    case Map.get(state.metrics_history, component_id) do
      nil -> {:reply, {:error, :component_not_registered}, state}
      metrics -> {:reply, metrics, state}
    end
  end

  def handle_call(:get_all_metrics, _from, state) do
    {:reply, state.metrics_history, state}
  end

  def handle_call({:subscribe_to_component, component_id, subscriber_pid}, _from, state) do
    subscribers = Map.update(state.subscribers, component_id, [subscriber_pid], fn subs ->
      if subscriber_pid in subs, do: subs, else: [subscriber_pid | subs]
    end)

    new_state = %{state | subscribers: subscribers}
    {:reply, :ok, new_state}
  end

  def handle_call({:unsubscribe_from_component, component_id, subscriber_pid}, _from, state) do
    subscribers = Map.update(state.subscribers, component_id, [], fn subs ->
      List.delete(subs, subscriber_pid)
    end)

    new_state = %{state | subscribers: subscribers}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_dashboard_data, _from, state) do
    dashboard_data = build_dashboard_data(state)
    {:reply, dashboard_data, state}
  end

  def handle_call({:update_config, new_config}, _from, state) do
    merged_config = Map.merge(state.config, new_config)
    new_state = %{state | config: merged_config}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_alerts, _from, state) do
    {:reply, state.alerts, state}
  end

  def handle_call({:clear_alerts, component_id}, _from, state) do
    new_alerts = Map.delete(state.alerts, component_id)
    new_state = %{state | alerts: new_alerts}
    {:reply, :ok, new_state}
  end

  def handle_cast({:record_metric, component_id, name, type, value, labels}, state) do
    metric = %{
      name: name,
      type: type,
      value: value,
      labels: labels,
      timestamp: System.system_time(:millisecond),
      component_id: component_id
    }

    new_state = record_metric_in_history(metric, state)
    notify_subscribers({:metric_recorded, component_id, metric}, new_state.subscribers)

    {:noreply, new_state}
  end

  def handle_info(:health_check_cycle, state) do
    # Perform health checks for all registered components
    new_state = perform_all_health_checks(state)

    # Schedule next health check cycle
    Process.send_after(self(), :health_check_cycle, state.config.health_check_interval)

    {:noreply, %{new_state | last_health_check: System.system_time(:millisecond)}}
  end

  def handle_info(:metrics_collection_cycle, state) do
    # Collect metrics from all registered components
    new_state = collect_all_metrics(state)

    # Schedule next metrics collection cycle
    Process.send_after(self(), :metrics_collection_cycle, state.config.metrics_collection_interval)

    {:noreply, %{new_state | last_metrics_collection: System.system_time(:millisecond)}}
  end

  def handle_info(:cleanup_old_data, state) do
    # Clean up old health checks and metrics based on retention period
    new_state = cleanup_old_monitoring_data(state)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_data, 300_000) # 5 minutes

    {:noreply, new_state}
  end

  # Private functions

  defp default_monitoring_config() do
    %{
      health_check_interval: 30_000, # 30 seconds
      metrics_collection_interval: 60_000, # 1 minute
      retention_period: 3_600_000, # 1 hour
      alert_thresholds: %{
        cpu_usage: 80.0,
        memory_usage: 85.0,
        error_rate: 5.0,
        response_time: 1000.0
      },
      enabled_checks: [:process_alive, :memory_usage, :cpu_usage, :message_queue],
      enabled_metrics: [:response_time, :throughput, :error_count, :memory_usage]
    }
  end

  defp enhance_monitoring_metadata(component_id, metadata) do
    base_metadata = %{
      component_id: component_id,
      registered_at: System.system_time(:millisecond),
      health_checks_enabled: true,
      metrics_enabled: true,
      alert_enabled: true
    }

    Map.merge(base_metadata, metadata)
  end

  defp perform_health_check(component_id, metadata \\ %{}) do
    start_time = System.system_time(:millisecond)

    health_result = try do
      case Process.whereis(component_id) do
        nil ->
          {:unhealthy, "Process not found"}

        pid ->
          if Process.alive?(pid) do
            # Try to call component's health_check function if it exists
            module = Map.get(metadata, :module, component_id)
            cond do
              function_exported?(module, :health_check, 1) ->
                case apply(module, :health_check, [component_id]) do
                  :healthy -> {:healthy, "Component reports healthy"}
                  :degraded -> {:degraded, "Component reports degraded performance"}
                  :unhealthy -> {:unhealthy, "Component reports unhealthy"}
                  _ -> {:unknown, "Invalid health check response"}
                end
              function_exported?(module, :health_check, 0) ->
                case apply(module, :health_check, []) do
                  :healthy -> {:healthy, "Component reports healthy"}
                  :degraded -> {:degraded, "Component reports degraded performance"}
                  :unhealthy -> {:unhealthy, "Component reports unhealthy"}
                  _ -> {:unknown, "Invalid health check response"}
                end
              true ->
                {:healthy, "Process alive, no health check function"}
            end
          else
            {:unhealthy, "Process not alive"}
          end
      end
    rescue
      error ->
        {:unhealthy, "Health check failed: #{inspect(error)}"}
    end

    {status, message} = health_result
    duration = System.system_time(:millisecond) - start_time

    %{
      component_id: component_id,
      status: status,
      message: message,
      timestamp: System.system_time(:millisecond),
      duration_ms: duration,
      metadata: collect_health_metadata(component_id)
    }
  end

  defp collect_health_metadata(component_id) do
    case Process.whereis(component_id) do
      nil -> %{}
      pid ->
        try do
          process_info = Process.info(pid, [:memory, :message_queue_len, :reductions])
          %{
            memory: process_info[:memory] || 0,
            message_queue_len: process_info[:message_queue_len] || 0,
            reductions: process_info[:reductions] || 0
          }
        rescue
          _ -> %{}
        end
    end
  end

  defp record_health_check(health_check, state) do
    component_id = health_check.component_id
    current_history = Map.get(state.health_history, component_id, [])
    new_history = [health_check | current_history] |> Enum.take(100) # Keep last 100 checks

    new_health_history = Map.put(state.health_history, component_id, new_history)

    # Check for alerts
    new_state = %{state | health_history: new_health_history}
    check_and_create_alerts(health_check, new_state)
  end

  defp get_latest_health_check(component_id, health_history) do
    case Map.get(health_history, component_id, []) do
      [] -> %{
        component_id: component_id,
        status: :unknown,
        message: "No health checks performed",
        timestamp: System.system_time(:millisecond),
        duration_ms: 0,
        metadata: %{}
      }
      [latest | _] -> latest
    end
  end

  defp record_metric_in_history(metric, state) do
    component_id = metric.component_id
    current_history = Map.get(state.metrics_history, component_id, [])
    new_history = [metric | current_history] |> Enum.take(1000) # Keep last 1000 metrics

    new_metrics_history = Map.put(state.metrics_history, component_id, new_history)
    %{state | metrics_history: new_metrics_history}
  end

  defp perform_all_health_checks(state) do
    Enum.reduce(state.components, state, fn {component_id, metadata}, acc_state ->
      health_check = perform_health_check(component_id, metadata)
      new_state = record_health_check(health_check, acc_state)
      notify_subscribers({:health_check_completed, component_id, health_check}, new_state.subscribers)
      new_state
    end)
  end

  defp collect_all_metrics(state) do
    Enum.reduce(state.components, state, fn {component_id, _metadata}, acc_state ->
      metrics = collect_component_metrics(component_id)

      Enum.reduce(metrics, acc_state, fn metric, inner_state ->
        record_metric_in_history(metric, inner_state)
      end)
    end)
  end

  defp collect_component_metrics(component_id) do
    base_metrics = [
      create_metric(component_id, "uptime_seconds", :gauge, get_component_uptime(component_id)),
      create_metric(component_id, "memory_bytes", :gauge, get_component_memory(component_id)),
      create_metric(component_id, "message_queue_length", :gauge, get_message_queue_length(component_id))
    ]

    # Try to get additional metrics from the component if it implements get_metrics
    additional_metrics = try do
      if function_exported?(component_id, :get_metrics, 0) do
        case apply(component_id, :get_metrics, []) do
          metrics when is_map(metrics) ->
            Enum.map(metrics, fn {name, value} ->
              create_metric(component_id, to_string(name), :gauge, value)
            end)
          _ -> []
        end
      else
        []
      end
    rescue
      _ -> []
    end

    base_metrics ++ additional_metrics
  end

  defp create_metric(component_id, name, type, value, labels \\ %{}) do
    %{
      name: name,
      type: type,
      value: value,
      labels: Map.put(labels, :component, component_id),
      timestamp: System.system_time(:millisecond),
      component_id: component_id
    }
  end

  defp get_component_uptime(component_id) do
    case Process.whereis(component_id) do
      nil -> 0
      _pid ->
        # This is a simplified uptime calculation
        # In a real implementation, you might track start time
        System.system_time(:second)
    end
  end

  defp get_component_memory(component_id) do
    case Process.whereis(component_id) do
      nil -> 0
      pid ->
        case Process.info(pid, :memory) do
          {:memory, memory} -> memory
          _ -> 0
        end
    end
  end

  defp get_message_queue_length(component_id) do
    case Process.whereis(component_id) do
      nil -> 0
      pid ->
        case Process.info(pid, :message_queue_len) do
          {:message_queue_len, len} -> len
          _ -> 0
        end
    end
  end

  defp check_and_create_alerts(health_check, state) do
    component_id = health_check.component_id

    # Check for health-based alerts
    new_alerts = case health_check.status do
      :unhealthy ->
        alert = %{
          type: :health,
          severity: :critical,
          message: "Component #{component_id} is unhealthy: #{health_check.message}",
          timestamp: health_check.timestamp,
          component_id: component_id
        }
        Map.put(state.alerts, {component_id, :health}, alert)

      :degraded ->
        alert = %{
          type: :health,
          severity: :warning,
          message: "Component #{component_id} performance is degraded: #{health_check.message}",
          timestamp: health_check.timestamp,
          component_id: component_id
        }
        Map.put(state.alerts, {component_id, :health}, alert)

      :healthy ->
        # Clear health alerts if component is now healthy
        Map.delete(state.alerts, {component_id, :health})

      _ ->
        state.alerts
    end

    %{state | alerts: new_alerts}
  end

  defp build_dashboard_data(state) do
    total_components = map_size(state.components)
    healthy_components = count_healthy_components(state.health_history)
    total_alerts = map_size(state.alerts)

    %{
      summary: %{
        total_components: total_components,
        healthy_components: healthy_components,
        unhealthy_components: total_components - healthy_components,
        total_alerts: total_alerts
      },
      components: build_component_summary(state),
      recent_alerts: get_recent_alerts(state.alerts, 10),
      system_metrics: build_system_metrics(state.metrics_history),
      last_updated: System.system_time(:millisecond)
    }
  end

  defp count_healthy_components(health_history) do
    Enum.count(health_history, fn {_component_id, history} ->
      case history do
        [latest | _] -> latest.status == :healthy
        [] -> false
      end
    end)
  end

  defp build_component_summary(state) do
    Enum.map(state.components, fn {component_id, metadata} ->
      latest_health = get_latest_health_check(component_id, state.health_history)
      recent_metrics = get_recent_metrics(component_id, state.metrics_history, 5)

      %{
        id: component_id,
        status: latest_health.status,
        last_health_check: latest_health.timestamp,
        metadata: metadata,
        recent_metrics: recent_metrics
      }
    end)
  end

  defp get_recent_alerts(alerts, limit) do
    alerts
    |> Map.values()
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(limit)
  end

  defp build_system_metrics(metrics_history) do
    # Aggregate metrics across all components
    all_metrics = Enum.flat_map(metrics_history, fn {_component_id, metrics} ->
      Enum.take(metrics, 10) # Recent metrics
    end)

    %{
      total_metrics_collected: length(all_metrics),
      avg_memory_usage: calculate_average_metric(all_metrics, "memory_bytes"),
      avg_message_queue_length: calculate_average_metric(all_metrics, "message_queue_length")
    }
  end

  defp get_recent_metrics(component_id, metrics_history, limit) do
    case Map.get(metrics_history, component_id, []) do
      [] -> []
      metrics -> Enum.take(metrics, limit)
    end
  end

  defp calculate_average_metric(metrics, metric_name) do
    matching_metrics = Enum.filter(metrics, fn metric -> metric.name == metric_name end)

    case matching_metrics do
      [] -> 0.0
      metrics ->
        total = Enum.sum(Enum.map(metrics, & &1.value))
        total / length(metrics)
    end
  end

  defp cleanup_old_monitoring_data(state) do
    cutoff_time = System.system_time(:millisecond) - state.config.retention_period

    # Clean up old health checks
    new_health_history = Enum.reduce(state.health_history, %{}, fn {component_id, history}, acc ->
      filtered_history = Enum.filter(history, fn check -> check.timestamp > cutoff_time end)
      Map.put(acc, component_id, filtered_history)
    end)

    # Clean up old metrics
    new_metrics_history = Enum.reduce(state.metrics_history, %{}, fn {component_id, metrics}, acc ->
      filtered_metrics = Enum.filter(metrics, fn metric -> metric.timestamp > cutoff_time end)
      Map.put(acc, component_id, filtered_metrics)
    end)

    %{state | health_history: new_health_history, metrics_history: new_metrics_history}
  end

  defp notify_subscribers(event, subscribers) do
    case event do
      {event_type, component_id, data} ->
        case Map.get(subscribers, component_id, []) do
          [] -> :ok
          subscriber_list ->
            Enum.each(subscriber_list, fn subscriber_pid ->
              send(subscriber_pid, {:monitoring_event, event_type, component_id, data})
            end)
        end
      _ -> :ok
    end
  end
end
