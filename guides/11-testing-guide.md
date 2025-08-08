# PacketFlow Testing Guide

## Overview

PacketFlow provides a comprehensive testing framework designed to ensure reliability, correctness, and performance across all system components. This guide covers testing strategies, patterns, and best practices for building robust PacketFlow applications.

## Testing Philosophy

PacketFlow follows a **multi-layered testing approach**:

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test component interactions and substrate integration
- **DSL Tests**: Test domain-specific language constructs
- **Performance Tests**: Test system performance under load
- **Security Tests**: Test capability-based security model

## Test Structure

### Test Organization

```
test/
├── packetflow/
│   ├── component/           # Component-specific tests
│   ├── registry/           # Registry tests
│   ├── intent/             # Intent tests
│   ├── capability/         # Capability tests
│   ├── substrate_test.exs  # Substrate tests
│   ├── dsl_*_test.exs     # DSL tests
│   └── *_integration_test.exs # Integration tests
└── test_helper.exs         # Test configuration
```

### Test Categories

1. **Core Module Tests**: Test fundamental system components
2. **Substrate Tests**: Test each substrate (ADT, Actor, Stream, Temporal)
3. **DSL Tests**: Test domain-specific language features
4. **Integration Tests**: Test cross-component interactions
5. **Web Tests**: Test web framework functionality

## Component Testing

### Basic Component Test Structure

```elixir
defmodule MyComponentTest do
  use ExUnit.Case, async: true
  use PacketFlow.Component.Testing

  setup do
    # Component setup
    {:ok, component_pid} = start_supervised(MyComponent)
    %{component: component_pid}
  end

  describe "component lifecycle" do
    test "starts successfully", %{component: component} do
      assert Process.alive?(component)
    end

    test "handles messages correctly", %{component: component} do
      send(component, {:test, "data"})
      # Assert expected behavior
    end
  end
end
```

### Component Testing Utilities

PacketFlow provides specialized testing utilities for components:

```elixir
# Create test cases
test_case = Testing.create_test_case(
  "component test",
  "Tests component behavior",
  fn -> assert true end,
  timeout: 1000,
  tags: [:unit, :component],
  metadata: %{category: "lifecycle"}
)

# Create test suites
suite = Testing.create_test_suite(
  "Component Test Suite",
  :my_component,
  [test_case],
  setup_all: fn -> :setup_done end,
  cleanup_all: fn -> :cleanup_done end
)

# Run test suite
report = Testing.run_test_suite(suite)
```

## DSL Testing

### Testing Capabilities

```elixir
defmodule CapabilityTest do
  use ExUnit.Case, async: false
  use PacketFlow.DSL

  test "capability implications work correctly" do
    defsimple_capability TestCap, [:read, :write, :admin] do
      @implications [
        {TestCap.admin, [TestCap.read, TestCap.write]},
        {TestCap.write, [TestCap.read]}
      ]
    end

    # Test capability creation
    read_cap = TestCap.read("/file.txt")
    write_cap = TestCap.write("/file.txt")
    admin_cap = TestCap.admin("/file.txt")

    # Test implications
    assert TestCap.implies?(admin_cap, read_cap)
    assert TestCap.implies?(admin_cap, write_cap)
    assert TestCap.implies?(write_cap, read_cap)
    refute TestCap.implies?(read_cap, write_cap)
  end
end
```

### Testing Contexts

```elixir
test "context propagation works correctly" do
  defsimple_context TestContext, [:user_id, :session_id] do
    @propagation_strategy :inherit
  end

  context = TestContext.new(user_id: "user1", session_id: "session1")
  
  # Test context creation
  assert context.user_id == "user1"
  assert context.session_id == "session1"
  
  # Test context propagation
  propagated = TestContext.propagate(context, SomeModule)
  assert propagated.user_id == "user1"
end
```

### Testing Intents

```elixir
test "intent capabilities are correctly defined" do
  defsimple_intent TestIntent, [:path, :user_id] do
    @capabilities [FileCap.read]
    @effect FileSystemEffect.read_file
  end

  intent = TestIntent.new("/test.txt", "user1")
  
  # Test intent creation
  assert intent.path == "/test.txt"
  assert intent.user_id == "user1"
  
  # Test required capabilities
  capabilities = TestIntent.required_capabilities(intent)
  assert FileCap.read("/test.txt") in capabilities
  
  # Test effect generation
  effect = TestIntent.to_effect(intent)
  assert effect.type == :read_file
end
```

### Testing Reactors

```elixir
test "reactor state management works correctly" do
  defintent IncrementIntent do
    defstruct []
  end

  defintent DecrementIntent do
    defstruct []
  end

  defsimple_reactor CounterReactor, [:count] do
    def process_intent(intent, state) do
      case intent do
        %IncrementIntent{} ->
          new_state = %{state | count: state.count + 1}
          {:ok, new_state, []}
        %DecrementIntent{} ->
          new_state = %{state | count: state.count - 1}
          {:ok, new_state, []}
      end
    end
  end

  # Test reactor lifecycle
  assert {:ok, pid} = CounterReactor.start_link()
  
  # Test state management
  initial_state = CounterReactor.get_state(pid)
  assert initial_state.count == 0
  
  # Test intent processing
  {:ok, new_state, _effects} = CounterReactor.process_intent(
    %IncrementIntent{}, 
    initial_state
  )
  assert new_state.count == 1
end
```

## Substrate Testing

### ADT Substrate Tests

```elixir
defmodule ADTSubstrateTest do
  use ExUnit.Case, async: true

  describe "algebraic data types" do
    test "sum types work correctly" do
      # Test capability-aware sum types
      assert true
    end

    test "product types work correctly" do
      # Test context propagation through product types
      assert true
    end

    test "type-level constraints" do
      # Test type-level constraint validation
      assert true
    end
  end
end
```

### Actor Substrate Tests

```elixir
defmodule ActorSubstrateTest do
  use ExUnit.Case, async: true

  describe "distributed actor orchestration" do
    test "actor lifecycle management" do
      # Test actor start/stop
      assert true
    end

    test "cross-node capability propagation" do
      # Test capability propagation across nodes
      assert true
    end

    test "actor clustering and discovery" do
      # Test actor clustering functionality
      assert true
    end

    test "fault tolerance and recovery" do
      # Test actor failure handling
      assert true
    end
  end
end
```

### Stream Substrate Tests

```elixir
defmodule StreamSubstrateTest do
  use ExUnit.Case, async: true

  describe "real-time processing" do
    test "backpressure handling" do
      # Test stream backpressure mechanisms
      assert true
    end

    test "time-based windowing" do
      # Test time-based window operations
      assert true
    end

    test "count-based windowing" do
      # Test count-based window operations
      assert true
    end

    test "stream composition" do
      # Test stream transformation and composition
      assert true
    end
  end
end
```

### Temporal Substrate Tests

```elixir
defmodule TemporalSubstrateTest do
  use ExUnit.Case, async: true

  describe "time-aware computation" do
    test "intent scheduling" do
      # Test temporal intent scheduling
      assert true
    end

    test "temporal reasoning" do
      # Test temporal logic and reasoning
      assert true
    end

    test "time-based capability validation" do
      # Test time-based capability checks
      assert true
    end
  end
end
```

## Integration Testing

### Substrate Integration Tests

```elixir
defmodule SubstrateIntegrationTest do
  use ExUnit.Case

  describe "cross-substrate integration" do
    test "actor-stream integration" do
      # Test actor and stream substrate interaction
      assert true
    end

    test "temporal-actor integration" do
      # Test temporal and actor substrate interaction
      assert true
    end

    test "adt-substrate integration" do
      # Test ADT substrate with other substrates
      assert true
    end
  end
end
```

### Web Integration Tests

```elixir
defmodule WebIntegrationTest do
  use ExUnit.Case

  describe "web framework integration" do
    test "RESTful API endpoints" do
      # Test REST API functionality
      assert true
    end

    test "WebSocket support" do
      # Test real-time WebSocket functionality
      assert true
    end

    test "capability-aware rendering" do
      # Test Temple-based component rendering
      assert true
    end
  end
end
```

## Performance Testing

### Load Testing

```elixir
defmodule PerformanceTest do
  use ExUnit.Case

  describe "system performance" do
    test "high-throughput processing" do
      # Test system under high load
      start_time = System.monotonic_time(:millisecond)
      
      # Generate high load
      results = for i <- 1..1000 do
        # Process intent
        {:ok, _} = process_test_intent(i)
      end
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Assert performance requirements
      assert duration < 5000  # Should complete within 5 seconds
      assert length(results) == 1000
    end

    test "memory usage under load" do
      # Test memory usage patterns
      initial_memory = :erlang.memory(:total)
      
      # Generate load
      for _ <- 1..100 do
        # Process intents
      end
      
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      
      # Assert memory constraints
      assert memory_increase < 50_000_000  # Less than 50MB increase
    end
  end
end
```

## Security Testing

### Capability Testing

```elixir
defmodule SecurityTest do
  use ExUnit.Case

  describe "capability-based security" do
    test "capability validation" do
      # Test capability checking
      user_context = UserContext.new(
        user_id: "user1",
        capabilities: [UserCap.basic]
      )
      
      intent = ReadFileIntent.new("/protected/file.txt", "user1")
      
      # Test capability validation
      assert {:error, :insufficient_capabilities} = 
        validate_intent(intent, user_context)
    end

    test "capability escalation prevention" do
      # Test prevention of capability escalation
      basic_context = UserContext.new(
        user_id: "user1",
        capabilities: [UserCap.basic]
      )
      
      admin_intent = AdminIntent.new("admin_action", "user1")
      
      # Should fail due to insufficient capabilities
      assert {:error, :insufficient_capabilities} = 
        validate_intent(admin_intent, basic_context)
    end

    test "context propagation security" do
      # Test secure context propagation
      assert true
    end
  end
end
```

## Test Data Factories

### Creating Test Data

```elixir
defmodule TestDataFactory do
  def create_user_context(opts \\ []) do
    UserContext.new(
      user_id: Keyword.get(opts, :user_id, "test_user"),
      session_id: Keyword.get(opts, :session_id, "test_session"),
      capabilities: Keyword.get(opts, :capabilities, [UserCap.basic])
    )
  end

  def create_test_intent(type, opts \\ []) do
    case type do
      :read_file ->
        ReadFileIntent.new(
          Keyword.get(opts, :path, "/test/file.txt"),
          Keyword.get(opts, :user_id, "test_user")
        )
      :write_file ->
        WriteFileIntent.new(
          Keyword.get(opts, :path, "/test/file.txt"),
          Keyword.get(opts, :content, "test content"),
          Keyword.get(opts, :user_id, "test_user")
        )
    end
  end

  def create_test_reactor(opts \\ []) do
    TestReactor.start_link(
      Keyword.get(opts, :name, :test_reactor)
    )
  end
end
```

## Mock and Stub Testing

### Component Mocking

```elixir
defmodule MockComponentTest do
  use ExUnit.Case

  describe "mocked components" do
    test "mocked component behavior" do
      # Create mock component
      mock_component = %{
        process_intent: fn intent, context ->
          {:ok, %{processed: true}, []}
        end
      }
      
      # Test with mock
      intent = TestIntent.new("test")
      context = TestContext.new()
      
      {:ok, state, effects} = mock_component.process_intent(intent, context)
      assert state.processed == true
    end
  end
end
```

## Test Reporting and Analysis

### Test Reports

```elixir
defmodule TestReportingTest do
  use ExUnit.Case

  test "test report generation" do
    # Create test suite
    test_cases = [
      Testing.create_test_case("test1", "First test", fn -> assert true end),
      Testing.create_test_case("test2", "Second test", fn -> assert false end)
    ]
    
    suite = Testing.create_test_suite("Test Suite", :test_component, test_cases)
    
    # Run tests
    report = Testing.run_test_suite(suite)
    
    # Analyze results
    assert report.summary.total == 2
    assert report.summary.passed == 1
    assert report.summary.failed == 1
    assert report.summary.total_duration_ms > 0
  end
end
```

## Continuous Integration

### CI Configuration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.14'
        otp-version: '25'
    
    - name: Install dependencies
      run: mix deps.get
    
    - name: Run tests
      run: mix test
    
    - name: Run coverage
      run: mix test --cover
    
    - name: Upload coverage
      uses: codecov/codecov-action@v1
```

## Best Practices

### 1. Test Organization

- **Group related tests** in describe blocks
- **Use descriptive test names** that explain the behavior being tested
- **Keep tests focused** on a single behavior or component
- **Use setup and teardown** for test isolation

### 2. Test Data Management

- **Use factories** for creating test data
- **Keep test data minimal** and focused
- **Clean up test data** after each test
- **Use unique identifiers** to avoid conflicts

### 3. Assertion Patterns

- **Test behavior, not implementation**
- **Use specific assertions** rather than generic ones
- **Test edge cases** and error conditions
- **Verify side effects** when relevant

### 4. Performance Considerations

- **Run performance tests** in separate suites
- **Use realistic data** for performance testing
- **Monitor resource usage** during tests
- **Set appropriate timeouts** for long-running tests

### 5. Security Testing

- **Test capability validation** thoroughly
- **Verify access control** at all levels
- **Test context propagation** security
- **Validate input sanitization**

## Running Tests

### Basic Test Execution

```bash
# Run all tests
mix test

# Run specific test file
mix test test/packetflow/component_test.exs

# Run tests with coverage
mix test --cover

# Run tests with detailed output
mix test --trace

# Run tests in parallel
mix test --max-failures 0
```

### Test Filtering

```bash
# Run tests with specific tags
mix test --only unit
mix test --only integration

# Exclude specific tags
mix test --exclude slow
mix test --exclude integration
```

### Continuous Testing

```bash
# Run tests in watch mode
mix test.watch

# Run tests with automatic recompilation
mix test --watch
```

## Debugging Tests

### Common Issues

1. **Test Isolation**: Ensure tests don't interfere with each other
2. **Async Tests**: Use `async: false` when tests share state
3. **Process Cleanup**: Ensure processes are properly terminated
4. **Resource Leaks**: Monitor for memory or file handle leaks

### Debugging Tools

```elixir
# Enable debug logging
Logger.configure(level: :debug)

# Use IEx.pry for interactive debugging
require IEx
IEx.pry

# Use IO.inspect for data inspection
IO.inspect(data, label: "Debug data")
```

## Conclusion

PacketFlow's testing framework provides comprehensive tools for ensuring system reliability, correctness, and performance. By following the patterns and best practices outlined in this guide, you can build robust, well-tested PacketFlow applications that meet production requirements.

For more information on specific testing scenarios, refer to the individual substrate guides and the DSL guide for detailed examples and patterns.
