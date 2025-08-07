# PacketFlow Web Framework Integration Design Specification

## Overview

This document outlines the design specification for integrating PacketFlow as a web server framework that leverages Temple for component-based UI development. This integration positions PacketFlow as a higher-level web framework that builds upon the substrate architecture rather than implementing web capabilities at the substrate level.

## Architectural Decision: Higher-Level Integration

### **Why Higher-Level Integration?**

**1. Separation of Concerns**: Web frameworks require components, routes, middleware, and UI patterns that are fundamentally different from the core substrate capabilities (ADT, Actor, Stream, Temporal).

**2. Substrate Purity**: The substrates should remain focused on their core responsibilities:
- **ADT**: Algebraic data types and type-level reasoning
- **Actor**: Distributed actor orchestration
- **Stream**: Real-time stream processing
- **Temporal**: Time-aware computation

**3. Framework Composition**: Web frameworks are better implemented as higher-level compositions that leverage the substrates rather than being substrates themselves.

**4. Temple Integration**: Temple's component-based approach aligns perfectly with PacketFlow's intent-context-capability model.

## Web Framework Architecture

### **PacketFlow.Web - The Web Framework Layer**

```elixir
defmodule PacketFlow.Web do
  @moduledoc """
  PacketFlow Web Framework: Higher-level web framework that leverages
  PacketFlow substrates for backend processing and Temple for UI components.
  """

  defmacro __using__(opts \\ []) do
    quote do
      use PacketFlow.Temporal  # Full substrate stack
      use Temple              # Component-based UI
      
      # Web-specific imports
      import PacketFlow.Web.Router
      import PacketFlow.Web.Component
      import PacketFlow.Web.Middleware
      import PacketFlow.Web.Capability
      
      # Web configuration
      @web_config Keyword.get(unquote(opts), :web_config, [])
    end
  end
end
```

### **Core Web Framework Components**

#### **1. PacketFlow.Web.Router - Intent-Based Routing**

```elixir
defmodule PacketFlow.Web.Router do
  @moduledoc """
  Intent-based routing that maps HTTP requests to PacketFlow intents
  """

  defroute "/api/users/:id", UserIntent do
    @capabilities [UserCap.read]
    @method [:GET, :PUT, :DELETE]
    @temporal_constraints [:business_hours]
    
    def handle_request(conn, params) do
      case conn.method do
        "GET" -> handle_get_user(conn, params)
        "PUT" -> handle_update_user(conn, params)
        "DELETE" -> handle_delete_user(conn, params)
      end
    end
  end

  defroute "/api/streams/:stream_id", StreamIntent do
    @capabilities [StreamCap.read, StreamCap.write]
    @method [:GET, :POST]
    @backpressure_strategy :drop_oldest
    
    def handle_request(conn, params) do
      case conn.method do
        "GET" -> handle_stream_read(conn, params)
        "POST" -> handle_stream_write(conn, params)
      end
    end
  end
end
```

#### **2. PacketFlow.Web.Component - Temple Integration**

```elixir
defmodule PacketFlow.Web.Component do
  @moduledoc """
  Temple component integration with PacketFlow capabilities
  """

  defcomponent UserProfile, [:user_id, :capabilities] do
    @capabilities [UserCap.read, UserCap.display]
    @temple_component true
    
    def render(assigns) do
      temple do
        div class: "user-profile" do
          h2 do: assigns.user.name
          div class: "user-stats" do
            span do: "Posts: #{assigns.user.post_count}"
            span do: "Followers: #{assigns.user.follower_count}"
          end
          
          if has_capability?(assigns.capabilities, UserCap.admin) do
            div class: "admin-controls" do
              button onclick: "admin_action" do: "Admin Actions"
            end
          end
        end
      end
    end
    
    def handle_event("admin_action", _params, socket) do
      # Handle admin action with capability validation
      if has_capability?(socket.assigns.capabilities, UserCap.admin) do
        {:noreply, socket}
      else
        {:error, :insufficient_capabilities}
      end
    end
  end

  defcomponent RealTimeFeed, [:stream_id, :capabilities] do
    @capabilities [StreamCap.read, StreamCap.realtime]
    @temple_component true
    @backpressure_strategy :drop_oldest
    
    def render(assigns) do
      temple do
        div class: "realtime-feed", data: [stream_id: assigns.stream_id] do
          div class: "feed-messages" do
            for message <- assigns.messages do
              div class: "message" do
                span class: "timestamp" do: message.timestamp
                span class: "content" do: message.content
              end
            end
          end
        end
      end
    end
    
    def handle_info({:stream_message, message}, socket) do
      # Handle real-time stream messages
      {:noreply, assign(socket, messages: [message | socket.assigns.messages])}
    end
  end
end
```

#### **3. PacketFlow.Web.Middleware - Capability-Aware Middleware**

```elixir
defmodule PacketFlow.Web.Middleware do
  @moduledoc """
  Capability-aware middleware for PacketFlow web applications
  """

  defmiddleware PacketFlow.CapabilityMiddleware do
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
        |> json(%{error: "insufficient_capabilities"})
        |> halt()
      end
    end
  end

  defmiddleware PacketFlow.TemporalMiddleware do
    def call(conn, _opts) do
      # Apply temporal constraints
      if temporal_valid?(conn) do
        conn
        |> assign(:temporal_context, build_temporal_context(conn))
      else
        conn
        |> put_status(400)
        |> json(%{error: "temporal_constraint_violation"})
        |> halt()
      end
    end
  end

  defmiddleware PacketFlow.StreamMiddleware do
    def call(conn, _opts) do
      # Handle real-time stream connections
      case conn.path_info do
        ["api", "streams", _stream_id] ->
          handle_stream_connection(conn)
        _ ->
          conn
      end
    end
  end
end
```

#### **4. PacketFlow.Web.Capability - Web-Specific Capabilities**

```elixir
defmodule PacketFlow.Web.Capability do
  @moduledoc """
  Web-specific capabilities for UI components and routes
  """

  defweb_capability UICap, [:read, :write, :admin, :display] do
    @implications [
      {UICap.admin, [UICap.read, UICap.write, UICap.display]},
      {UICap.write, [UICap.read, UICap.display]},
      {UICap.display, [UICap.read]}
    ]
    
    def read(component), do: {:read, component}
    def write(component), do: {:write, component}
    def admin(component), do: {:admin, component}
    def display(component), do: {:display, component}
  end

  defweb_capability RouteCap, [:get, :post, :put, :delete, :stream] do
    @implications [
      {RouteCap.stream, [RouteCap.get, RouteCap.post]},
      {RouteCap.delete, [RouteCap.get]},
      {RouteCap.put, [RouteCap.get, RouteCap.post]}
    ]
    
    def get(route), do: {:get, route}
    def post(route), do: {:post, route}
    def put(route), do: {:put, route}
    def delete(route), do: {:delete, route}
    def stream(route), do: {:stream, route}
  end
end
```

## Integration with Temple

### **Temple Component Integration**

```elixir
defmodule MyApp.Web do
  use PacketFlow.Web
  
  # Define Temple components with PacketFlow capabilities
  defcomponent Dashboard, [:user_id, :capabilities] do
    @capabilities [UICap.display, RouteCap.get]
    @temple_component true
    
    def render(assigns) do
        temple do
            div class: "dashboard" do
                header do
                    h1 do: "Dashboard"
                    if has_capability?(assigns.capabilities, UICap.admin) do
                        nav class: "admin-nav" do
                            a href: "/admin" do: "Admin Panel"
                        end
                    end
                end
                
                main do
                    section class: "widgets" do
                        # Temple component composition
                        UserProfile.render(user_id: assigns.user_id, capabilities: assigns.capabilities)
                        RealTimeFeed.render(stream_id: "dashboard-feed", capabilities: assigns.capabilities)
                    end
                end
            end
        end
    end
  end

  # Define routes that map to PacketFlow intents
  defroute "/dashboard", DashboardIntent do
    @capabilities [UICap.display, RouteCap.get]
    @method [:GET]
    
    def handle_request(conn, _params) do
      user_id = get_session(conn, :user_id)
      capabilities = conn.assigns.capabilities
      
      # Create intent for dashboard rendering
      intent = DashboardIntent.new(user_id: user_id, capabilities: capabilities)
      
      # Process through PacketFlow substrates
      case PacketFlow.Temporal.process_intent(intent) do
        {:ok, dashboard_data, _effects} ->
          conn
          |> assign(:dashboard_data, dashboard_data)
          |> render("dashboard.html")
        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: reason})
      end
    end
  end
end
```

### **Real-Time WebSocket Integration**

```elixir
defmodule PacketFlow.Web.WebSocket do
  @moduledoc """
  WebSocket integration for real-time PacketFlow communication
  """

  defwebsocket "/socket", PacketFlowSocket do
    @capabilities [StreamCap.read, StreamCap.write]
    @backpressure_strategy :drop_oldest
    
    def handle_connect(socket, _params) do
      # Validate capabilities for WebSocket connection
      if has_capabilities?(socket.assigns.capabilities, @capabilities) do
        {:ok, socket}
      else
        {:error, :insufficient_capabilities}
      end
    end
    
    def handle_in("join_stream", %{"stream_id" => stream_id}, socket) do
      # Join a real-time stream
      case PacketFlow.Stream.join_stream(stream_id, socket) do
        {:ok, stream_socket} ->
          {:reply, {:ok, %{stream_id: stream_id}}, stream_socket}
        {:error, reason} ->
          {:reply, {:error, reason}, socket}
      end
    end
    
    def handle_in("send_message", %{"message" => message}, socket) do
      # Send message through PacketFlow stream
      intent = MessageIntent.new(
        content: message,
        user_id: socket.assigns.user_id,
        capabilities: socket.assigns.capabilities
      )
      
      case PacketFlow.Stream.process_intent(intent) do
        {:ok, _result, _effects} ->
          {:reply, {:ok, %{message: "sent"}}, socket}
        {:error, reason} ->
          {:reply, {:error, reason}, socket}
      end
    end
  end
end
```

## Web Framework Configuration

### **Application Configuration**

```elixir
# config/config.exs
config :packetflow_web, :web_framework, [
  temple: [
    components_path: "lib/myapp_web/components",
    templates_path: "lib/myapp_web/templates"
  ],
  substrates: [
    adt: [capability_check: true],
    actor: [cluster_size: 3],
    stream: [backpressure_strategy: :drop_oldest],
    temporal: [timezone: "UTC"]
  ],
  middleware: [
    PacketFlow.Web.Middleware.CapabilityMiddleware,
    PacketFlow.Web.Middleware.TemporalMiddleware,
    PacketFlow.Web.Middleware.StreamMiddleware
  ],
  capabilities: [
    default: [UICap.display, RouteCap.get],
    admin: [UICap.admin, RouteCap.delete],
    stream: [StreamCap.read, StreamCap.write]
  ]
]
```

### **Component Configuration**

```elixir
# lib/myapp_web/components/dashboard.ex
defcomponent Dashboard, [:user_id, :capabilities] do
  @capabilities [UICap.display, RouteCap.get]
  @temple_component true
  @substrates [:adt, :actor, :stream, :temporal]
  
  def render(assigns) do
    ~H"""
    <div class="dashboard" phx-hook="DashboardHook">
      <UserProfile user_id={@user_id} capabilities={@capabilities} />
      <RealTimeFeed stream_id="dashboard-feed" capabilities={@capabilities} />
    </div>
    """
  end
  
  def handle_event("refresh", _params, socket) do
    # Trigger refresh through PacketFlow substrates
    intent = RefreshIntent.new(
      user_id: socket.assigns.user_id,
      capabilities: socket.assigns.capabilities
    )
    
    case PacketFlow.Temporal.process_intent(intent) do
      {:ok, new_data, _effects} ->
        {:noreply, assign(socket, data: new_data)}
      {:error, _reason} ->
        {:noreply, socket}
    end
  end
end
```

## Advanced Web Framework Features

### **1. Component State Management**

```elixir
defmodule PacketFlow.Web.State do
  @moduledoc """
  Component state management with PacketFlow substrates
  """

  defcomponent_state UserState, [:user_id] do
    @capabilities [UserCap.read, UserCap.write]
    @substrates [:adt, :actor]
    
    def init(user_id) do
      # Initialize state through PacketFlow substrates
      intent = UserStateIntent.new(user_id: user_id)
      
      case PacketFlow.Actor.process_intent(intent) do
        {:ok, state, _effects} -> {:ok, state}
        {:error, reason} -> {:error, reason}
      end
    end
    
    def update(state, action) do
      # Update state through PacketFlow substrates
      intent = UserUpdateIntent.new(
        user_id: state.user_id,
        action: action,
        current_state: state
      )
      
      case PacketFlow.Actor.process_intent(intent) do
        {:ok, new_state, _effects} -> {:ok, new_state}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
```

### **2. Real-Time Component Updates**

```elixir
defmodule PacketFlow.Web.RealTime do
  @moduledoc """
  Real-time component updates through PacketFlow streams
  """

  defrealtime_component LiveFeed, [:stream_id, :capabilities] do
    @capabilities [StreamCap.read, UICap.display]
    @backpressure_strategy :drop_oldest
    @window_size {:time, {:seconds, 30}}
    
    def render(assigns) do
      temple do
        div class: "live-feed", data: [stream_id: assigns.stream_id] do
          div class: "feed-messages" do
            for message <- assigns.messages do
              div class: "message", data: [timestamp: message.timestamp] do
                span class: "content" do: message.content
              end
            end
          end
        end
      end
    end
    
    def handle_stream_message(message, socket) do
      # Handle real-time stream messages
      case validate_message_capabilities(message, socket.assigns.capabilities) do
        {:ok, validated_message} ->
          {:noreply, assign(socket, messages: [validated_message | socket.assigns.messages])}
        {:error, _reason} ->
          {:noreply, socket}
      end
    end
  end
end
```

### **3. Temporal Component Scheduling**

```elixir
defmodule PacketFlow.Web.Temporal do
  @moduledoc """
  Temporal component scheduling and time-aware UI updates
  """

  deftemporal_component ScheduledWidget, [:schedule, :capabilities] do
    @capabilities [UICap.display, TemporalCap.schedule]
    @schedule "0 */5 * * * *" # Every 5 minutes
    @temporal_constraints [:business_hours]
    
    def render(assigns) do
      temple do
        div class: "scheduled-widget" do
          h3 do: "Scheduled Updates"
          div class: "widget-content" do
            if assigns.data do
              div class: "data-display" do: assigns.data.content
            else
              div class: "loading" do: "Loading..."
            end
          end
        end
      end
    end
    
    def handle_scheduled_update(socket) do
      # Handle scheduled updates through PacketFlow temporal substrate
      intent = ScheduledUpdateIntent.new(
        schedule: socket.assigns.schedule,
        capabilities: socket.assigns.capabilities
      )
      
      case PacketFlow.Temporal.process_intent(intent) do
        {:ok, new_data, _effects} ->
          {:noreply, assign(socket, data: new_data)}
        {:error, _reason} ->
          {:noreply, socket}
      end
    end
  end
end
```

## Testing Strategy

### **Component Testing**

```elixir
defmodule MyAppWeb.DashboardTest do
  use MyAppWeb.ConnCase
  use PacketFlow.Test
  
  test "dashboard renders with correct capabilities" do
    user_id = "user123"
    capabilities = [UICap.display, RouteCap.get]
    
    # Test component rendering with capabilities
    assert render_component(Dashboard, user_id: user_id, capabilities: capabilities)
           =~ "Dashboard"
    
    # Test capability-based conditional rendering
    admin_capabilities = [UICap.admin, UICap.display, RouteCap.get]
    assert render_component(Dashboard, user_id: user_id, capabilities: admin_capabilities)
           =~ "Admin Panel"
  end
  
  test "dashboard handles real-time updates" do
    # Test real-time stream integration
    socket = connect(MyAppWeb.UserSocket, %{})
    
    # Simulate stream message
    send(socket.channel_pid, {:stream_message, %{content: "Test message"}})
    
    assert_receive %{messages: [%{content: "Test message"}]}
  end
end
```

### **Integration Testing**

```elixir
defmodule MyAppWeb.IntegrationTest do
  use MyAppWeb.ConnCase
  use PacketFlow.Test
  
  test "full request flow through substrates" do
    # Test complete flow from HTTP request through all substrates
    conn = build_conn()
    |> put_req_header("authorization", "Bearer token123")
    
    response = conn
    |> get("/dashboard")
    |> json_response(200)
    
    assert response["dashboard_data"]
    assert response["capabilities"]
  end
end
```

## Deployment and Production

### **Web Framework Deployment**

```elixir
# lib/myapp_web/application.ex
defmodule MyAppWeb.Application do
  use Application

  def start(_type, _args) do
    children = [
      # PacketFlow substrates
      {PacketFlow.Actor.Supervisor, []},
      {PacketFlow.Stream.Supervisor, []},
      {PacketFlow.Temporal.Scheduler, []},
      
      # Web framework
      MyAppWeb.Endpoint,
      MyAppWeb.Presence,
      
      # Temple components
      MyAppWeb.ComponentRegistry
    ]

    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### **Production Configuration**

```elixir
# config/prod.exs
config :myapp_web, MyAppWeb.Endpoint,
  url: [host: "myapp.com", port: 443],
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]

config :packetflow_web, :production, [
  substrates: [
    actor: [cluster_size: 5, fault_tolerance: :restart],
    stream: [backpressure_strategy: :drop_oldest, window_size: {:time, {:minutes, 5}}],
    temporal: [timezone: "UTC", temporal_reasoning: true]
  ],
  capabilities: [
    rate_limiting: true,
    circuit_breaker: true,
    monitoring: true
  ]
]
```

## Conclusion

This design specification positions PacketFlow as a higher-level web framework that:

1. **Leverages Existing Substrates**: Uses ADT, Actor, Stream, and Temporal substrates for backend processing
2. **Integrates with Temple**: Provides component-based UI development with capability-aware components
3. **Maintains Separation of Concerns**: Keeps web framework concerns separate from substrate capabilities
4. **Enables Progressive Enhancement**: Start with basic components and add real-time, temporal, and distributed capabilities
5. **Provides Type Safety**: Capability-based security and type-level constraints throughout the web stack

The web framework layer acts as a composition layer that brings together PacketFlow's substrate capabilities with Temple's component-based UI development, creating a powerful foundation for building modern web applications with distributed, real-time, and time-aware capabilities.
