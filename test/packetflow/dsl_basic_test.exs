defmodule PacketFlow.DSLBasicTest do
  use ExUnit.Case, async: true
  use PacketFlow.DSL

  test "Basic DSL functionality" do
    # Test 1: Basic capability
    defcapability BasicCap do
      def read(path), do: {:read, path}
    end

    assert BasicCap.read("/test.txt") == {:read, "/test.txt"}
    assert BasicCap.implies?({:read, "/test.txt"}, {:read, "/test.txt"})
    assert BasicCap.compose([{:read, "/test.txt"}]) == MapSet.new([{:read, "/test.txt"}])
    assert BasicCap.grants({:read, "/test.txt"}) == []

    # Test 2: Basic context
    defcontext BasicContext do
      defstruct []

      def new(attrs \\ []) do
        struct(__MODULE__, attrs)
      end
    end

    context = BasicContext.new()
    assert context != nil

    # Test 3: Basic intent
    defintent BasicIntent do
      # Uses default struct
    end

    # Test 4: Basic reactor
    defreactor BasicReactor do
      @initial_state %{count: 0}
    end

    assert {:ok, _pid} = BasicReactor.start_link()
    assert {:error, :not_implemented} = BasicReactor.process_intent(%{}, %{count: 0})
  end
end
