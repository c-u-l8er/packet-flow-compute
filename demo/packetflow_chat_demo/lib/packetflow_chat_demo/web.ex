defmodule PacketflowChatDemo.Web do
  @moduledoc """
  Web interface for the PacketFlow LLM Chat Demo
  """

  # Cowboy HTTP handler
  @behaviour :cowboy_handler

  # ============================================================================
  # COWBOY HANDLER CALLBACKS
  # ============================================================================

  def init(req, state) do
    {:cowboy_rest, req, state}
  end

  def content_types_provided(req, state) do
    {[
      {"text/html", :to_html},
      {"application/json", :to_json}
    ], req, state}
  end

  def content_types_accepted(req, state) do
    {[
      {"application/json", :from_json}
    ], req, state}
  end

  def allowed_methods(req, state) do
    {["GET", "POST"], req, state}
  end

  def to_html(req, state) do
    html = render_chat_interface()
    {html, req, state}
  end

  def to_json(req, state) do
    handle_api_request(req, state)
  end

  def from_json(req, state) do
    handle_api_request(req, state)
  end

  def handle_api_request(req, state) do
    method = :cowboy_req.method(req)
    path = :cowboy_req.path(req)

    case {method, path} do
      {"POST", "/api/chat"} ->
        handle_chat_request(req, state)
      {"POST", "/api/history"} ->
        handle_history_request(req, state)
      {"GET", "/api/sessions"} ->
        handle_sessions_request(req, state)
      _ ->
        req = :cowboy_req.reply(404, %{"content-type" => "application/json"}, "{\"error\": \"Not Found\"}", req)
        {:stop, req, state}
    end
  end

  def handle_chat_request(req, state) do
    case read_body(req) do
      {:ok, body, req} ->
        case Jason.decode(body) do
          {:ok, %{"message" => message, "user_id" => user_id, "session_id" => session_id}} ->
            case PacketflowChatDemo.ChatReactor.send_message(user_id, message, session_id) do
              {:ok, response} ->
                req = :cowboy_req.reply(200, %{"content-type" => "application/json"}, Jason.encode!(response), req)
                {:stop, req, state}
              {:error, error} ->
                req = :cowboy_req.reply(400, %{"content-type" => "application/json"}, Jason.encode!(error), req)
                {:stop, req, state}
            end
          {:error, _} ->
            req = :cowboy_req.reply(400, %{"content-type" => "application/json"}, Jason.encode!(%{error: "Invalid JSON"}), req)
            {:stop, req, state}
        end
      {:error, :timeout} ->
        req = :cowboy_req.reply(408, %{"content-type" => "application/json"}, Jason.encode!(%{error: "Request timeout"}), req)
        {:stop, req, state}
    end
  end

  def handle_history_request(req, state) do
    case read_body(req) do
      {:ok, body, req} ->
        case Jason.decode(body) do
          {:ok, %{"user_id" => user_id, "session_id" => session_id}} ->
            case PacketflowChatDemo.ChatReactor.get_history(user_id, session_id) do
              {:ok, history} ->
                req = :cowboy_req.reply(200, %{"content-type" => "application/json"}, Jason.encode!(history), req)
                {:stop, req, state}
              {:error, error} ->
                req = :cowboy_req.reply(400, %{"content-type" => "application/json"}, Jason.encode!(error), req)
                {:stop, req, state}
            end
          {:error, _} ->
            req = :cowboy_req.reply(400, %{"content-type" => "application/json"}, Jason.encode!(%{error: "Invalid JSON"}), req)
            {:stop, req, state}
        end
      {:error, :timeout} ->
        req = :cowboy_req.reply(408, %{"content-type" => "application/json"}, Jason.encode!(%{error: "Request timeout"}), req)
        {:stop, req, state}
    end
  end

  def handle_sessions_request(req, state) do
    case PacketflowChatDemo.ChatReactor.get_sessions() do
      {:ok, sessions} ->
        req = :cowboy_req.reply(200, %{"content-type" => "application/json"}, Jason.encode!(sessions), req)
        {:stop, req, state}
      {:error, error} ->
        req = :cowboy_req.reply(400, %{"content-type" => "application/json"}, Jason.encode!(error), req)
        {:stop, req, state}
    end
  end

  def read_body(req) do
    case :cowboy_req.read_body(req) do
      {:ok, body, req} -> {:ok, body, req}
      {:more, body, req} -> read_body(req)
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # TEMPLATE RENDERING
  # ============================================================================

  def render_chat_interface do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>PacketFlow LLM Chat Demo</title>
      <script src="https://cdn.tailwindcss.com"></script>
      <style>
        .chat-container {
          height: calc(100vh - 200px);
        }
        .message-bubble {
          max-width: 80%;
          word-wrap: break-word;
        }
        .typing-indicator {
          display: none;
        }
        .typing-indicator.show {
          display: block;
        }
      </style>
    </head>
    <body class="bg-gray-100 min-h-screen">
      <div class="container mx-auto px-4 py-8">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-800 mb-2">PacketFlow LLM Chat Demo</h1>
          <p class="text-gray-600">Experience PacketFlow's intent-context-capability system in action</p>
        </div>

        <!-- Chat Interface -->
        <div class="max-w-4xl mx-auto bg-white rounded-lg shadow-lg overflow-hidden">
          <!-- Chat Header -->
          <div class="bg-gradient-to-r from-blue-500 to-purple-600 text-white p-4">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-xl font-semibold">AI Assistant</h2>
                <p class="text-blue-100 text-sm">Powered by PacketFlow</p>
              </div>
              <div class="flex space-x-2">
                <button id="new-chat" class="bg-white bg-opacity-20 hover:bg-opacity-30 px-3 py-1 rounded text-sm transition-colors">New Chat</button>
                <button id="admin-panel" class="bg-white bg-opacity-20 hover:bg-opacity-30 px-3 py-1 rounded text-sm transition-colors">Admin</button>
              </div>
            </div>
          </div>

          <!-- Messages Container -->
          <div id="messages" class="chat-container overflow-y-auto p-4 space-y-4">
            <!-- Welcome message -->
            <div class="flex justify-start">
              <div class="message-bubble bg-blue-100 text-blue-800 p-3 rounded-lg">
                <p>Hello! I'm your AI assistant powered by PacketFlow. Try asking me about:</p>
                <ul class="list-disc list-inside mt-2 space-y-1">
                  <li>PacketFlow capabilities and features</li>
                  <li>Intent-context-capability patterns</li>
                  <li>Elixir and distributed systems</li>
                  <li>Or anything else you'd like to know!</li>
                </ul>
              </div>
            </div>
          </div>

          <!-- Typing indicator -->
          <div id="typing-indicator" class="typing-indicator p-4">
            <div class="flex items-center space-x-2">
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
              <span class="text-gray-500 text-sm ml-2">AI is thinking...</span>
            </div>
          </div>

          <!-- Input Area -->
          <div class="border-t border-gray-200 p-4">
            <form id="chat-form" class="flex space-x-2">
              <input type="text" id="message-input"
                     class="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                     placeholder="Type your message here..."
                     autocomplete="off">
              <button type="submit" class="bg-blue-500 hover:bg-blue-600 text-white px-6 py-2 rounded-lg transition-colors">Send</button>
            </form>
          </div>
        </div>

        <!-- Admin Panel (hidden by default) -->
        <div id="admin-panel" class="hidden max-w-4xl mx-auto mt-8 bg-white rounded-lg shadow-lg p-6">
          <h3 class="text-xl font-semibold mb-4">Admin Panel</h3>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Model Configuration</label>
              <textarea id="model-config"
                       class="w-full border border-gray-300 rounded-lg px-3 py-2 h-32"
                       placeholder='{"model": "gpt-3.5-turbo", "temperature": 0.7, "max_tokens": 1000}'></textarea>
            </div>
            <button id="update-config" class="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg transition-colors">Update Configuration</button>
          </div>
        </div>
      </div>

      <script>
        // Chat functionality
        let currentSessionId = generateSessionId();
        let currentUserId = 'demo-user-' + Math.random().toString(36).substr(2, 9);

        function generateSessionId() {
          return Math.random().toString(36).substr(2, 9);
        }

        function addMessage(content, isUser = false) {
          const messagesContainer = document.getElementById('messages');
          const messageDiv = document.createElement('div');
          messageDiv.className = \`flex \${isUser ? 'justify-end' : 'justify-start'}\`;

          const bubbleClass = isUser
            ? 'message-bubble bg-blue-500 text-white'
            : 'message-bubble bg-gray-100 text-gray-800';

          messageDiv.innerHTML = \`
            <div class="\${bubbleClass} p-3 rounded-lg">
              <p>\${content}</p>
            </div>
          \`;

          messagesContainer.appendChild(messageDiv);
          messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }

        function showTypingIndicator() {
          document.getElementById('typing-indicator').classList.add('show');
        }

        function hideTypingIndicator() {
          document.getElementById('typing-indicator').classList.remove('show');
        }

        async function sendMessage(message) {
          if (!message.trim()) return;

          // Add user message
          addMessage(message, true);

          // Show typing indicator
          showTypingIndicator();

          try {
            const response = await fetch('/api/chat', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                message: message,
                user_id: currentUserId,
                session_id: currentSessionId
              })
            });

            const data = await response.json();

            hideTypingIndicator();

            if (response.ok) {
              addMessage(data.response);
            } else {
              addMessage('Error: ' + (data.message || 'Unknown error'));
            }
          } catch (error) {
            hideTypingIndicator();
            addMessage('Error: Failed to send message');
            console.error('Error:', error);
          }
        }

        // Event listeners
        document.getElementById('chat-form').addEventListener('submit', function(e) {
          e.preventDefault();
          const input = document.getElementById('message-input');
          const message = input.value;
          input.value = '';
          sendMessage(message);
        });

        document.getElementById('new-chat').addEventListener('click', function() {
          currentSessionId = generateSessionId();
          document.getElementById('messages').innerHTML = '';
          addMessage('New chat session started! How can I help you today?');
        });

        document.getElementById('admin-panel').addEventListener('click', function() {
          const panel = document.getElementById('admin-panel');
          panel.classList.toggle('hidden');
        });

        document.getElementById('update-config').addEventListener('click', async function() {
          const configText = document.getElementById('model-config').value;
          try {
            const config = JSON.parse(configText);
            const response = await fetch('/api/config', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                user_id: currentUserId,
                config: config
              })
            });

            if (response.ok) {
              alert('Configuration updated successfully!');
            } else {
              alert('Failed to update configuration');
            }
          } catch (error) {
            alert('Invalid JSON configuration');
          }
        });

        // Enter key support
        document.getElementById('message-input').addEventListener('keypress', function(e) {
          if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            document.getElementById('chat-form').dispatchEvent(new Event('submit'));
          }
        });
      </script>
    </body>
    </html>
    """
  end
end
