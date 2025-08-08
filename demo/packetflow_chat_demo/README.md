# PacketFlow LLM Chat Demo

A comprehensive demonstration of PacketFlow's intent-context-capability system applied to an LLM chat application.

## 🚀 Overview

This demo showcases how PacketFlow's DSL (Domain-Specific Language) can be used to build a production-ready LLM chat application with:

- **Capability-based security** - Fine-grained permission control
- **Context management** - Automatic information flow through the system
- **Intent-driven design** - Clear separation of user intentions and system effects
- **Distributed processing** - Scalable actor-based architecture
- **Real-time web interface** - Beautiful UI with live chat functionality

## 🏗️ Architecture

### PacketFlow DSL Components

#### 1. **Capabilities** (`ChatCap`)
```elixir
defsimple_capability ChatCap, [:send_message, :view_history, :admin] do
  @implications [
    {ChatCap.admin, [ChatCap.send_message, ChatCap.view_history]},
    {ChatCap.send_message, [ChatCap.view_history]}
  ]
end
```

- **`send_message`** - Basic capability to send messages
- **`view_history`** - Ability to view chat history
- **`admin`** - Administrative capabilities (implies all others)

#### 2. **Contexts** (`ChatContext`)
```elixir
defsimple_context ChatContext, [:user_id, :session_id, :capabilities, :model_config] do
  @propagation_strategy :inherit
end
```

- Manages user identity, session state, and model configuration
- Automatic propagation through the system

#### 3. **Intents** 
- **`SendMessageIntent`** - User wants to send a message
- **`GetHistoryIntent`** - User wants to view chat history
- **`AdminConfigIntent`** - Admin wants to update model configuration

#### 4. **Effects** (`ChatEffect`)
- **`message_sent`** - Message was successfully sent and AI responded
- **`history_retrieved`** - Chat history was retrieved
- **`config_updated`** - Model configuration was updated
- **`error`** - Error occurred during processing

#### 5. **Reactor** (`ChatReactor`)
- Handles all intents and manages application state
- Maintains chat sessions and model configuration
- Simulates AI response generation

## 🎯 Features

### Core Functionality
- ✅ **Real-time chat interface** with typing indicators
- ✅ **Session management** with persistent chat history
- ✅ **Capability-based access control** for different user types
- ✅ **Admin panel** for model configuration updates
- ✅ **Error handling** with graceful degradation
- ✅ **Responsive design** with Tailwind CSS

### PacketFlow Integration
- ✅ **DSL-driven architecture** with clear separation of concerns
- ✅ **Intent-context-capability pattern** for security and clarity
- ✅ **Component lifecycle management** with proper startup/shutdown
- ✅ **Effect validation** with structured error handling
- ✅ **Context propagation** throughout the system

### Technical Features
- ✅ **WebSocket-ready** architecture for real-time updates
- ✅ **RESTful API** endpoints for chat operations
- ✅ **JSON serialization** for all data structures
- ✅ **Comprehensive logging** with structured output
- ✅ **Health monitoring** with component status tracking

## 🚀 Quick Start

### Prerequisites
- Elixir 1.14+
- Mix package manager
- PacketFlow framework (included as local dependency)

### Installation

1. **Navigate to the demo directory:**
   ```bash
   cd demo/packetflow_chat_demo
   ```

2. **Install dependencies:**
   ```bash
   mix deps.get
   ```

3. **Compile the project:**
   ```bash
   mix compile
   ```

4. **Start the application:**
   ```bash
   mix run --no-halt
   ```

5. **Open your browser:**
   Navigate to `http://localhost:4000`

## 🎮 Usage

### Basic Chat
1. Type a message in the input field
2. Press Enter or click "Send"
3. Watch the AI respond with PacketFlow-powered responses

### Try These Examples
- **"Hello"** - Get a friendly greeting
- **"Tell me about PacketFlow"** - Learn about the framework
- **"What are capabilities?"** - Understand capability-based security
- **"Explain intents"** - Learn about intent-driven design
- **"Help"** - Get assistance with available features

### Admin Features
1. Click the "Admin" button in the chat header
2. Modify the model configuration JSON
3. Click "Update Configuration" to apply changes

### New Chat Sessions
1. Click "New Chat" to start a fresh conversation
2. Each session maintains its own history
3. Sessions are automatically created and managed

## 🏗️ Code Structure

```
lib/packetflow_chat_demo/
├── application.ex          # OTP application startup
├── chat_system.ex         # PacketFlow DSL definitions
├── chat_reactor.ex        # GenServer wrapper for the reactor
└── web.ex                 # Web interface with Plug + Temple
```

### Key Modules

#### `ChatSystem` - PacketFlow DSL
- Defines capabilities, contexts, intents, effects, and reactor
- Implements handler functions for each intent
- Manages chat sessions and AI response generation

#### `ChatReactor` - GenServer Wrapper
- Provides clean API for web interface
- Handles PacketFlow component lifecycle
- Manages context and intent creation

#### `Web` - Web Interface
- Beautiful chat UI with Tailwind CSS
- RESTful API endpoints
- Real-time JavaScript functionality

## 🔧 Configuration

### Model Configuration
The AI model can be configured through the admin panel:

```json
{
  "model": "gpt-3.5-turbo",
  "temperature": 0.7,
  "max_tokens": 1000
}
```

### Capability Hierarchy
```
admin
├── send_message
│   └── view_history
└── view_history
```

## 🧪 Testing

Run the test suite:
```bash
mix test
```

## 📊 Monitoring

The application includes comprehensive logging:
- Component lifecycle events
- Intent processing
- Effect generation
- Error handling

## 🔍 Debugging

### Enable Debug Logging
```elixir
# In config/dev.exs
config :logger, level: :debug
```

### Inspect Reactor State
```elixir
# In IEx
iex> PacketflowChatDemo.ChatReactor.get_sessions()
```

## 🚀 Production Deployment

### Environment Variables
- `PORT` - Web server port (default: 4000)
- `LOG_LEVEL` - Logging level (default: info)

### Docker Support
```dockerfile
FROM elixir:1.14-alpine
WORKDIR /app
COPY . .
RUN mix deps.get && mix compile
EXPOSE 4000
CMD ["mix", "run", "--no-halt"]
```

## 🤝 Contributing

This demo is part of the PacketFlow framework. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📚 Learn More

- [PacketFlow Documentation](https://github.com/packetflow/packetflow)
- [Elixir Language](https://elixir-lang.org/)
- [Plug Framework](https://hexdocs.pm/plug/)
- [Temple Templates](https://hexdocs.pm/temple/)

## 📄 License

MIT License - see LICENSE file for details.

---

**Built with ❤️ using PacketFlow - Production-Ready Distributed Computing Framework for Elixir**

