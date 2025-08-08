# Web Framework Guide

## What is the Web Framework?

The **Web Framework** is PacketFlow's full-stack web application layer. It builds on top of the Temporal substrate to provide Temple-based UI components, RESTful APIs with capability checking, real-time WebSocket support, and progressive web application features.

Think of it as the "user interface layer" that allows you to build complete web applications with security, real-time updates, and modern UI components.

## Core Concepts

### Full-Stack Web Development

The Web Framework provides:
- **Temple-based UI components** with capability-aware rendering
- **RESTful API endpoints** with automatic capability checking
- **Real-time WebSocket support** for live updates
- **Progressive web application** features
- **Server-side rendering** with client-side hydration

In PacketFlow, web development is enhanced with:
- **Capability-aware UI rendering**
- **Real-time context propagation**
- **Temporal validation in web interfaces**
- **Secure API endpoints with automatic authorization**

## Key Components

### 1. **Web Components** (Temple-based UI)
Web components provide the user interface using Temple for server-side rendering.

```elixir
defmodule FileSystem.Web.Components do
  use PacketFlow.Web

  # Define a file browser component
  defcomponent FileBrowser do
    @template """
    <div class="file-browser">
      <h2>File Browser</h2>
      
      <div class="toolbar">
        <button class="btn btn-primary" onclick="uploadFile()">
          Upload File
        </button>
        <button class="btn btn-secondary" onclick="createFolder()">
          New Folder
        </button>
      </div>
      
      <div class="file-list">
        <%= for file <- @files do %>
          <div class="file-item">
            <span class="file-name"><%= file.name %></span>
            <span class="file-size"><%= format_size(file.size) %></span>
            <div class="file-actions">
              <%= if has_capability?(@context, FileCap.read(file.path)) do %>
                <button onclick="downloadFile('<%= file.path %>')">Download</button>
              <% end %>
              <%= if has_capability?(@context, FileCap.write(file.path)) do %>
                <button onclick="editFile('<%= file.path %>')">Edit</button>
              <% end %>
              <%= if has_capability?(@context, FileCap.delete(file.path)) do %>
                <button onclick="deleteFile('<%= file.path %>')">Delete</button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """

    def render(assigns) do
      # Validate temporal constraints for web rendering
      case validate_temporal_constraints(assigns.context) do
        :ok ->
          # Render the component
          Temple.render(@template, assigns)
        
        {:error, reason} ->
          # Show temporal constraint violation
          render_temporal_error(reason)
      end
    end

    defp validate_temporal_constraints(context) do
      current_time = System.system_time(:millisecond)
      
      # Check if current time allows file operations
      if FileSystem.TemporalLogic.business_hours?(current_time) do
        :ok
      else
        {:error, :outside_business_hours}
      end
    end

    defp render_temporal_error(reason) do
      """
      <div class="temporal-error">
        <h3>Service Temporarily Unavailable</h3>
        <p>File operations are only available during business hours (9 AM - 5 PM).</p>
        <p>Please try again during business hours.</p>
      </div>
      """
    end
  end

  # Define a file editor component
  defcomponent FileEditor do
    @template """
    <div class="file-editor">
      <div class="editor-header">
        <h3>Editing: <%= @file_path %></h3>
        <div class="editor-actions">
          <button class="btn btn-primary" onclick="saveFile()">Save</button>
          <button class="btn btn-secondary" onclick="cancelEdit()">Cancel</button>
        </div>
      </div>
      
      <div class="editor-content">
        <textarea id="file-content" class="code-editor">
          <%= @file_content %>
        </textarea>
      </div>
      
      <div class="editor-status">
        <span class="status-indicator <%= @status %>">
          <%= @status_message %>
        </span>
        <span class="last-saved">
          Last saved: <%= @last_saved %>
        </span>
      </div>
    </div>
    """

    def render(assigns) do
      # Check if user has write capability for this file
      if has_capability?(assigns.context, FileCap.write(assigns.file_path)) do
        Temple.render(@template, assigns)
      else
        render_access_denied()
      end
    end

    defp render_access_denied do
      """
      <div class="access-denied">
        <h3>Access Denied</h3>
        <p>You don't have permission to edit this file.</p>
      </div>
      """
    end
  end
end
```

### 2. **Web Router** (RESTful API)
The web router provides RESTful API endpoints with automatic capability checking.

```elixir
defmodule FileSystem.Web.Router do
  use PacketFlow.Web

  # Define API routes with capability checking
  defrouter FileSystemAPI do
    # GET /api/files - List files
    get "/api/files" do
      # Check read capability
      if has_capability?(conn, FileCap.read("/")) do
        # Get files from actor
        {:ok, files} = PacketFlow.Actor.send_message(:file_actor, {:list_files, conn.assigns.context})
        
        json(conn, %{
          files: files,
          timestamp: System.system_time()
        })
      else
        conn
        |> put_status(403)
        |> json(%{error: "Insufficient capabilities"})
      end
    end

    # GET /api/files/:path - Get file content
    get "/api/files/*path" do
      path = Enum.join(path, "/")
      
      # Check read capability for specific path
      if has_capability?(conn, FileCap.read(path)) do
        # Get file content from actor
        case PacketFlow.Actor.send_message(:file_actor, {:read_file, path, conn.assigns.context}) do
          {:ok, content} ->
            json(conn, %{
              path: path,
              content: content,
              timestamp: System.system_time()
            })
          
          {:error, reason} ->
            conn
            |> put_status(404)
            |> json(%{error: "File not found"})
        end
      else
        conn
        |> put_status(403)
        |> json(%{error: "Insufficient capabilities"})
      end
    end

    # POST /api/files/:path - Create or update file
    post "/api/files/*path" do
      path = Enum.join(path, "/")
      content = conn.body_params["content"]
      
      # Check write capability for specific path
      if has_capability?(conn, FileCap.write(path)) do
        # Validate temporal constraints
        case validate_temporal_constraints(conn.assigns.context) do
          :ok ->
            # Write file through actor
            case PacketFlow.Actor.send_message(:file_actor, {:write_file, path, content, conn.assigns.context}) do
              {:ok, _} ->
                json(conn, %{
                  path: path,
                  status: "created",
                  timestamp: System.system_time()
                })
              
              {:error, reason} ->
                conn
                |> put_status(500)
                |> json(%{error: "Failed to write file"})
            end
          
          {:error, reason} ->
            conn
            |> put_status(503)
            |> json(%{error: "Service unavailable due to temporal constraints"})
        end
      else
        conn
        |> put_status(403)
        |> json(%{error: "Insufficient capabilities"})
      end
    end

    # DELETE /api/files/:path - Delete file
    delete "/api/files/*path" do
      path = Enum.join(path, "/")
      
      # Check delete capability for specific path
      if has_capability?(conn, FileCap.delete(path)) do
        # Validate temporal constraints
        case validate_temporal_constraints(conn.assigns.context) do
          :ok ->
            # Delete file through actor
            case PacketFlow.Actor.send_message(:file_actor, {:delete_file, path, conn.assigns.context}) do
              {:ok, _} ->
                json(conn, %{
                  path: path,
                  status: "deleted",
                  timestamp: System.system_time()
                })
              
              {:error, reason} ->
                conn
                |> put_status(500)
                |> json(%{error: "Failed to delete file"})
            end
          
          {:error, reason} ->
            conn
            |> put_status(503)
            |> json(%{error: "Service unavailable due to temporal constraints"})
        end
      else
        conn
        |> put_status(403)
        |> json(%{error: "Insufficient capabilities"})
      end
    end

    # WebSocket endpoint for real-time updates
    websocket "/api/ws" do
      # Handle WebSocket connection
      case handle_websocket_connection(conn) do
        {:ok, socket} ->
          # Subscribe to file system events
          PacketFlow.Stream.subscribe_to_events(:file_stream, socket)
          
          # Send initial state
          send_initial_state(socket)
          
          {:ok, socket}
        
        {:error, reason} ->
          {:error, reason}
      end
    end

    # Private helper functions
    defp validate_temporal_constraints(context) do
      current_time = System.system_time(:millisecond)
      
      # Check business hours constraint
      if FileSystem.TemporalLogic.business_hours?(current_time) do
        :ok
      else
        {:error, :outside_business_hours}
      end
    end

    defp handle_websocket_connection(conn) do
      # Validate user session and capabilities
      case validate_websocket_session(conn) do
        {:ok, context} ->
          socket = %WebSocket{
            conn: conn,
            context: context,
            subscriptions: []
          }
          {:ok, socket}
        
        {:error, reason} ->
          {:error, reason}
      end
    end

    defp validate_websocket_session(conn) do
      # Extract user session from connection
      session = conn.assigns[:session]
      
      if session and session.user_id do
        # Get user capabilities
        capabilities = get_user_capabilities(session.user_id)
        context = %FileSystem.Contexts.FileContext{
          user_id: session.user_id,
          session_id: session.id,
          capabilities: capabilities
        }
        {:ok, context}
      else
        {:error, :invalid_session}
      end
    end

    defp send_initial_state(socket) do
      # Send current file system state to WebSocket
      {:ok, files} = PacketFlow.Actor.send_message(:file_actor, {:list_files, socket.context})
      
      message = %{
        type: "initial_state",
        files: files,
        timestamp: System.system_time()
      }
      
      WebSocket.send(socket, message)
    end
  end
end
```

### 3. **Web Middleware** (Request Processing)
Web middleware handles request processing, authentication, and capability checking.

```elixir
defmodule FileSystem.Web.Middleware do
  use PacketFlow.Web

  # Define authentication middleware
  defmiddleware Authentication do
    def call(conn, _opts) do
      # Extract authentication token
      token = get_auth_token(conn)
      
      case validate_token(token) do
        {:ok, user_id} ->
          # Get user capabilities
          capabilities = get_user_capabilities(user_id)
          
          # Create context
          context = %FileSystem.Contexts.FileContext{
            user_id: user_id,
            session_id: generate_session_id(),
            capabilities: capabilities,
            timestamp: System.system_time()
          }
          
          # Add context to connection
          conn
          |> assign(:context, context)
          |> assign(:user_id, user_id)
        
        {:error, reason} ->
          conn
          |> put_status(401)
          |> json(%{error: "Authentication failed"})
          |> halt()
      end
    end

    defp get_auth_token(conn) do
      # Extract token from Authorization header
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] -> token
        _ -> nil
      end
    end

    defp validate_token(token) do
      # Validate JWT token
      case JWT.verify(token, secret_key()) do
        {:ok, claims} ->
          user_id = claims["user_id"]
          {:ok, user_id}
        
        {:error, _reason} ->
          {:error, :invalid_token}
      end
    end

    defp get_user_capabilities(user_id) do
      # Get user capabilities from database
      case get_user_from_database(user_id) do
        {:ok, user} ->
          user.capabilities
        
        {:error, _reason} ->
          []
      end
    end
  end

  # Define capability checking middleware
  defmiddleware CapabilityCheck do
    def call(conn, required_capabilities) do
      context = conn.assigns[:context]
      
      # Check if user has required capabilities
      if has_all_capabilities?(context, required_capabilities) do
        conn
      else
        conn
        |> put_status(403)
        |> json(%{error: "Insufficient capabilities"})
        |> halt()
      end
    end

    defp has_all_capabilities?(context, required_capabilities) do
      user_capabilities = context.capabilities
      
      Enum.all?(required_capabilities, fn required_cap ->
        Enum.any?(user_capabilities, fn user_cap ->
          capability_implies?(user_cap, required_cap)
        end)
      end)
    end
  end

  # Define temporal validation middleware
  defmiddleware TemporalValidation do
    def call(conn, _opts) do
      context = conn.assigns[:context]
      
      # Validate temporal constraints
      case validate_temporal_constraints(context) do
        :ok ->
          conn
        
        {:error, reason} ->
          conn
          |> put_status(503)
          |> json(%{error: "Service unavailable due to temporal constraints"})
          |> halt()
      end
    end

    defp validate_temporal_constraints(context) do
      current_time = System.system_time(:millisecond)
      
      # Check business hours constraint
      if FileSystem.TemporalLogic.business_hours?(current_time) do
        :ok
      else
        {:error, :outside_business_hours}
      end
    end
  end
end
```

## How It Works

### 1. **Component Rendering with Capabilities**
Components render based on user capabilities:

```elixir
# Render file browser component
context = FileSystem.Contexts.FileContext.new("user123", "session456", [
  FileCap.read("/"),
  FileCap.write("/user/"),
  FileCap.delete("/user/")
])

# Component automatically shows/hides buttons based on capabilities
component = FileSystem.Web.Components.FileBrowser.render(%{
  files: files,
  context: context
})

# Only shows download button for all files
# Only shows edit button for files in /user/
# Only shows delete button for files in /user/
```

### 2. **API Endpoint with Automatic Security**
API endpoints automatically check capabilities:

```elixir
# GET /api/files/user/document.txt
# User has: [FileCap.read("/"), FileCap.write("/user/")]
# Request requires: FileCap.read("/user/document.txt")

# Automatic capability checking:
# FileCap.read("/") implies FileCap.read("/user/document.txt") ✓
# Request proceeds

# If user only had: [FileCap.read("/user/")]
# FileCap.read("/user/") does not imply FileCap.read("/user/document.txt") ✗
# Request returns 403 Forbidden
```

### 3. **Real-time Updates via WebSocket**
WebSocket connections provide real-time updates:

```elixir
# User connects to WebSocket
# System subscribes to file system events

# When file is created:
PacketFlow.Stream.emit_event(%FileCreatedEvent{
  path: "/user/newfile.txt",
  user_id: "user123",
  timestamp: System.system_time()
})

# WebSocket automatically receives and broadcasts:
{
  "type": "file_created",
  "path": "/user/newfile.txt",
  "user_id": "user123",
  "timestamp": 1640995200000
}
```

### 4. **Temporal Validation in Web Interface**
Web interfaces respect temporal constraints:

```elixir
# User tries to edit file at 8 PM (outside business hours)
# Temporal validation middleware checks:
FileSystem.TemporalLogic.business_hours?(current_time)
# => false

# API returns 503 Service Unavailable with message:
{
  "error": "Service unavailable due to temporal constraints"
}

# UI shows appropriate message to user
```

## Advanced Features

### Progressive Web Application

```elixir
defmodule FileSystem.Web.PWA do
  use PacketFlow.Web

  # Define PWA manifest
  defmanifest FileSystemPWA do
    @manifest %{
      name: "File System Manager",
      short_name: "FileSys",
      description: "Secure file system management",
      start_url: "/",
      display: "standalone",
      background_color: "#ffffff",
      theme_color: "#000000",
      icons: [
        %{src: "/icons/icon-192.png", sizes: "192x192", type: "image/png"},
        %{src: "/icons/icon-512.png", sizes: "512x512", type: "image/png"}
      ]
    }

    def get_manifest do
      @manifest
    end
  end

  # Define service worker for offline functionality
  defservice_worker FileSystemSW do
    @cache_name "file-system-v1"
    @cache_urls [
      "/",
      "/static/css/app.css",
      "/static/js/app.js",
      "/api/files"
    ]

    def install(event) do
      # Cache essential resources
      caches.open(@cache_name)
      |> then(fn cache ->
        cache.addAll(@cache_urls)
      end)
    end

    def fetch(event) do
      # Handle offline requests
      case caches.match(event.request) do
        {:ok, response} ->
          response
        
        {:error, _} ->
          # Try network, fallback to cached version
          fetch_from_network(event.request)
      end
    end
  end
end
```

### Real-time Collaboration

```elixir
defmodule FileSystem.Web.Collaboration do
  use PacketFlow.Web

  # Define collaborative editing
  defcomponent CollaborativeEditor do
    @template """
    <div class="collaborative-editor">
      <div class="editor-header">
        <h3>Editing: <%= @file_path %></h3>
        <div class="collaborators">
          <%= for user <- @collaborators do %>
            <span class="collaborator" style="color: <%= user.color %>">
              <%= user.name %>
            </span>
          <% end %>
        </div>
      </div>
      
      <div class="editor-content">
        <div id="editor" class="code-editor" data-file="<%= @file_path %>">
          <%= @file_content %>
        </div>
      </div>
      
      <div class="editor-status">
        <span class="connection-status <%= @connection_status %>">
          <%= @connection_status %>
        </span>
        <span class="last-saved">
          Last saved: <%= @last_saved %>
        </span>
      </div>
    </div>
    """

    def render(assigns) do
      # Check if user has write capability
      if has_capability?(assigns.context, FileCap.write(assigns.file_path)) do
        # Get current collaborators
        collaborators = get_collaborators(assigns.file_path)
        
        Temple.render(@template, %{assigns | collaborators: collaborators})
      else
        render_access_denied()
      end
    end

    defp get_collaborators(file_path) do
      # Get users currently editing this file
      case PacketFlow.Actor.send_message(:collaboration_actor, {:get_collaborators, file_path}) do
        {:ok, users} -> users
        {:error, _} -> []
      end
    end
  end

  # Define WebSocket handler for real-time collaboration
  defwebsocket_handler CollaborationHandler do
    def handle_message(%{"type" => "join_file", "file_path" => file_path}, socket) do
      # User joins collaborative editing session
      case join_collaboration_session(socket.context.user_id, file_path) do
        {:ok, session} ->
          # Notify other users
          broadcast_to_collaborators(file_path, %{
            type: "user_joined",
            user_id: socket.context.user_id,
            user_name: socket.context.user_name
          })
          
          {:ok, %{socket | session: session}}
        
        {:error, reason} ->
          {:error, reason}
      end
    end

    def handle_message(%{"type" => "edit", "file_path" => file_path, "changes" => changes}, socket) do
      # Handle collaborative edit
      case apply_collaborative_edit(file_path, changes, socket.context) do
        {:ok, _} ->
          # Broadcast changes to other collaborators
          broadcast_to_collaborators(file_path, %{
            type: "edit",
            user_id: socket.context.user_id,
            changes: changes,
            timestamp: System.system_time()
          })
          
          {:ok, socket}
        
        {:error, reason} ->
          {:error, reason}
      end
    end

    def handle_message(%{"type" => "leave_file", "file_path" => file_path}, socket) do
      # User leaves collaborative editing session
      leave_collaboration_session(socket.context.user_id, file_path)
      
      # Notify other users
      broadcast_to_collaborators(file_path, %{
        type: "user_left",
        user_id: socket.context.user_id
      })
      
      {:ok, socket}
    end
  end
end
```

### Advanced UI Components

```elixir
defmodule FileSystem.Web.AdvancedComponents do
  use PacketFlow.Web

  # Define drag-and-drop file upload
  defcomponent FileUpload do
    @template """
    <div class="file-upload" id="file-upload">
      <div class="upload-area" 
           ondrop="handleDrop(event)" 
           ondragover="handleDragOver(event)"
           ondragleave="handleDragLeave(event)">
        <div class="upload-icon">📁</div>
        <div class="upload-text">
          Drag and drop files here or click to browse
        </div>
        <input type="file" id="file-input" style="display: none" onchange="handleFileSelect(event)">
      </div>
      
      <div class="upload-progress" style="display: <%= if @uploading, do: 'block', else: 'none' %>">
        <div class="progress-bar">
          <div class="progress-fill" style="width: <%= @progress %>%"></div>
        </div>
        <div class="progress-text">
          Uploading: <%= @current_file %> (<%= @progress %>%)
        </div>
      </div>
      
      <div class="upload-list">
        <%= for file <- @uploaded_files do %>
          <div class="uploaded-file">
            <span class="file-name"><%= file.name %></span>
            <span class="file-size"><%= format_size(file.size) %></span>
            <span class="upload-status <%= file.status %>">
              <%= file.status %>
            </span>
          </div>
        <% end %>
      </div>
    </div>
    """

    def render(assigns) do
      # Check if user has upload capability
      if has_capability?(assigns.context, FileCap.write("/uploads/")) do
        Temple.render(@template, assigns)
      else
        render_upload_disabled()
      end
    end

    defp render_upload_disabled do
      """
      <div class="upload-disabled">
        <p>File upload is not available for your account.</p>
        <p>Please contact your administrator for upload permissions.</p>
      </div>
      """
    end
  end

  # Define file preview component
  defcomponent FilePreview do
    @template """
    <div class="file-preview">
      <div class="preview-header">
        <h3><%= @file_name %></h3>
        <div class="preview-actions">
          <button onclick="downloadFile('<%= @file_path %>')">Download</button>
          <button onclick="shareFile('<%= @file_path %>')">Share</button>
        </div>
      </div>
      
      <div class="preview-content">
        <%= case @file_type do %>
          <% "image" -> %>
            <img src="/api/files/<%= @file_path %>" alt="<%= @file_name %>">
          <% "text" -> %>
            <pre class="text-preview"><%= @file_content %></pre>
          <% "pdf" -> %>
            <iframe src="/api/files/<%= @file_path %>" width="100%" height="600"></iframe>
          <% _ -> %>
            <div class="unsupported-format">
              <p>Preview not available for this file type.</p>
              <button onclick="downloadFile('<%= @file_path %>')">Download to view</button>
            </div>
        <% end %>
      </div>
    </div>
    """

    def render(assigns) do
      # Check if user has read capability
      if has_capability?(assigns.context, FileCap.read(assigns.file_path)) do
        # Determine file type for preview
        file_type = determine_file_type(assigns.file_path)
        
        Temple.render(@template, %{assigns | file_type: file_type})
      else
        render_access_denied()
      end
    end

    defp determine_file_type(file_path) do
      extension = Path.extname(file_path) |> String.downcase()
      
      case extension do
        ".jpg" -> "image"
        ".jpeg" -> "image"
        ".png" -> "image"
        ".gif" -> "image"
        ".txt" -> "text"
        ".md" -> "text"
        ".pdf" -> "pdf"
        _ -> "unknown"
      end
    end
  end
end
```

## Integration with Other Substrates

The Web Framework integrates with other substrates:

- **ADT Substrate**: Web components render ADT contexts and intents
- **Actor Substrate**: Web requests are processed by actors
- **Stream Substrate**: WebSocket connections provide real-time updates
- **Temporal Substrate**: Web interfaces respect temporal constraints

## Best Practices

### 1. **Design Secure Web Components**
Always check capabilities in components:

```elixir
# Good: Check capabilities before rendering
def render(assigns) do
  if has_capability?(assigns.context, FileCap.read(assigns.file_path)) do
    Temple.render(@template, assigns)
  else
    render_access_denied()
  end
end

# Avoid: Rendering without capability checks
def render(assigns) do
  Temple.render(@template, assigns)  # Security risk!
end
```

### 2. **Use Appropriate HTTP Status Codes**
Return meaningful status codes:

```elixir
# 200 OK - Request succeeded
json(conn, %{files: files})

# 201 Created - Resource created
conn
|> put_status(201)
|> json(%{file: file, status: "created"})

# 403 Forbidden - Insufficient capabilities
conn
|> put_status(403)
|> json(%{error: "Insufficient capabilities"})

# 503 Service Unavailable - Temporal constraints
conn
|> put_status(503)
|> json(%{error: "Service unavailable due to temporal constraints"})
```

### 3. **Handle Real-time Updates Efficiently**
Use WebSocket for real-time updates:

```elixir
# Subscribe to relevant events
def handle_websocket_connection(conn) do
  # Subscribe to file system events for this user
  user_id = conn.assigns.user_id
  
  PacketFlow.Stream.subscribe_to_events(:file_stream, self(), %{
    user_id: user_id,
    filters: ["file_created", "file_updated", "file_deleted"]
  })
  
  {:ok, conn}
end

# Handle real-time events
def handle_info({:stream_event, event}, socket) do
  # Send event to WebSocket client
  WebSocket.send(socket, event)
  {:noreply, socket}
end
```

### 4. **Implement Progressive Enhancement**
Build for offline functionality:

```elixir
# Service worker for offline support
def install(event) do
  # Cache essential resources
  caches.open("file-system-v1")
  |> then(fn cache ->
    cache.addAll([
      "/",
      "/static/css/app.css",
      "/static/js/app.js"
    ])
  end)
end

def fetch(event) do
  # Try network first, fallback to cache
  case fetch_from_network(event.request) do
    {:ok, response} -> response
    {:error, _} -> fetch_from_cache(event.request)
  end
end
```

## Common Patterns

### 1. **CRUD Web Interface**
```elixir
defmodule FileSystem.Web.CRUD do
  use PacketFlow.Web

  # List resources
  get "/api/files" do
    if has_capability?(conn, FileCap.read("/")) do
      {:ok, files} = PacketFlow.Actor.send_message(:file_actor, {:list_files, conn.assigns.context})
      json(conn, %{files: files})
    else
      conn |> put_status(403) |> json(%{error: "Insufficient capabilities"})
    end
  end

  # Create resource
  post "/api/files" do
    if has_capability?(conn, FileCap.write("/")) do
      case PacketFlow.Actor.send_message(:file_actor, {:create_file, conn.body_params, conn.assigns.context}) do
        {:ok, file} -> conn |> put_status(201) |> json(%{file: file})
        {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
      end
    else
      conn |> put_status(403) |> json(%{error: "Insufficient capabilities"})
    end
  end

  # Update resource
  put "/api/files/:id" do
    if has_capability?(conn, FileCap.write("/")) do
      case PacketFlow.Actor.send_message(:file_actor, {:update_file, id, conn.body_params, conn.assigns.context}) do
        {:ok, file} -> json(conn, %{file: file})
        {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
      end
    else
      conn |> put_status(403) |> json(%{error: "Insufficient capabilities"})
    end
  end

  # Delete resource
  delete "/api/files/:id" do
    if has_capability?(conn, FileCap.delete("/")) do
      case PacketFlow.Actor.send_message(:file_actor, {:delete_file, id, conn.assigns.context}) do
        {:ok, _} -> conn |> put_status(204)
        {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
      end
    else
      conn |> put_status(403) |> json(%{error: "Insufficient capabilities"})
    end
  end
end
```

### 2. **Real-time Dashboard**
```elixir
defmodule FileSystem.Web.Dashboard do
  use PacketFlow.Web

  defcomponent SystemDashboard do
    @template """
    <div class="dashboard">
      <div class="dashboard-header">
        <h2>System Dashboard</h2>
        <div class="dashboard-actions">
          <button onclick="refreshDashboard()">Refresh</button>
        </div>
      </div>
      
      <div class="dashboard-grid">
        <div class="dashboard-card">
          <h3>File Operations</h3>
          <div class="metric">
            <span class="metric-value"><%= @metrics.reads %></span>
            <span class="metric-label">Reads</span>
          </div>
          <div class="metric">
            <span class="metric-value"><%= @metrics.writes %></span>
            <span class="metric-label">Writes</span>
          </div>
        </div>
        
        <div class="dashboard-card">
          <h3>Active Users</h3>
          <div class="metric">
            <span class="metric-value"><%= @metrics.active_users %></span>
            <span class="metric-label">Users</span>
          </div>
        </div>
        
        <div class="dashboard-card">
          <h3>System Status</h3>
          <div class="status-indicator <%= @system_status %>">
            <%= @system_status %>
          </div>
        </div>
      </div>
      
      <div class="recent-activity">
        <h3>Recent Activity</h3>
        <div class="activity-list">
          <%= for activity <- @recent_activities do %>
            <div class="activity-item">
              <span class="activity-time"><%= format_time(activity.timestamp) %></span>
              <span class="activity-user"><%= activity.user_id %></span>
              <span class="activity-action"><%= activity.action %></span>
              <span class="activity-target"><%= activity.target %></span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """

    def render(assigns) do
      # Check if user has admin capability
      if has_capability?(assigns.context, FileCap.admin("/")) do
        Temple.render(@template, assigns)
      else
        render_access_denied()
      end
    end
  end
end
```

### 3. **File Upload with Progress**
```elixir
defmodule FileSystem.Web.FileUpload do
  use PacketFlow.Web

  defcomponent UploadProgress do
    @template """
    <div class="upload-progress">
      <div class="upload-header">
        <h3>Uploading Files</h3>
        <button onclick="cancelUpload()">Cancel</button>
      </div>
      
      <div class="upload-list">
        <%= for file <- @uploading_files do %>
          <div class="upload-item">
            <div class="file-info">
              <span class="file-name"><%= file.name %></span>
              <span class="file-size"><%= format_size(file.size) %></span>
            </div>
            
            <div class="progress-bar">
              <div class="progress-fill" style="width: <%= file.progress %>%"></div>
            </div>
            
            <div class="upload-status">
              <span class="status-text"><%= file.status %></span>
              <span class="progress-text"><%= file.progress %>%</span>
            </div>
          </div>
        <% end %>
      </div>
      
      <div class="upload-summary">
        <span class="total-files"><%= length(@uploading_files) %> files</span>
        <span class="total-progress"><%= calculate_total_progress(@uploading_files) %>% complete</span>
      </div>
    </div>
    """

    def render(assigns) do
      Temple.render(@template, assigns)
    end

    defp calculate_total_progress(files) do
      total_progress = Enum.reduce(files, 0, fn file, acc ->
        acc + file.progress
      end)
      
      div(total_progress, length(files))
    end
  end
end
```

## Testing Your Web Components

```elixir
defmodule FileSystem.Web.Test do
  use ExUnit.Case
  use PacketFlow.Testing

  test "web component renders with correct capabilities" do
    # Test with read capability
    context_with_read = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.read("/")])
    
    result = FileSystem.Web.Components.FileBrowser.render(%{
      files: [%{name: "test.txt", path: "/test.txt", size: 100}],
      context: context_with_read
    })
    
    # Should show download button but not edit/delete buttons
    assert String.contains?(result, "downloadFile")
    refute String.contains?(result, "editFile")
    refute String.contains?(result, "deleteFile")
  end

  test "API endpoint checks capabilities correctly" do
    # Test API with insufficient capabilities
    conn = %Plug.Conn{
      assigns: %{context: FileSystem.Contexts.FileContext.new("user123", "session456", [])}
    }
    
    result = FileSystem.Web.Router.handle_get_file(conn, ["user", "document.txt"])
    
    assert result.status == 403
    assert result.resp_body =~ "Insufficient capabilities"
  end

  test "WebSocket handles real-time updates" do
    # Start WebSocket connection
    {:ok, socket} = WebSocket.connect("/api/ws")
    
    # Subscribe to file events
    WebSocket.send(socket, %{type: "subscribe", events: ["file_created"]})
    
    # Simulate file creation
    PacketFlow.Stream.emit_event(%FileCreatedEvent{
      path: "/test.txt",
      user_id: "user123"
    })
    
    # Should receive WebSocket message
    assert_receive {:websocket_message, %{type: "file_created", path: "/test.txt"}}
  end
end
```

## Next Steps

Now that you understand the Web Framework, you can:

1. **Build Complete Applications**: Create full-stack web applications
2. **Add Real-time Features**: Implement live collaboration and updates
3. **Scale Your Web App**: Distribute web components across nodes
4. **Enhance User Experience**: Add progressive web app features

The Web Framework is your full-stack foundation - it makes your system accessible to users through modern web interfaces!
