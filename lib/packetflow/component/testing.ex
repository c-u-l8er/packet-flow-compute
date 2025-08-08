defmodule PacketFlow.Component.Testing do
  @moduledoc """
  Component testing interfaces for automated testing

  This module provides:
  - Component test suite generation
  - Integration testing utilities
  - Mock and stub implementations
  - Test data factories
  - Performance testing tools
  - Test reporting and analysis
  """

  @type test_case :: %{
    name: String.t(),
    description: String.t(),
    setup: function() | nil,
    test_function: function(),
    cleanup: function() | nil,
    timeout: integer(),
    tags: [atom()],
    metadata: map()
  }

  @type test_result :: %{
    test_case: test_case(),
    status: :passed | :failed | :skipped | :timeout,
    duration_ms: number(),
    message: String.t() | nil,
    error: term() | nil,
    timestamp: integer()
  }

  @type test_suite :: %{
    name: String.t(),
    component_id: atom(),
    test_cases: [test_case()],
    setup_all: function() | nil,
    cleanup_all: function() | nil,
    metadata: map()
  }

  @type test_report :: %{
    suite: test_suite(),
    results: [test_result()],
    summary: %{
      total: integer(),
      passed: integer(),
      failed: integer(),
      skipped: integer(),
      timeout: integer(),
      total_duration_ms: number()
    },
    timestamp: integer()
  }

  @doc """
  Create a test suite for a component
  """
  @spec create_test_suite(String.t(), atom(), [test_case()], keyword()) :: test_suite()
  def create_test_suite(name, component_id, test_cases, opts \\ []) do
    %{
      name: name,
      component_id: component_id,
      test_cases: test_cases,
      setup_all: Keyword.get(opts, :setup_all),
      cleanup_all: Keyword.get(opts, :cleanup_all),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Create a test case
  """
  @spec create_test_case(String.t(), String.t(), function(), keyword()) :: test_case()
  def create_test_case(name, description, test_function, opts \\ []) do
    %{
      name: name,
      description: description,
      setup: Keyword.get(opts, :setup),
      test_function: test_function,
      cleanup: Keyword.get(opts, :cleanup),
      timeout: Keyword.get(opts, :timeout, 5000),
      tags: Keyword.get(opts, :tags, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Run a test suite
  """
  @spec run_test_suite(test_suite()) :: test_report()
  def run_test_suite(suite) do
    start_time = System.system_time(:millisecond)

    # Run setup_all if provided
    setup_all_result = if suite.setup_all do
      try do
        suite.setup_all.()
        :ok
      rescue
        error -> {:error, error}
      end
    else
      :ok
    end

    results = case setup_all_result do
      :ok ->
        # Run all test cases
        test_results = Enum.map(suite.test_cases, fn test_case ->
          run_test_case(test_case)
        end)

        # Run cleanup_all if provided
        if suite.cleanup_all do
          try do
            suite.cleanup_all.()
          rescue
            _error -> :ok # Don't fail the suite if cleanup fails
          end
        end

        test_results

      {:error, error} ->
        # If setup_all fails, mark all tests as failed
        Enum.map(suite.test_cases, fn test_case ->
          %{
            test_case: test_case,
            status: :failed,
            duration_ms: 0,
            message: "Setup failed",
            error: error,
            timestamp: System.system_time(:millisecond)
          }
        end)
    end

    end_time = System.system_time(:millisecond)

    summary = calculate_test_summary(results, end_time - start_time)

    %{
      suite: suite,
      results: results,
      summary: summary,
      timestamp: start_time
    }
  end

  @doc """
  Run a single test case
  """
  @spec run_test_case(test_case()) :: test_result()
  def run_test_case(test_case) do
    start_time = System.system_time(:millisecond)

    # Run setup if provided
    setup_result = if test_case.setup do
      try do
        test_case.setup.()
        :ok
      rescue
        error -> {:error, error}
      end
    else
      :ok
    end

    test_result = case setup_result do
      :ok ->
        # Run the actual test with timeout
        task = Task.async(fn ->
          try do
            test_case.test_function.()
            :ok
          rescue
            error -> {:error, error}
          catch
            :exit, reason -> {:error, {:exit, reason}}
            kind, reason -> {:error, {kind, reason}}
          end
        end)

        case Task.yield(task, test_case.timeout) do
          {:ok, :ok} ->
            {:passed, "Test passed", nil}

          {:ok, {:error, error}} ->
            {:failed, "Test failed", error}

          nil ->
            Task.shutdown(task, :brutal_kill)
            {:timeout, "Test timed out", :timeout}
        end

      {:error, error} ->
        {:failed, "Setup failed", error}
    end

    # Run cleanup if provided
    if test_case.cleanup do
      try do
        test_case.cleanup.()
      rescue
        _error -> :ok # Don't fail the test if cleanup fails
      end
    end

    end_time = System.system_time(:millisecond)
    {status, message, error} = test_result

    %{
      test_case: test_case,
      status: status,
      duration_ms: end_time - start_time,
      message: message,
      error: error,
      timestamp: start_time
    }
  end

  @doc """
  Create a mock component for testing
  """
  @spec create_mock_component(atom(), map()) :: {:ok, pid()} | {:error, term()}
  def create_mock_component(component_id, mock_config \\ %{}) do
    mock_spec = %{
      id: component_id,
      start: {PacketFlow.Component.Testing.MockComponent, :start_link, [mock_config]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker,
      modules: [PacketFlow.Component.Testing.MockComponent]
    }

    case DynamicSupervisor.start_child(PacketFlow.Component.Testing.MockSupervisor, mock_spec) do
      {:ok, pid} ->
        Process.register(pid, component_id)
        {:ok, pid}
      error -> error
    end
  end

  @doc """
  Create test data factory for a component
  """
  @spec create_test_data_factory(atom(), map()) :: map()
  def create_test_data_factory(component_type, options \\ %{}) do
    base_factory = %{
      component_type: component_type,
      generators: %{},
      sequences: %{},
      traits: %{},
      options: options
    }

    case component_type do
      :capability ->
        add_capability_generators(base_factory)

      :context ->
        add_context_generators(base_factory)

      :intent ->
        add_intent_generators(base_factory)

      :reactor ->
        add_reactor_generators(base_factory)

      _ ->
        base_factory
    end
  end

  @doc """
  Generate test data using a factory
  """
  @spec generate_test_data(map(), atom(), map()) :: term()
  def generate_test_data(factory, data_type, overrides \\ %{}) do
    case Map.get(factory.generators, data_type) do
      nil -> {:error, {:generator_not_found, data_type}}
      generator -> apply_generator(generator, factory, overrides)
    end
  end

  @doc """
  Run integration tests between components
  """
  @spec run_integration_tests([atom()], [test_case()]) :: test_report()
  def run_integration_tests(component_ids, test_cases) do
    # Ensure all components are running
    setup_result = Enum.reduce_while(component_ids, :ok, fn component_id, _acc ->
      case ensure_component_running(component_id) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {component_id, reason}}}
      end
    end)

    case setup_result do
      :ok ->
        integration_suite = %{
          name: "Integration Tests",
          component_id: :integration,
          test_cases: test_cases,
          setup_all: nil,
          cleanup_all: fn -> cleanup_integration_components(component_ids) end,
          metadata: %{component_ids: component_ids}
        }

        run_test_suite(integration_suite)

      {:error, reason} ->
        failed_results = Enum.map(test_cases, fn test_case ->
          %{
            test_case: test_case,
            status: :failed,
            duration_ms: 0,
            message: "Integration setup failed",
            error: reason,
            timestamp: System.system_time(:millisecond)
          }
        end)

        %{
          suite: %{name: "Integration Tests", component_id: :integration, test_cases: test_cases},
          results: failed_results,
          summary: calculate_test_summary(failed_results, 0),
          timestamp: System.system_time(:millisecond)
        }
    end
  end

  @doc """
  Run performance tests for a component
  """
  @spec run_performance_tests(atom(), map()) :: map()
  def run_performance_tests(component_id, test_config \\ %{}) do
    iterations = Map.get(test_config, :iterations, 100)
    warmup_iterations = Map.get(test_config, :warmup_iterations, 10)
    test_function = Map.get(test_config, :test_function, fn -> :ok end)

    # Warmup
    Enum.each(1..warmup_iterations, fn _ -> test_function.() end)

    # Actual performance test
    {total_time, results} = :timer.tc(fn ->
      Enum.map(1..iterations, fn _ ->
        {time, result} = :timer.tc(test_function)
        {time, result}
      end)
    end)

    times = Enum.map(results, fn {time, _result} -> time end)

    %{
      component_id: component_id,
      iterations: iterations,
      total_time_us: total_time,
      average_time_us: Enum.sum(times) / length(times),
      min_time_us: Enum.min(times),
      max_time_us: Enum.max(times),
      median_time_us: calculate_median(times),
      percentile_95_us: calculate_percentile(times, 95),
      percentile_99_us: calculate_percentile(times, 99),
      timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  Generate test report in various formats
  """
  @spec generate_test_report(test_report(), atom()) :: String.t() | map()
  def generate_test_report(report, format \\ :text) do
    case format do
      :text -> generate_text_report(report)
      :json -> generate_json_report(report)
      :html -> generate_html_report(report)
      :junit -> generate_junit_report(report)
      _ -> {:error, {:unsupported_format, format}}
    end
  end

  # Private functions

  defp calculate_test_summary(results, total_duration_ms) do
    summary = Enum.reduce(results, %{passed: 0, failed: 0, skipped: 0, timeout: 0}, fn result, acc ->
      Map.update(acc, result.status, 1, &(&1 + 1))
    end)

    Map.merge(summary, %{
      total: length(results),
      total_duration_ms: total_duration_ms
    })
  end

  defp add_capability_generators(factory) do
    generators = %{
      basic_capability: fn _factory, overrides ->
        Map.merge(%{
          type: :read,
          resource: "/test/resource",
          scope: :user
        }, overrides)
      end,
      admin_capability: fn _factory, overrides ->
        Map.merge(%{
          type: :admin,
          resource: :all,
          scope: :system
        }, overrides)
      end
    }

    %{factory | generators: generators}
  end

  defp add_context_generators(factory) do
    generators = %{
      user_context: fn _factory, overrides ->
        Map.merge(%{
          user_id: "test_user_#{:rand.uniform(1000)}",
          session_id: "session_#{:rand.uniform(1000)}",
          capabilities: [],
          metadata: %{}
        }, overrides)
      end,
      admin_context: fn _factory, overrides ->
        Map.merge(%{
          user_id: "admin_user",
          session_id: "admin_session",
          capabilities: [:admin],
          metadata: %{role: :admin}
        }, overrides)
      end
    }

    %{factory | generators: generators}
  end

  defp add_intent_generators(factory) do
    generators = %{
      read_intent: fn _factory, overrides ->
        Map.merge(%{
          type: :read,
          resource: "/test/resource",
          user_id: "test_user",
          metadata: %{}
        }, overrides)
      end,
      write_intent: fn _factory, overrides ->
        Map.merge(%{
          type: :write,
          resource: "/test/resource",
          data: %{test: "data"},
          user_id: "test_user",
          metadata: %{}
        }, overrides)
      end
    }

    %{factory | generators: generators}
  end

  defp add_reactor_generators(factory) do
    generators = %{
      basic_reactor_state: fn _factory, overrides ->
        Map.merge(%{
          data: %{},
          metadata: %{},
          started_at: System.system_time(:millisecond)
        }, overrides)
      end
    }

    %{factory | generators: generators}
  end

  defp apply_generator(generator, factory, overrides) do
    generator.(factory, overrides)
  end

  defp ensure_component_running(component_id) do
    case Process.whereis(component_id) do
      nil -> {:error, :component_not_running}
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          :ok
        else
          {:error, :component_not_alive}
        end
    end
  end

  defp cleanup_integration_components(_component_ids) do
    # Cleanup logic for integration tests
    :ok
  end

  defp calculate_median(times) do
    sorted = Enum.sort(times)
    length = length(sorted)

    if rem(length, 2) == 0 do
      mid1 = Enum.at(sorted, div(length, 2) - 1)
      mid2 = Enum.at(sorted, div(length, 2))
      (mid1 + mid2) / 2
    else
      Enum.at(sorted, div(length, 2))
    end
  end

  defp calculate_percentile(times, percentile) do
    sorted = Enum.sort(times)
    index = round(length(sorted) * percentile / 100) - 1
    index = max(0, min(index, length(sorted) - 1))
    Enum.at(sorted, index)
  end

  defp generate_text_report(report) do
    """
    Test Suite: #{report.suite.name}
    Component: #{report.suite.component_id}

    Summary:
    - Total: #{report.summary.total}
    - Passed: #{report.summary.passed}
    - Failed: #{report.summary.failed}
    - Skipped: #{report.summary.skipped}
    - Timeout: #{report.summary.timeout}
    - Duration: #{report.summary.total_duration_ms}ms

    Results:
    #{Enum.map_join(report.results, "\n", &format_test_result/1)}
    """
  end

  defp generate_json_report(report) do
    sanitized_report = sanitize_report_for_json(report)
    Jason.encode!(sanitized_report, pretty: true)
  end

    defp sanitize_report_for_json(report) do
    sanitized_results = Enum.map(report.results, fn result ->
      sanitized_test_case = sanitize_test_case_for_json(result.test_case)
      sanitized_error = sanitize_error_for_json(result.error)
      %{result | test_case: sanitized_test_case, error: sanitized_error}
    end)

    sanitized_suite = sanitize_test_suite_for_json(report.suite)
    %{report | results: sanitized_results, suite: sanitized_suite}
  end

  defp sanitize_test_case_for_json(test_case) do
    %{
      name: test_case.name,
      description: test_case.description,
      timeout_ms: Map.get(test_case, :timeout_ms, Map.get(test_case, :timeout, 5000)),
      tags: test_case.tags,
      # Remove function references
      setup: if(is_function(test_case.setup), do: "function", else: test_case.setup),
      test_function: if(is_function(test_case.test_function), do: "function", else: test_case.test_function),
      cleanup: if(is_function(test_case.cleanup), do: "function", else: test_case.cleanup)
    }
  end

  defp sanitize_test_suite_for_json(test_suite) do
    %{
      name: test_suite.name,
      description: Map.get(test_suite, :description, ""),
      timeout_ms: Map.get(test_suite, :timeout_ms, Map.get(test_suite, :timeout, 10000)),
      tags: Map.get(test_suite, :tags, []),
      # Remove function references
      setup_all: if(is_function(Map.get(test_suite, :setup_all)), do: "function", else: Map.get(test_suite, :setup_all)),
      cleanup_all: if(is_function(Map.get(test_suite, :cleanup_all)), do: "function", else: Map.get(test_suite, :cleanup_all)),
      test_cases: Enum.map(Map.get(test_suite, :test_cases, []), &sanitize_test_case_for_json/1)
    }
  end

  defp sanitize_error_for_json(error) when is_struct(error) do
    # Convert struct to a simple map representation
    %{
      type: error.__struct__ |> to_string(),
      message: Map.get(error, :message, "Unknown error"),
      details: inspect(error)
    }
  end

  defp sanitize_error_for_json(error) do
    error
  end

  defp generate_html_report(report) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Test Report: #{report.suite.name}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; }
            .passed { color: green; }
            .failed { color: red; }
            .timeout { color: orange; }
            .skipped { color: gray; }
        </style>
    </head>
    <body>
        <h1>Test Report: #{report.suite.name}</h1>
        <div class="summary">
            <h2>Summary</h2>
            <p>Total: #{report.summary.total}</p>
            <p class="passed">Passed: #{report.summary.passed}</p>
            <p class="failed">Failed: #{report.summary.failed}</p>
            <p class="skipped">Skipped: #{report.summary.skipped}</p>
            <p class="timeout">Timeout: #{report.summary.timeout}</p>
            <p>Duration: #{report.summary.total_duration_ms}ms</p>
        </div>
        <h2>Results</h2>
        #{Enum.map_join(report.results, "\n", &format_html_test_result/1)}
    </body>
    </html>
    """
  end

  defp generate_junit_report(report) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuite name="#{report.suite.name}"
               tests="#{report.summary.total}"
               failures="#{report.summary.failed}"
               errors="0"
               time="#{report.summary.total_duration_ms / 1000}">
        #{Enum.map_join(report.results, "\n", &format_junit_test_result/1)}
    </testsuite>
    """
  end

  defp format_test_result(result) do
    status_icon = case result.status do
      :passed -> "✓"
      :failed -> "✗"
      :timeout -> "⏰"
      :skipped -> "⊝"
    end

    "#{status_icon} #{result.test_case.name} (#{result.duration_ms}ms)"
  end

  defp format_html_test_result(result) do
    status_class = to_string(result.status)
    """
    <div class="#{status_class}">
        <h3>#{result.test_case.name}</h3>
        <p>Status: #{result.status}</p>
        <p>Duration: #{result.duration_ms}ms</p>
        #{if result.message, do: "<p>Message: #{result.message}</p>", else: ""}
    </div>
    """
  end

  defp format_junit_test_result(result) do
    case result.status do
      :passed ->
        "<testcase name=\"#{result.test_case.name}\" time=\"#{result.duration_ms / 1000}\"/>"

      :failed ->
        """
        <testcase name="#{result.test_case.name}" time="#{result.duration_ms / 1000}">
            <failure message="#{result.message || "Test failed"}">#{inspect(result.error)}</failure>
        </testcase>
        """

      :timeout ->
        """
        <testcase name="#{result.test_case.name}" time="#{result.duration_ms / 1000}">
            <failure message="Test timed out">Test execution exceeded timeout</failure>
        </testcase>
        """

      :skipped ->
        """
        <testcase name="#{result.test_case.name}" time="#{result.duration_ms / 1000}">
            <skipped message="Test skipped"/>
        </testcase>
        """
    end
  end
end

defmodule PacketFlow.Component.Testing.MockSupervisor do
  @moduledoc """
  Dynamic supervisor for mock components
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule PacketFlow.Component.Testing.MockComponent do
  @moduledoc """
  Mock component implementation for testing
  """

  use GenServer
  @behaviour PacketFlow.Component.Interface

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  # GenServer callback
  def init(config) do
    {:ok, %{config: config, state: %{}, message_count: 0}}
  end

  # Component.Interface implementation
  def component_init(config), do: {:ok, %{config: config, state: %{}, started_at: System.system_time(:millisecond)}}
  def get_state(), do: GenServer.call(__MODULE__, :get_state)
  def update_state(new_state), do: GenServer.call(__MODULE__, {:update_state, new_state})
  def send_message(target, message) do
    send(target, {:component_message, __MODULE__, message})
    :ok
  end
  def handle_message(_message, state), do: {:ok, state}
  def health_check(), do: :healthy
  def get_config(), do: GenServer.call(__MODULE__, :get_config)
  def update_config(new_config), do: GenServer.call(__MODULE__, {:update_config, new_config})
  def get_dependencies(), do: []
  def validate_dependencies(), do: :ok
  def get_required_capabilities(), do: []
  def get_provided_capabilities(), do: []
  def start_component(config), do: start_link(config)
  def stop_component(), do: GenServer.stop(__MODULE__)

  def get_metrics() do
    state = get_state()
    %{
      message_count: state.message_count,
      uptime: System.system_time(:millisecond)
    }
  end

  def handle_call(:get_state, _from, state), do: {:reply, state.state, state}
  def handle_call({:update_state, new_state}, _from, state), do: {:reply, :ok, %{state | state: new_state}}
  def handle_call(:get_config, _from, state), do: {:reply, state.config, state}
  def handle_call({:update_config, new_config}, _from, state), do: {:reply, :ok, %{state | config: new_config}}

  def handle_info({:component_message, _from, _payload}, state) do
    new_state = %{state | message_count: state.message_count + 1}
    {:noreply, new_state}
  end
end
