defmodule PacketFlow.Web.Router do
  @moduledoc """
  Intent-based routing that maps HTTP requests to PacketFlow intents
  """

  defmacro defroute(path, intent_module, do: body) do
    quote do
      def route(unquote(path), conn, params) do
        unquote(body)
      end
    end
  end

  defmacro defroute(path, intent_module, opts \\ [], do: body) do
    capabilities = Keyword.get(opts, :capabilities, [])
    method = Keyword.get(opts, :method, [:GET])
    temporal_constraints = Keyword.get(opts, :temporal_constraints, [])
    backpressure_strategy = Keyword.get(opts, :backpressure_strategy, nil)

    quote do
      def route(unquote(path), conn, params) do
        # Validate capabilities
        if validate_route_capabilities(conn, unquote(capabilities)) do
          # Apply temporal constraints
          if temporal_valid?(conn, unquote(temporal_constraints)) do
            # Handle request based on method
            case conn.method do
              method when method in unquote(method) ->
                unquote(body)
              _ ->
                conn
                |> put_status(405)
                |> json(%{error: "method_not_allowed"})
            end
          else
            conn
            |> put_status(400)
            |> json(%{error: "temporal_constraint_violation"})
          end
        else
          conn
          |> put_status(403)
          |> json(%{error: "insufficient_capabilities"})
        end
      end
    end
  end

  defp validate_route_capabilities(conn, required_capabilities) do
    user_capabilities = conn.assigns[:capabilities] || MapSet.new()
    Enum.all?(required_capabilities, fn cap ->
      Enum.any?(user_capabilities, fn user_cap ->
        PacketFlow.Capability.implies?(user_cap, cap)
      end)
    end)
  end

  defp temporal_valid?(conn, constraints) do
    case constraints do
      [:business_hours] -> validate_business_hours(conn)
      [:weekdays] -> validate_weekdays(conn)
      _ -> true
    end
  end

  defp validate_business_hours(_conn) do
    # Simple business hours validation (9 AM - 5 PM UTC)
    now = DateTime.utc_now()
    hour = now.hour
    hour >= 9 and hour < 17
  end

  defp validate_weekdays(_conn) do
    # Simple weekday validation (Monday - Friday)
    now = DateTime.utc_now()
    weekday = Date.day_of_week(now)
    weekday >= 1 and weekday <= 5
  end
end
