defmodule PacketFlow.Web do
  @moduledoc """
  PacketFlow Web Framework: Higher-level web framework that leverages
  PacketFlow substrates for backend processing and Temple for UI components.
  """

  defmacro __using__(opts \\ []) do
    quote do
      use PacketFlow.Temporal  # Full substrate stack
      import Temple           # Component-based UI

      # Web-specific imports
      import PacketFlow.Web.Router
      import PacketFlow.Web.Component
      import PacketFlow.Web.Middleware
      import PacketFlow.Web.Capability

      # Web configuration
      @web_config Keyword.get(unquote(opts), :web_config, [])

      # Import common web functions
      import Plug.Conn, only: [put_status: 2, put_resp_content_type: 2, send_resp: 3, halt: 1]
      import Jason, only: [encode!: 1]

      # Define json/2 function for convenience
      def json(conn, data) do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(conn.status || 200, encode!(data))
      end

      # Define missing functions for router
      def validate_route_capabilities(conn, required_capabilities) do
        user_capabilities = conn.assigns[:capabilities] || MapSet.new()
        Enum.all?(required_capabilities, fn cap ->
          Enum.any?(user_capabilities, fn user_cap ->
            # Mock capability checking for now
            user_cap == cap
          end)
        end)
      end

      def temporal_valid?(conn, constraints) do
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
  end
end
