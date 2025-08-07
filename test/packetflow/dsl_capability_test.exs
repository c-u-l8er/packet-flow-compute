defmodule PacketFlow.DSLCapabilityTest do
  use ExUnit.Case, async: false
  use PacketFlow.DSL

  test "defcapability creates capability with default implementations" do
    defcapability TestCap1_Default do
      def read(path), do: {:read, path}
      def write(path), do: {:write, path}
    end

    assert TestCap1_Default.read("/test.txt") == {:read, "/test.txt"}
    assert TestCap1_Default.write("/test.txt") == {:write, "/test.txt"}
    assert TestCap1_Default.implies?({:read, "/test.txt"}, {:read, "/test.txt"})
    assert TestCap1_Default.compose([{:read, "/test.txt"}]) == MapSet.new([{:read, "/test.txt"}])
    assert TestCap1_Default.grants({:read, "/test.txt"}) == []
  end

  test "defcapability with implications and grants" do
    defcapability FileSystemCap1_Implications do
      @implications [
        {{:admin}, [{:read, :any}, {:write, :any}, {:delete, :any}]},
        {{:delete, :any}, [{:read, :any}, {:write, :any}]}
      ]

      @grants [
        {{:admin}, [{:read, :any}, {:write, :any}, {:delete, :any}]},
        {{:delete, :any}, [{:read, :any}, {:write, :any}]}
      ]

      def read(path), do: {:read, path}
      def write(path), do: {:write, path}
      def delete(path), do: {:delete, path}
      def admin(), do: {:admin}

      def implies?(cap1, cap2) do
        _implications = @implications
        |> Enum.find(fn {cap, _} -> cap == cap1 end)
        |> case do
          {^cap1, implied_caps} ->
            Enum.any?(implied_caps, fn implied_cap ->
              case {implied_cap, cap2} do
                {{op, :any}, {op2, _}} when op == op2 -> true
                {implied_cap, cap2} -> implied_cap == cap2
              end
            end)
          _ ->
            # Check if cap1 is a specific capability that should imply cap2
            case {cap1, cap2} do
              {{:delete, _}, {:read, _}} -> true
              {{:delete, _}, {:write, _}} -> true
              {cap1, cap2} -> cap1 == cap2
            end
        end
      end

      def grants(capability) do
        grants_map = Map.new(@grants)
        Map.get(grants_map, capability, [])
      end
    end

    admin_cap = FileSystemCap1_Implications.admin()
    read_cap = FileSystemCap1_Implications.read("/test.txt")
    delete_cap = FileSystemCap1_Implications.delete("/test.txt")

    assert FileSystemCap1_Implications.implies?(admin_cap, read_cap)
    assert FileSystemCap1_Implications.implies?(delete_cap, read_cap)
    assert FileSystemCap1_Implications.grants(admin_cap) == [{:read, :any}, {:write, :any}, {:delete, :any}]
  end

  test "defsimple_capability creates capability with basic operations" do
    defsimple_capability UserCap1_Basic, [:basic, :admin] do
      @implications [
        {{:admin}, [{:basic}]}
      ]
    end

    basic_cap = UserCap1_Basic.basic()
    admin_cap = UserCap1_Basic.admin()

    assert basic_cap == {:basic}
    assert admin_cap == {:admin}
    assert UserCap1_Basic.implies?(admin_cap, basic_cap)
  end
end
