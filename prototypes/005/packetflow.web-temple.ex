defmodule PacketFlow.WebTemple do
  @moduledoc """
  PacketFlow Web Temple: Temple-based web interface generation for the ADT substrate

  This module provides:
  - Temple-based UI generation for intents, contexts, and capabilities
  - Reactive web interfaces with real-time updates
  - Web-based intent submission and capability management
  - Context visualization and propagation tracking
  - Actor monitoring and state inspection web interfaces
  """

  defmacro __using__(opts \\ []) do
    quote do
      import PacketFlow.WebTemple.DSL
      import PacketFlow.WebTemple.Components
      import PacketFlow.WebTemple.Routing
      import PacketFlow.WebTemple.Reactivity

      # Enable live updates by default
      @live_updates_enabled Keyword.get(unquote(opts), :live_updates, true)
      @websocket_enabled Keyword.get(unquote(opts), :websocket, true)
    end
  end
end

defmodule PacketFlow.WebTemple.DSL do
  @moduledoc """
  DSL for defining Temple-based web interfaces for PacketFlow components
  """

  @doc """
  Define a web interface for an intent with Temple components

  ## Example
  ```elixir
  defweb_intent FileOpWeb do
    @intent_module FileOp
    @capability_module FileSystemCap

    # Intent form generation
    def intent_form(context) do
      form_for context, "/intents/file_op", fn f ->
        div class: "intent-form" do
          div class: "form-group" do
            label f, "Operation Type"
            select f, :operation, [
              {"Read File", :read_file},
              {"Write File", :write_file},
              {"Delete File", :delete_file}
            ], class: "form-control"
          end

          div class: "form-group" do
            label f, "File Path"
            text_input f, :path, class: "form-control"
          end

          div class: "form-group" do
            label f, "Content (for write operations)"
            textarea f, :content, class: "form-control"
          end

          div class: "form-group" do
            label f, "Required Capabilities"
            capability_selector f, :capabilities, available_capabilities(context)
          end

          submit "Submit Intent", class: "btn btn-primary"
        end
      end
    end

    # Intent result display
    def intent_result(result, context) do
      case result do
        {:ok, data} ->
          div class: "intent-success" do
            h3 "Intent Executed Successfully"
            pre class: "result-data" do
              inspect(data)
            end
          end
        {:error, reason} ->
          div class: "intent-error" do
            h3 "Intent Execution Failed"
            p class: "error-message" do
              inspect(reason)
            end
          end
      end
    end

    # Live updates for intent status
    def live_intent_status(intent_id) do
      div id: "intent-status-#{intent_id}", class: "intent-status" do
        # Real-time status updates via WebSocket
        div class: "status-indicator" do
          span class: "status-dot pending" do
            "⏳"
          end
          span class: "status-text" do
            "Processing..."
          end
        end
      end
    end
  end
  ```
  """
  defmacro defweb_intent(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.WebTemple.WebIntent

        use Temple

        # Default implementations
        def intent_form(_context), do: div("Form not implemented")
        def intent_result(_result, _context), do: div("Result display not implemented")
        def live_intent_status(_intent_id), do: div("Status not implemented")

        unquote(body)
      end
    end
  end

  @doc """
  Define a web interface for context visualization and management

  ## Example
  ```elixir
  defweb_context RequestContextWeb do
    @context_module RequestContext

    # Context visualization
    def context_visualizer(context) do
      div class: "context-visualizer" do
        h3 "Request Context"

        div class: "context-fields" do
          div class: "field" do
            span class: "field-label" do
              "User ID:"
            end
            span class: "field-value" do
              context.user_id
            end
          end

          div class: "field" do
            span class: "field-label" do
              "Session ID:"
            end
            span class: "field-value" do
              context.session_id
            end
          end

          div class: "field" do
            span class: "field-label" do
              "Request ID:"
            end
            span class: "field-value" do
              context.request_id
            end
          end

          div class: "field" do
            span class: "field-label" do
              "Trace:"
            end
            div class: "trace-list" do
              for trace_item <- context.trace do
                div class: "trace-item" do
                  trace_item
                end
              end
            end
          end
        end

        # Context propagation visualization
        div class: "context-propagation" do
          h4 "Context Propagation"
          propagation_tree(context)
        end
      end
    end

    # Context editor
    def context_editor(context, changeset) do
      form_for changeset, "/contexts/update", fn f ->
        div class: "context-editor" do
          div class: "form-group" do
            label f, :user_id, "User ID"
            text_input f, :user_id, class: "form-control"
          end

          div class: "form-group" do
            label f, :session_id, "Session ID"
            text_input f, :session_id, class: "form-control"
          end

          div class: "form-group" do
            label f, :trace, "Trace"
            textarea f, :trace, class: "form-control"
          end

          submit "Update Context", class: "btn btn-primary"
        end
      end
    end

    # Live context updates
    def live_context_updates(context_id) do
      div id: "context-updates-#{context_id}", class: "context-updates" do
        # Real-time context changes via WebSocket
        div class: "update-stream" do
          for update <- get_context_updates(context_id) do
            div class: "context-update" do
              span class: "update-timestamp" do
                update.timestamp
              end
              span class: "update-field" do
                "#{update.field}: #{update.old_value} → #{update.new_value}"
              end
            end
          end
        end
      end
    end
  end
  ```
  """
  defmacro defweb_context(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.WebTemple.WebContext

        use Temple

        # Default implementations
        def context_visualizer(_context), do: div("Visualizer not implemented")
        def context_editor(_context, _changeset), do: div("Editor not implemented")
        def live_context_updates(_context_id), do: div("Updates not implemented")

        unquote(body)
      end
    end
  end

  @doc """
  Define a web interface for capability management and visualization

  ## Example
  ```elixir
  defweb_capability FileSystemCapWeb do
    @capability_module FileSystemCap

    # Capability tree visualization
    def capability_tree(capabilities) do
      div class: "capability-tree" do
        h3 "File System Capabilities"

        div class: "tree-root" do
          for cap <- capabilities do
            div class: "capability-node" do
              span class: "capability-name" do
                cap.name
              end

              div class: "capability-details" do
                span class: "capability-pattern" do
                  "Pattern: #{cap.pattern}"
                end

                if cap.grants do
                  div class: "capability-grants" do
                    span "Grants:"
                    for granted <- cap.grants do
                      span class: "granted-cap" do
                        granted
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # Capability editor
    def capability_editor(capability, changeset) do
      form_for changeset, "/capabilities/update", fn f ->
        div class: "capability-editor" do
          div class: "form-group" do
            label f, :name, "Capability Name"
            text_input f, :name, class: "form-control"
          end

          div class: "form-group" do
            label f, :pattern, "Path Pattern (Regex)"
            text_input f, :pattern, class: "form-control"
          end

          div class: "form-group" do
            label f, :grants, "Grants (comma-separated)"
            text_input f, :grants, class: "form-control"
          end

          submit "Update Capability", class: "btn btn-primary"
        end
      end
    end

    # Capability implication visualization
    def capability_implications(capability) do
      div class: "capability-implications" do
        h4 "Capability Implications"

        div class: "implication-graph" do
          for implied <- get_implied_capabilities(capability) do
            div class: "implication-arrow" do
              span class: "from-cap" do
                capability.name
              end
              span class: "arrow" do
                "→"
              end
              span class: "to-cap" do
                implied.name
              end
            end
          end
        end
      end
    end
  end
  ```
  """
  defmacro defweb_capability(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.WebTemple.WebCapability

        use Temple

        # Default implementations
        def capability_tree(_capabilities), do: div("Tree not implemented")
        def capability_editor(_capability, _changeset), do: div("Editor not implemented")
        def capability_implications(_capability), do: div("Implications not implemented")

        unquote(body)
      end
    end
  end

  @doc """
  Define a web interface for actor monitoring and management

  ## Example
  ```elixir
  defweb_actor FileSystemActorWeb do
    @actor_module FileSystemActor

    # Actor dashboard
    def actor_dashboard(actors) do
      div class: "actor-dashboard" do
        h3 "File System Actors"

        div class: "actor-grid" do
          for actor <- actors do
            div class: "actor-card" do
              div class: "actor-header" do
                h4 actor.name
                span class: "actor-status #{actor.status}" do
                  actor.status
                end
              end

              div class: "actor-stats" do
                div class: "stat" do
                  span class: "stat-label" do
                    "Messages Processed:"
                  end
                  span class: "stat-value" do
                    actor.messages_processed
                  end
                end

                div class: "stat" do
                  span class: "stat-label" do
                    "Current State:"
                  end
                  span class: "stat-value" do
                    inspect(actor.current_state)
                  end
                end

                div class: "stat" do
                  span class: "stat-label" do
                    "Capabilities:"
                  end
                  span class: "stat-value" do
                    for cap <- actor.capabilities do
                      span class: "capability-tag" do
                        cap
                      end
                    end
                  end
                end
              end

              div class: "actor-actions" do
                button "View Details", class: "btn btn-sm btn-info"
                button "Restart", class: "btn btn-sm btn-warning"
                button "Stop", class: "btn btn-sm btn-danger"
              end
            end
          end
        end
      end
    end

    # Actor state inspector
    def actor_state_inspector(actor_pid) do
      div class: "actor-state-inspector" do
        h4 "Actor State Inspection"

        div class: "state-tree" do
          # Recursive state visualization
          render_state_tree(get_actor_state(actor_pid))
        end

        div class: "state-actions" do
          button "Refresh State", class: "btn btn-sm btn-primary"
          button "Export State", class: "btn btn-sm btn-secondary"
        end
      end
    end

    # Live actor monitoring
    def live_actor_monitor(actor_pid) do
      div id: "actor-monitor-#{inspect(actor_pid)}", class: "actor-monitor" do
        # Real-time actor metrics via WebSocket
        div class: "metrics-panel" do
          div class: "metric" do
            span class: "metric-label" do
              "CPU Usage:"
            end
            span class: "metric-value" do
              get_actor_cpu_usage(actor_pid)
            end
          end

          div class: "metric" do
            span class: "metric-label" do
              "Memory Usage:"
            end
            span class: "metric-value" do
              get_actor_memory_usage(actor_pid)
            end
          end

          div class: "metric" do
            span class: "metric-label" do
              "Message Queue:"
            end
            span class: "metric-value" do
              get_actor_queue_size(actor_pid)
            end
          end
        end

        div class: "message-log" do
          h5 "Recent Messages"
          for message <- get_recent_messages(actor_pid) do
            div class: "message-entry" do
              span class: "message-timestamp" do
                message.timestamp
              end
              span class: "message-type" do
                message.type
              end
              span class: "message-content" do
                message.content
              end
            end
          end
        end
      end
    end
  end
  ```
  """
  defmacro defweb_actor(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.WebTemple.WebActor

        use Temple

        # Default implementations
        def actor_dashboard(_actors), do: div("Dashboard not implemented")
        def actor_state_inspector(_actor_pid), do: div("Inspector not implemented")
        def live_actor_monitor(_actor_pid), do: div("Monitor not implemented")

        unquote(body)
      end
    end
  end

  @doc """
  Define a web application layout with navigation and routing

  ## Example
  ```elixir
  defweb_app PacketFlowWebApp do
    @app_name "PacketFlow Management Console"

    # Main application layout
    def app_layout(content) do
      html do
        head do
          title @app_name
          meta charset: "utf-8"
          meta name: "viewport", content: "width=device-width, initial-scale=1"
          link rel: "stylesheet", href: "/css/app.css"
          script src: "/js/app.js", defer: true
        end

        body do
          nav class: "navbar navbar-expand-lg navbar-dark bg-dark" do
            div class: "container" do
              a class: "navbar-brand", href: "/" do
                @app_name
              end

              div class: "navbar-nav" do
                a class: "nav-link", href: "/intents" do
                  "Intents"
                end
                a class: "nav-link", href: "/contexts" do
                  "Contexts"
                end
                a class: "nav-link", href: "/capabilities" do
                  "Capabilities"
                end
                a class: "nav-link", href: "/actors" do
                  "Actors"
                end
              end
            end
          end

          main class: "container mt-4" do
            content
          end

          footer class: "footer mt-auto py-3 bg-light" do
            div class: "container text-center" do
              span class: "text-muted" do
                "PacketFlow Web Console v1.0"
              end
            end
          end
        end
      end
    end

    # Error page
    def error_page(error) do
      div class: "error-page" do
        h1 "Error"
        p class: "error-message" do
          error.message
        end
        a href: "/", class: "btn btn-primary" do
          "Return to Dashboard"
        end
      end
    end

    # Loading page
    def loading_page(message \\ "Loading...") do
      div class: "loading-page" do
        div class: "spinner-border", role: "status" do
          span class: "sr-only" do
            message
          end
        end
        p class: "loading-message" do
          message
        end
      end
    end
  end
  ```
  """
  defmacro defweb_app(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.WebTemple.WebApp

        use Temple

        # Default implementations
        def app_layout(_content), do: div("Layout not implemented")
        def error_page(_error), do: div("Error page not implemented")
        def loading_page(_message), do: div("Loading page not implemented")

        unquote(body)
      end
    end
  end
end

defmodule PacketFlow.WebTemple.Components do
  @moduledoc """
  Reusable Temple components for PacketFlow web interfaces
  """

  @doc """
  Create a capability selector component
  """
  def capability_selector(form, field, available_capabilities) do
    select form, field, available_capabilities,
      multiple: true,
      class: "form-control capability-selector"
  end

  @doc """
  Create a context field editor component
  """
  def context_field_editor(form, field_name, field_type, field_value) do
    div class: "context-field-editor" do
      label form, field_name, String.capitalize(field_name)

      case field_type do
        :string ->
          text_input form, field_name, value: field_value, class: "form-control"
        :integer ->
          number_input form, field_name, value: field_value, class: "form-control"
        :boolean ->
          checkbox form, field_name, checked: field_value, class: "form-check-input"
        :list ->
          textarea form, field_name, value: Enum.join(field_value, "\n"), class: "form-control"
        _ ->
          text_input form, field_name, value: field_value, class: "form-control"
      end
    end
  end

  @doc """
  Create a state tree visualization component
  """
  def state_tree(state, depth \\ 0) do
    div class: "state-tree", style: "margin-left: #{depth * 20}px" do
      case state do
        %{} when map_size(state) == 0 ->
          span class: "empty-state" do
            "{}"
          end
        %{} ->
          for {key, value} <- state do
            div class: "state-node" do
              span class: "state-key" do
                "#{key}:"
              end
              state_tree(value, depth + 1)
            end
          end
        list when is_list(list) ->
          div class: "state-list" do
            for item <- list do
              div class: "state-list-item" do
                state_tree(item, depth + 1)
              end
            end
          end
        other ->
          span class: "state-value" do
            inspect(other)
          end
      end
    end
  end

  @doc """
  Create a message log component
  """
  def message_log(messages) do
    div class: "message-log" do
      for message <- messages do
        div class: "message-entry #{message.type}" do
          span class: "message-timestamp" do
            message.timestamp
          end
          span class: "message-type" do
            message.type
          end
          span class: "message-content" do
            message.content
          end
        end
      end
    end
  end

  @doc """
  Create a metrics panel component
  """
  def metrics_panel(metrics) do
    div class: "metrics-panel" do
      for {name, value, unit} <- metrics do
        div class: "metric" do
          span class: "metric-label" do
            "#{name}:"
          end
          span class: "metric-value" do
            "#{value}#{unit}"
          end
        end
      end
    end
  end
end

defmodule PacketFlow.WebTemple.Routing do
  @moduledoc """
  Web routing and navigation for PacketFlow interfaces
  """

  @doc """
  Generate routes for PacketFlow web interfaces
  """
  def generate_routes do
    [
      {"/", PacketFlowWebApp, :dashboard},
      {"/intents", PacketFlowWebApp, :intents},
      {"/intents/new", PacketFlowWebApp, :new_intent},
      {"/intents/:id", PacketFlowWebApp, :show_intent},
      {"/contexts", PacketFlowWebApp, :contexts},
      {"/contexts/:id", PacketFlowWebApp, :show_context},
      {"/capabilities", PacketFlowWebApp, :capabilities},
      {"/capabilities/:id", PacketFlowWebApp, :show_capability},
      {"/actors", PacketFlowWebApp, :actors},
      {"/actors/:id", PacketFlowWebApp, :show_actor},
      {"/actors/:id/state", PacketFlowWebApp, :actor_state},
      {"/actors/:id/monitor", PacketFlowWebApp, :actor_monitor}
    ]
  end

  @doc """
  Create navigation menu for PacketFlow web app
  """
  def navigation_menu(current_path) do
    nav class: "navbar navbar-expand-lg navbar-dark bg-dark" do
      div class: "container" do
        a class: "navbar-brand", href: "/" do
          "PacketFlow"
        end

        div class: "navbar-nav" do
          nav_link("/intents", "Intents", current_path)
          nav_link("/contexts", "Contexts", current_path)
          nav_link("/capabilities", "Capabilities", current_path)
          nav_link("/actors", "Actors", current_path)
        end
      end
    end
  end

  defp nav_link(path, text, current_path) do
    active_class = if path == current_path, do: "active", else: ""
    a class: "nav-link #{active_class}", href: path do
      text
    end
  end
end

defmodule PacketFlow.WebTemple.Reactivity do
  @moduledoc """
  Reactive updates and WebSocket integration for PacketFlow web interfaces
  """

  @doc """
  Set up WebSocket connection for live updates
  """
  def setup_websocket(channel, topic) do
    script do
      """
      const socket = new WebSocket("#{channel}");
      const topic = "#{topic}";

      socket.onopen = function() {
        socket.send(JSON.stringify({
          type: "subscribe",
          topic: topic
        }));
      };

      socket.onmessage = function(event) {
        const data = JSON.parse(event.data);
        handleUpdate(data);
      };

      function handleUpdate(data) {
        // Handle different types of updates
        switch(data.type) {
          case "intent_status":
            updateIntentStatus(data.intent_id, data.status);
            break;
          case "context_update":
            updateContext(data.context_id, data.changes);
            break;
          case "actor_metric":
            updateActorMetrics(data.actor_id, data.metrics);
            break;
        }
      }
      """
    end
  end

  @doc """
  Create a reactive component that updates automatically
  """
  def reactive_component(id, initial_content, update_function) do
    div id: id, class: "reactive-component" do
      initial_content
    end

    script do
      """
      function update#{String.capitalize(id)}(data) {
        const element = document.getElementById("#{id}");
        if (element) {
          element.innerHTML = #{update_function}(data);
        }
      }
      """
    end
  end

  @doc """
  Create a live data stream component
  """
  def live_data_stream(id, data_source, render_function) do
    div id: id, class: "live-data-stream" do
      # Initial content
      render_function.([])
    end

    script do
      """
      // Set up polling for live data
      setInterval(function() {
        fetch("#{data_source}")
          .then(response => response.json())
          .then(data => {
            const element = document.getElementById("#{id}");
            if (element) {
              element.innerHTML = #{render_function}(data);
            }
          });
      }, 1000);
      """
    end
  end
end

# Supporting behaviour definitions
defmodule PacketFlow.WebTemple.WebIntent do
  @callback intent_form(context :: struct()) :: Temple.t()
  @callback intent_result(result :: any(), context :: struct()) :: Temple.t()
  @callback live_intent_status(intent_id :: String.t()) :: Temple.t()
end

defmodule PacketFlow.WebTemple.WebContext do
  @callback context_visualizer(context :: struct()) :: Temple.t()
  @callback context_editor(context :: struct(), changeset :: any()) :: Temple.t()
  @callback live_context_updates(context_id :: String.t()) :: Temple.t()
end

defmodule PacketFlow.WebTemple.WebCapability do
  @callback capability_tree(capabilities :: list()) :: Temple.t()
  @callback capability_editor(capability :: any(), changeset :: any()) :: Temple.t()
  @callback capability_implications(capability :: any()) :: Temple.t()
end

defmodule PacketFlow.WebTemple.WebActor do
  @callback actor_dashboard(actors :: list()) :: Temple.t()
  @callback actor_state_inspector(actor_pid :: pid()) :: Temple.t()
  @callback live_actor_monitor(actor_pid :: pid()) :: Temple.t()
end

defmodule PacketFlow.WebTemple.WebApp do
  @callback app_layout(content :: Temple.t()) :: Temple.t()
  @callback error_page(error :: any()) :: Temple.t()
  @callback loading_page(message :: String.t()) :: Temple.t()
end
