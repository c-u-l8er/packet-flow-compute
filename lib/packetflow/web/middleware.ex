defmodule PacketFlow.Web.Middleware do
  @moduledoc """
  Capability-aware middleware for PacketFlow web applications
  """

  defmacro defmiddleware(name, do: body) do
    quote do
      defmodule unquote(name) do
        use Plug

        def init(opts), do: opts

        def call(conn, opts) do
          unquote(body)
        end
      end
    end
  end
end

# Define capability middleware
defmodule PacketFlow.CapabilityMiddleware do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extract capabilities from request
    capabilities = extract_capabilities(conn)

    # Validate capabilities for the route
    if validate_route_capabilities(conn, capabilities) do
      conn
      |> assign(:capabilities, capabilities)
      |> assign(:user_context, build_user_context(conn, capabilities))
    else
      conn
      |> put_status(403)
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "insufficient_capabilities"}))
      |> halt()
    end
  end

  defp extract_capabilities(conn) do
    # Extract capabilities from various sources
    token_capabilities = extract_token_capabilities(conn)
    session_capabilities = extract_session_capabilities(conn)
    header_capabilities = extract_header_capabilities(conn)

    # Merge capabilities
    MapSet.union(token_capabilities, MapSet.union(session_capabilities, header_capabilities))
  end

  defp extract_token_capabilities(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case decode_token(token) do
          {:ok, %{"capabilities" => caps}} -> MapSet.new(caps)
          _ -> MapSet.new()
        end
      _ ->
        MapSet.new()
    end
  end

  defp extract_session_capabilities(conn) do
    case get_session(conn, :capabilities) do
      nil -> MapSet.new()
      caps -> MapSet.new(caps)
    end
  end

  defp extract_header_capabilities(conn) do
    case get_req_header(conn, "x-capabilities") do
      [caps_header] ->
        case Jason.decode(caps_header) do
          {:ok, caps} -> MapSet.new(caps)
          _ -> MapSet.new()
        end
      _ ->
        MapSet.new()
    end
  end

  defp validate_route_capabilities(conn, capabilities) do
    # Get required capabilities for the route
    required_capabilities = get_route_capabilities(conn)

    # Check if user has required capabilities
    Enum.all?(required_capabilities, fn required_cap ->
      Enum.any?(capabilities, fn user_cap ->
        PacketFlow.Capability.implies?(user_cap, required_cap)
      end)
    end)
  end

  defp get_route_capabilities(conn) do
    # Extract route capabilities from path or configuration
    case conn.path_info do
      ["api", "admin" | _] -> [UICap.admin]
      ["api", "users" | _] -> [UICap.read, UICap.write]
      ["api", "files" | _] -> [FileCap.read]
      _ -> [UICap.display]
    end
  end

  defp build_user_context(conn, capabilities) do
    %{
      user_id: get_user_id(conn),
      session_id: get_session(conn, :session_id),
      capabilities: capabilities,
      timestamp: DateTime.utc_now()
    }
  end

  defp get_user_id(conn) do
    get_session(conn, :user_id) ||
    extract_user_from_token(conn) ||
    "anonymous"
  end

  defp extract_user_from_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case decode_token(token) do
          {:ok, %{"user_id" => user_id}} -> user_id
          _ -> nil
        end
      _ ->
        nil
    end
  end

  defp decode_token(token) do
    # Simple token decoding - in production, use proper JWT library
    case Base.decode64(token) do
      {:ok, decoded} ->
        case Jason.decode(decoded) do
          {:ok, data} -> {:ok, data}
          _ -> {:error, :invalid_token}
        end
      _ ->
        {:error, :invalid_token}
    end
  end
end

# Define temporal middleware
defmodule PacketFlow.TemporalMiddleware do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Apply temporal constraints
    if temporal_valid?(conn) do
      conn
      |> assign(:temporal_context, build_temporal_context(conn))
    else
      conn
      |> put_status(400)
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "temporal_constraint_violation"}))
      |> halt()
    end
  end

  defp temporal_valid?(conn) do
    # Check temporal constraints based on route
    case conn.path_info do
      ["api", "admin" | _] -> validate_business_hours()
      ["api", "scheduled" | _] -> validate_weekdays()
      _ -> true
    end
  end

  defp validate_business_hours() do
    now = DateTime.utc_now()
    hour = now.hour
    hour >= 9 and hour < 17
  end

  defp validate_weekdays() do
    now = DateTime.utc_now()
    weekday = Date.day_of_week(now)
    weekday >= 1 and weekday <= 5
  end

  defp build_temporal_context(conn) do
    %{
      current_time: DateTime.utc_now(),
      timezone: "UTC",
      business_hours: {9, 17},
      weekdays: [1, 2, 3, 4, 5]
    }
  end
end

# Define stream middleware
defmodule PacketFlow.StreamMiddleware do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Handle real-time stream connections
    case conn.path_info do
      ["api", "streams", _stream_id] ->
        handle_stream_connection(conn)
      _ ->
        conn
    end
  end

  defp handle_stream_connection(conn) do
    # Validate stream capabilities
    stream_id = List.last(conn.path_info)
    capabilities = conn.assigns[:capabilities] || MapSet.new()

    if has_stream_capabilities?(capabilities, stream_id) do
      conn
      |> assign(:stream_id, stream_id)
      |> assign(:stream_capabilities, get_stream_capabilities(stream_id))
    else
      conn
      |> put_status(403)
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "insufficient_stream_capabilities"}))
      |> halt()
    end
  end

  defp has_stream_capabilities?(capabilities, stream_id) do
    required_caps = get_stream_capabilities(stream_id)
    Enum.all?(required_caps, fn cap ->
      Enum.any?(capabilities, fn user_cap ->
        PacketFlow.Capability.implies?(user_cap, cap)
      end)
    end)
  end

  defp get_stream_capabilities(stream_id) do
    case stream_id do
      "public" -> [StreamCap.read]
      "private" -> [StreamCap.read, StreamCap.write]
      "admin" -> [StreamCap.read, StreamCap.write, StreamCap.admin]
      _ -> [StreamCap.read]
    end
  end
end
