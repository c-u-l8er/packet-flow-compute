# 🚀 PacketFlow Chat Demo with Real OpenAI Integration

## Quick Start

1. **Set your OpenAI API key** (already configured in the code):
   ```bash
   export OPENAI_API_KEY="sk-proj-4389ryhu..."
   ```

2. **Navigate to the demo directory**:
   ```bash
   cd /home/travis/Projects/packetflow/demo/packetflow_chat_demo
   ```

3. **Install dependencies**:
   ```bash
   mix deps.get
   ```

4. **Start the server**:
   ```bash
   mix phx.server
   ```

5. **Open your browser** to: `http://localhost:4000`

## Features

### ✅ **Real OpenAI Integration**
- Uses your actual OpenAI API key
- Generates intelligent responses using GPT-3.5-turbo
- Maintains conversation history

### ✅ **Streaming Responses**
- Messages appear word-by-word as they're generated
- Visual streaming indicator with blinking cursor
- Natural typing simulation

### ✅ **PacketFlow Architecture**
- **Capabilities**: `send_message`, `stream_response`, `view_history`, `admin`
- **Intents**: `StreamMessageIntent` for real-time responses
- **Context**: User sessions and conversation management
- **Effects**: Stream events and message handling

### ✅ **Production Features**
- Rate limiting (10 requests per minute per user)
- Error handling for API failures
- Session management
- Admin panel for configuration

## How It Works

1. **User types message** → LiveView captures input
2. **StreamMessageIntent created** → Sent to ChatReactor
3. **ChatReactor processes** → Calls OpenAI API
4. **Response streams back** → Word-by-word via PubSub
5. **LiveView updates UI** → Real-time message display

## Architecture

```
User Input → LiveView → ChatReactor → OpenAI Service → Streaming Response
     ↑                                                           ↓
     └────────────── PubSub Broadcast ←─────────────────────────┘
```

The application demonstrates PacketFlow's intent-context-capability pattern with real AI integration while providing a smooth, responsive chat experience.

## Troubleshooting

- **Port 4000 in use**: The app will try port 4000, change it in `config/dev.exs` if needed
- **API key issues**: Make sure the environment variable is set correctly
- **Network errors**: Check your internet connection for OpenAI API access
