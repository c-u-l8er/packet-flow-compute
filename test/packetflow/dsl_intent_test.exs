defmodule PacketFlow.DSLIntentTest do
  use ExUnit.Case, async: false
  use PacketFlow.DSL

    test "defintent creates intent with default implementations" do
    defintent IntentTest1_Default do
      defstruct [:field1, :field2]
    end

    intent = struct(IntentTest1_Default, field1: "value1", field2: "value2")

    assert IntentTest1_Default.required_capabilities(intent) == []
    assert %PacketFlow.Reactor.Message{} = IntentTest1_Default.to_reactor_message(intent)
    assert %PacketFlow.Effect{} = IntentTest1_Default.to_effect(intent)
  end

    test "defintent with custom capability requirements" do
    # Define a simple capability first
    defcapability TestFileCap1_Custom do
      def read(path), do: {:read, path}
    end

    defintent FileReadIntent1_Custom do
      @capabilities []

      defstruct [:path, :user_id]

      def required_capabilities(intent) do
        [TestFileCap1_Custom.read(intent.path)]
      end
    end

    intent = struct(FileReadIntent1_Custom, path: "/test.txt", user_id: "user1")

    assert FileReadIntent1_Custom.required_capabilities(intent) == [TestFileCap1_Custom.read("/test.txt")]
  end

    test "defsimple_intent creates intent with minimal boilerplate" do
    defsimple_intent SimpleIntent1_Minimal_Unique, [:field1, :field2] do
      @capabilities []
      @effect nil
    end

    intent = SimpleIntent1_Minimal_Unique.new("value1", "value2")

    assert intent.field1 == "value1"
    assert intent.field2 == "value2"
    assert SimpleIntent1_Minimal_Unique.required_capabilities(intent) == []
  end
end
