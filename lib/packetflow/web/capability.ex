defmodule PacketFlow.Web.Capability do
  @moduledoc """
  Web-specific capabilities for UI components and routes
  """

  defmacro defweb_capability(name, operations, do: body) do
    implications = Keyword.get(body, :implications, [])

    quote do
      defmodule unquote(name) do
        @implications unquote(implications)

        unquote(body)

        def implies?(cap1, cap2) do
          implications = @implications
          |> Enum.find(fn {cap, _} -> cap == cap1 end)
          |> case do
            {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
            _ -> cap1 == cap2
          end
        end
      end
    end
  end

  # Define UI capabilities
  defmodule UICap do
    def read(component), do: {:read, component}
    def write(component), do: {:write, component}
    def admin(component), do: {:admin, component}
    def display(component), do: {:display, component}

    @implications [
      {{:admin, ""}, [{:read, ""}, {:write, ""}, {:display, ""}]},
      {{:write, ""}, [{:read, ""}, {:display, ""}]},
      {{:display, ""}, [{:read, ""}]}
    ]

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end
  end

  # Define route capabilities
  defmodule RouteCap do
    def get(route), do: {:get, route}
    def post(route), do: {:post, route}
    def put(route), do: {:put, route}
    def delete(route), do: {:delete, route}
    def stream(route), do: {:stream, route}

    @implications [
      {{:stream, ""}, [{:get, ""}, {:post, ""}]},
      {{:delete, ""}, [{:get, ""}]},
      {{:put, ""}, [{:get, ""}, {:post, ""}]}
    ]

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end
  end

  # Define stream capabilities
  defmodule StreamCap do
    def read(stream), do: {:read, stream}
    def write(stream), do: {:write, stream}
    def admin(stream), do: {:admin, stream}

    @implications [
      {{:admin, ""}, [{:read, ""}, {:write, ""}]},
      {{:write, ""}, [{:read, ""}]}
    ]

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end
  end

  # Define file capabilities
  defmodule FileCap do
    def read(path), do: {:read, path}
    def write(path), do: {:write, path}
    def delete(path), do: {:delete, path}
    def admin(), do: {:admin}

    @implications [
      {{:admin}, [{:read, ""}, {:write, ""}, {:delete, ""}]},
      {{:delete, ""}, [{:read, ""}, {:write, ""}]},
      {{:write, ""}, [{:read, ""}]}
    ]

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end
  end

  # Define user capabilities
  defmodule UserCap do
    def read(user), do: {:read, user}
    def write(user), do: {:write, user}
    def admin(user), do: {:admin, user}

    @implications [
      {{:admin, ""}, [{:read, ""}, {:write, ""}]},
      {{:write, ""}, [{:read, ""}]}
    ]

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end
  end
end
