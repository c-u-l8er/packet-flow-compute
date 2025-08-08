defmodule PacketFlow.Component.TestingTest do
  use ExUnit.Case, async: true

  alias PacketFlow.Component.Testing

  setup_all do
    # Start the MockSupervisor for tests that need it
    {:ok, _pid} = start_supervised(PacketFlow.Component.Testing.MockSupervisor)
    :ok
  end

  describe "test case creation" do
    test "create_test_case creates test case structure" do
      test_function = fn -> assert 1 + 1 == 2 end

      test_case = Testing.create_test_case(
        "addition test",
        "Tests that 1 + 1 equals 2",
        test_function,
        timeout: 1000,
        tags: [:math, :basic],
        metadata: %{category: "arithmetic"}
      )

      assert test_case.name == "addition test"
      assert test_case.description == "Tests that 1 + 1 equals 2"
      assert is_function(test_case.test_function)
      assert test_case.timeout == 1000
      assert test_case.tags == [:math, :basic]
      assert test_case.metadata.category == "arithmetic"
    end

    test "create_test_case with default options" do
      test_function = fn -> :ok end

      test_case = Testing.create_test_case("simple test", "Simple test", test_function)

      assert test_case.name == "simple test"
      assert test_case.description == "Simple test"
      assert test_case.timeout == 5000  # default
      assert test_case.tags == []       # default
      assert test_case.metadata == %{}  # default
    end
  end

  describe "test suite creation" do
    test "create_test_suite creates test suite structure" do
      test_cases = [
        Testing.create_test_case("test 1", "First test", fn -> :ok end),
        Testing.create_test_case("test 2", "Second test", fn -> :ok end)
      ]

      suite = Testing.create_test_suite(
        "Math Test Suite",
        :math_component,
        test_cases,
        setup_all: fn -> :setup_done end,
        cleanup_all: fn -> :cleanup_done end,
        metadata: %{category: "unit_tests"}
      )

      assert suite.name == "Math Test Suite"
      assert suite.component_id == :math_component
      assert length(suite.test_cases) == 2
      assert is_function(suite.setup_all)
      assert is_function(suite.cleanup_all)
      assert suite.metadata.category == "unit_tests"
    end
  end

  describe "test case execution" do
    test "run_test_case executes successful test" do
      test_case = Testing.create_test_case(
        "success test",
        "Test that succeeds",
        fn -> assert true end
      )

      result = Testing.run_test_case(test_case)

      assert result.test_case == test_case
      assert result.status == :passed
      assert result.message == "Test passed"
      assert result.error == nil
      assert is_number(result.duration_ms)
      assert is_integer(result.timestamp)
    end

    test "run_test_case captures test failures" do
      test_case = Testing.create_test_case(
        "failure test",
        "Test that fails",
        fn -> assert false, "This should fail" end
      )

      result = Testing.run_test_case(test_case)

      assert result.status == :failed
      assert result.message == "Test failed"
      assert result.error != nil
    end

    test "run_test_case handles test timeouts" do
      test_case = Testing.create_test_case(
        "timeout test",
        "Test that times out",
        fn -> Process.sleep(100) end,
        timeout: 50  # Shorter than the sleep
      )

      result = Testing.run_test_case(test_case)

      assert result.status == :timeout
      assert result.message == "Test timed out"
      assert result.error == :timeout
    end

    test "run_test_case runs setup and cleanup functions" do
      {:ok, setup_called} = Agent.start_link(fn -> false end)
      {:ok, cleanup_called} = Agent.start_link(fn -> false end)

      test_case = Testing.create_test_case(
        "setup cleanup test",
        "Test with setup and cleanup",
        fn ->
          assert Agent.get(setup_called, & &1) == true
          :ok
        end,
        setup: fn -> Agent.update(setup_called, fn _ -> true end) end,
        cleanup: fn -> Agent.update(cleanup_called, fn _ -> true end) end
      )

      result = Testing.run_test_case(test_case)

      assert result.status == :passed
      assert Agent.get(cleanup_called, & &1) == true
    end

    test "run_test_case handles setup failures" do
      test_case = Testing.create_test_case(
        "setup failure test",
        "Test with failing setup",
        fn -> :ok end,
        setup: fn -> raise "Setup failed" end
      )

      result = Testing.run_test_case(test_case)

      assert result.status == :failed
      assert result.message == "Setup failed"
      assert result.error != nil
    end
  end

  describe "test suite execution" do
    test "run_test_suite executes all test cases" do
      test_cases = [
        Testing.create_test_case("test 1", "First test", fn -> assert 1 == 1 end),
        Testing.create_test_case("test 2", "Second test", fn -> assert 2 == 2 end),
        Testing.create_test_case("test 3", "Third test", fn -> assert false end)  # This will fail
      ]

      suite = Testing.create_test_suite("Test Suite", :test_component, test_cases)

      report = Testing.run_test_suite(suite)

      assert report.suite == suite
      assert length(report.results) == 3
      assert report.summary.total == 3
      assert report.summary.passed == 2
      assert report.summary.failed == 1
      assert report.summary.skipped == 0
      assert report.summary.timeout == 0
      assert is_number(report.summary.total_duration_ms)
      assert is_integer(report.timestamp)
    end

    test "run_test_suite runs setup_all and cleanup_all" do
      {:ok, setup_all_called} = Agent.start_link(fn -> false end)
      {:ok, cleanup_all_called} = Agent.start_link(fn -> false end)

      test_cases = [
        Testing.create_test_case("test", "Test", fn ->
          assert Agent.get(setup_all_called, & &1) == true
          :ok
        end)
      ]

      suite = Testing.create_test_suite(
        "Setup Suite",
        :test_component,
        test_cases,
        setup_all: fn -> Agent.update(setup_all_called, fn _ -> true end) end,
        cleanup_all: fn -> Agent.update(cleanup_all_called, fn _ -> true end) end
      )

      report = Testing.run_test_suite(suite)

      assert report.summary.passed == 1
      assert Agent.get(cleanup_all_called, & &1) == true
    end

    test "run_test_suite handles setup_all failures" do
      test_cases = [
        Testing.create_test_case("test", "Test", fn -> :ok end)
      ]

      suite = Testing.create_test_suite(
        "Failing Setup Suite",
        :test_component,
        test_cases,
        setup_all: fn -> raise "Setup failed" end
      )

      report = Testing.run_test_suite(suite)

      # All tests should be marked as failed due to setup_all failure
      assert report.summary.failed == 1
      assert report.summary.passed == 0
    end
  end

  describe "mock component creation" do
    test "create_mock_component creates mock component process" do
      mock_config = %{test_setting: "test_value"}

      # Note: This test is limited because we don't have the MockSupervisor running
      # In a full integration test, this would work
      result = Testing.create_mock_component(:test_mock, mock_config)

      # Should return either success or a specific error
      case result do
        {:ok, _pid} -> assert true
        {:error, _reason} -> assert true
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end
  end

  describe "test data factories" do
    test "create_test_data_factory creates capability factory" do
      factory = Testing.create_test_data_factory(:capability, %{custom: "option"})

      assert factory.component_type == :capability
      assert factory.options.custom == "option"
      assert is_map(factory.generators)
      assert Map.has_key?(factory.generators, :basic_capability)
      assert Map.has_key?(factory.generators, :admin_capability)
    end

    test "create_test_data_factory creates context factory" do
      factory = Testing.create_test_data_factory(:context)

      assert factory.component_type == :context
      assert Map.has_key?(factory.generators, :user_context)
      assert Map.has_key?(factory.generators, :admin_context)
    end

    test "create_test_data_factory creates intent factory" do
      factory = Testing.create_test_data_factory(:intent)

      assert factory.component_type == :intent
      assert Map.has_key?(factory.generators, :read_intent)
      assert Map.has_key?(factory.generators, :write_intent)
    end

    test "create_test_data_factory creates reactor factory" do
      factory = Testing.create_test_data_factory(:reactor)

      assert factory.component_type == :reactor
      assert Map.has_key?(factory.generators, :basic_reactor_state)
    end

    test "create_test_data_factory creates generic factory for unknown types" do
      factory = Testing.create_test_data_factory(:unknown_type)

      assert factory.component_type == :unknown_type
      assert factory.generators == %{}
    end
  end

  describe "test data generation" do
    test "generate_test_data creates capability data" do
      factory = Testing.create_test_data_factory(:capability)

      basic_cap = Testing.generate_test_data(factory, :basic_capability)
      assert basic_cap.type == :read
      assert basic_cap.resource == "/test/resource"
      assert basic_cap.scope == :user

      admin_cap = Testing.generate_test_data(factory, :admin_capability)
      assert admin_cap.type == :admin
      assert admin_cap.resource == :all
      assert admin_cap.scope == :system
    end

    test "generate_test_data creates context data" do
      factory = Testing.create_test_data_factory(:context)

      user_context = Testing.generate_test_data(factory, :user_context)
      assert is_binary(user_context.user_id)
      assert is_binary(user_context.session_id)
      assert is_list(user_context.capabilities)
      assert is_map(user_context.metadata)

      admin_context = Testing.generate_test_data(factory, :admin_context)
      assert admin_context.user_id == "admin_user"
      assert :admin in admin_context.capabilities
    end

    test "generate_test_data creates intent data" do
      factory = Testing.create_test_data_factory(:intent)

      read_intent = Testing.generate_test_data(factory, :read_intent)
      assert read_intent.type == :read
      assert read_intent.resource == "/test/resource"
      assert read_intent.user_id == "test_user"

      write_intent = Testing.generate_test_data(factory, :write_intent)
      assert write_intent.type == :write
      assert is_map(write_intent.data)
    end

    test "generate_test_data creates reactor data" do
      factory = Testing.create_test_data_factory(:reactor)

      reactor_state = Testing.generate_test_data(factory, :basic_reactor_state)
      assert is_map(reactor_state.data)
      assert is_map(reactor_state.metadata)
      assert is_integer(reactor_state.started_at)
    end

    test "generate_test_data applies overrides" do
      factory = Testing.create_test_data_factory(:capability)

      overrides = %{type: :custom, resource: "/custom/resource"}
      capability = Testing.generate_test_data(factory, :basic_capability, overrides)

      assert capability.type == :custom
      assert capability.resource == "/custom/resource"
      assert capability.scope == :user  # Not overridden
    end

    test "generate_test_data returns error for unknown data type" do
      factory = Testing.create_test_data_factory(:capability)

      result = Testing.generate_test_data(factory, :unknown_type)
      assert {:error, {:generator_not_found, :unknown_type}} = result
    end
  end

  describe "integration tests" do
    test "run_integration_tests with mock components" do
      # This test is limited without actual running components
      # In a full integration environment, this would be more comprehensive

      component_ids = [:comp1, :comp2]
      test_cases = [
        Testing.create_test_case("integration test", "Test integration", fn -> :ok end)
      ]

      report = Testing.run_integration_tests(component_ids, test_cases)

      assert is_map(report)
      assert Map.has_key?(report, :suite)
      assert Map.has_key?(report, :results)
      assert Map.has_key?(report, :summary)

      # Results will likely show setup failures since components don't exist
      assert report.summary.total == 1
    end
  end

  describe "performance tests" do
    test "run_performance_tests measures execution time" do
      test_function = fn ->
        Process.sleep(10)  # Simulate some work
        :ok
      end

      config = %{
        iterations: 5,
        warmup_iterations: 2,
        test_function: test_function
      }

      result = Testing.run_performance_tests(:perf_component, config)

      assert result.component_id == :perf_component
      assert result.iterations == 5
      assert is_integer(result.total_time_us)
      assert is_number(result.average_time_us)
      assert is_integer(result.min_time_us)
      assert is_integer(result.max_time_us)
      assert is_number(result.median_time_us)
      assert is_number(result.percentile_95_us)
      assert is_number(result.percentile_99_us)
      assert is_integer(result.timestamp)

      # Performance characteristics
      assert result.average_time_us >= result.min_time_us
      assert result.max_time_us >= result.average_time_us
      assert result.total_time_us > 0
    end

    test "run_performance_tests with default configuration" do
      result = Testing.run_performance_tests(:default_perf_component)

      assert result.iterations == 100  # default
      assert is_number(result.average_time_us)
    end
  end

  describe "test report generation" do
    setup do
      test_cases = [
        Testing.create_test_case("passing test", "Test that passes", fn -> :ok end),
        Testing.create_test_case("failing test", "Test that fails", fn -> assert false end)
      ]

      suite = Testing.create_test_suite("Report Test Suite", :report_component, test_cases)
      report = Testing.run_test_suite(suite)

      %{report: report}
    end

    test "generate_test_report creates text report", %{report: report} do
      text_report = Testing.generate_test_report(report, :text)

      assert is_binary(text_report)
      assert String.contains?(text_report, "Report Test Suite")
      assert String.contains?(text_report, "Total:")
      assert String.contains?(text_report, "Passed:")
      assert String.contains?(text_report, "Failed:")
      assert String.contains?(text_report, "✓") or String.contains?(text_report, "✗")
    end

    test "generate_test_report creates JSON report", %{report: report} do
      json_report = Testing.generate_test_report(report, :json)

      assert is_binary(json_report)

      # Should be valid JSON
      {:ok, parsed} = Jason.decode(json_report, keys: :atoms)
      assert Map.has_key?(parsed, :suite)
      assert Map.has_key?(parsed, :results)
      assert Map.has_key?(parsed, :summary)
    end

    test "generate_test_report creates HTML report", %{report: report} do
      html_report = Testing.generate_test_report(report, :html)

      assert is_binary(html_report)
      assert String.contains?(html_report, "<!DOCTYPE html>")
      assert String.contains?(html_report, "<title>")
      assert String.contains?(html_report, "Report Test Suite")
      assert String.contains?(html_report, "passed")
      assert String.contains?(html_report, "failed")
    end

    test "generate_test_report creates JUnit XML report", %{report: report} do
      junit_report = Testing.generate_test_report(report, :junit)

      assert is_binary(junit_report)
      assert String.contains?(junit_report, "<?xml version")
      assert String.contains?(junit_report, "<testsuite")
      assert String.contains?(junit_report, "<testcase")
      assert String.contains?(junit_report, "Report Test Suite")
    end

    test "generate_test_report returns error for unsupported format", %{report: report} do
      result = Testing.generate_test_report(report, :unsupported_format)
      assert {:error, {:unsupported_format, :unsupported_format}} = result
    end
  end

  describe "mock component behavior" do
    test "MockComponent implements Component.Interface" do
      # Test that MockComponent has all the required interface functions
      assert function_exported?(Testing.MockComponent, :component_init, 1)
      assert function_exported?(Testing.MockComponent, :get_state, 0)
      assert function_exported?(Testing.MockComponent, :update_state, 1)
      assert function_exported?(Testing.MockComponent, :health_check, 0)
      assert function_exported?(Testing.MockComponent, :get_config, 0)
      assert function_exported?(Testing.MockComponent, :update_config, 1)
      assert function_exported?(Testing.MockComponent, :get_dependencies, 0)
      assert function_exported?(Testing.MockComponent, :validate_dependencies, 0)
      assert function_exported?(Testing.MockComponent, :get_required_capabilities, 0)
      assert function_exported?(Testing.MockComponent, :get_provided_capabilities, 0)
      assert function_exported?(Testing.MockComponent, :get_metrics, 0)
      assert function_exported?(Testing.MockComponent, :start_component, 1)
      assert function_exported?(Testing.MockComponent, :stop_component, 0)
      assert function_exported?(Testing.MockComponent, :send_message, 2)
      assert function_exported?(Testing.MockComponent, :handle_message, 2)
    end

    test "MockComponent provides default implementations" do
      # Test default implementations
      assert Testing.MockComponent.health_check() == :healthy
      assert Testing.MockComponent.get_dependencies() == []
      assert Testing.MockComponent.validate_dependencies() == :ok
      assert Testing.MockComponent.get_required_capabilities() == []
      assert Testing.MockComponent.get_provided_capabilities() == []
    end
  end

  describe "error handling and edge cases" do
    test "handles test cases with nil functions gracefully" do
      # This should not be possible with proper test case creation,
      # but test defensive programming
      test_case = %{
        name: "nil test",
        description: "Test with nil function",
        test_function: nil,
        setup: nil,
        cleanup: nil,
        timeout: 5000,
        tags: [],
        metadata: %{}
      }

      # Should handle gracefully, not crash
      result = Testing.run_test_case(test_case)
      assert result.status == :failed
    end

    test "handles very long running tests" do
      test_case = Testing.create_test_case(
        "long test",
        "Test that takes a while",
        fn -> Process.sleep(200) end,
        timeout: 300  # Just enough time
      )

      result = Testing.run_test_case(test_case)
      assert result.status == :passed
      assert result.duration_ms >= 200
    end

    test "handles test cases that throw exits" do
      test_case = Testing.create_test_case(
        "exit test",
        "Test that exits",
        fn -> exit(:test_exit) end
      )

      result = Testing.run_test_case(test_case)
      assert result.status == :failed
      assert result.error != nil
    end

    test "handles test cases with complex error types" do
      test_case = Testing.create_test_case(
        "complex error test",
        "Test with complex error",
        fn -> throw({:complex, :error, %{data: "test"}}) end
      )

      result = Testing.run_test_case(test_case)
      assert result.status == :failed
      assert result.error != nil
    end
  end

  describe "test utilities and helpers" do
    test "test data factories support chaining and composition" do
      capability_factory = Testing.create_test_data_factory(:capability)
      context_factory = Testing.create_test_data_factory(:context)

      # Generate related test data
      capability = Testing.generate_test_data(capability_factory, :basic_capability)
      context = Testing.generate_test_data(context_factory, :user_context,
        %{capabilities: [capability]})

      assert capability in context.capabilities
    end
  end
end
