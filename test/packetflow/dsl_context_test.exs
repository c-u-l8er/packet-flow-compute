defmodule PacketFlow.DSLContextTest do
  use ExUnit.Case, async: false
  use PacketFlow.DSL

    test "defcontext creates context with default implementations" do
    defcontext ContextTest1_Default_Unique2 do
      defstruct [:field1]

      def new(attrs \\ []) do
        struct(__MODULE__, attrs)
      end
    end

    context = ContextTest1_Default_Unique2.new(field1: "value1")

    assert context.field1 == "value1"
    assert ContextTest1_Default_Unique2.propagate(context, SomeModule) == context
    assert ContextTest1_Default_Unique2.compose(context, context, :merge) == context
  end

    test "defcontext with custom propagation strategy" do
    defcontext RequestContext1_Custom_Unique2 do
      @propagation_strategy :inherit

      defstruct [:user_id, :session_id, :request_id, :capabilities, :trace]

      def new(attrs \\ []) do
        struct(__MODULE__, attrs)
        |> ensure_request_id()
      end

      def propagate(context, target_module) do
        %__MODULE__{
          user_id: context.user_id,
          session_id: context.session_id,
          request_id: generate_request_id(),
          capabilities: context.capabilities,
          trace: [target_module | (context.trace || [])]
        }
      end

      defp generate_request_id, do: "req_#{:rand.uniform(1000)}"

      defp ensure_request_id(context) do
        if context.request_id == nil do
          %{context | request_id: generate_request_id()}
        else
          context
        end
      end
    end

    context = RequestContext1_Custom_Unique2.new(user_id: "user1", session_id: "session1")
    propagated = RequestContext1_Custom_Unique2.propagate(context, SomeModule)

    assert propagated.user_id == "user1"
    assert propagated.session_id == "session1"
    assert propagated.trace == [SomeModule]
    assert propagated.request_id != context.request_id
  end

    test "defsimple_context creates context with basic fields" do
    defsimple_context UserContext1_Simple_Unique, [:user_id, :session_id, :capabilities] do
      @propagation_strategy :inherit
    end

    context = UserContext1_Simple_Unique.new(user_id: "user1", session_id: "session1")

    assert context.user_id == "user1"
    assert context.session_id == "session1"
  end
end
