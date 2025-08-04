# PacketFlow Phase 2 - AI Integration Setup Guide

## Overview

Phase 2 of PacketFlow development adds AI integration capabilities, including:

- ✅ **Intent Analysis** - Natural language processing for user requests
- ✅ **LLM Integration** - Anthropic Claude and OpenAI GPT support
- ✅ **Execution Planning** - Automated plan generation from user intents
- ✅ **Capability Discovery** - AI-powered capability search and selection
- ✅ **Chat Integration** - PacketFlow capabilities integrated with existing chat system
- ✅ **Frontend Interface** - AI assistant interface for testing capabilities
- ⏳ **API Keys Setup** - Configuration for LLM providers
- ⏳ **Testing & Validation** - End-to-end testing with real examples

## What's Been Implemented

### 1. Core PacketFlow Infrastructure

- **PacketFlow.Capability** - Macro for defining declarative capabilities
- **PacketFlow.CapabilityRegistry** - Discovery and management system
- **PacketFlow.ExecutionEngine** - Execution orchestration for capabilities and plans
- **PacketFlow.AIPlanner** - AI-powered intent analysis and plan generation

### 2. Chat Capabilities

Five example capabilities demonstrating AI integration:

- `send_message` - Enhanced message sending with AI insights
- `analyze_conversation` - Conversation pattern analysis
- `generate_response` - AI-powered response suggestions
- `moderate_content` - Content safety analysis
- `create_room_summary` - Intelligent room activity summaries

### 3. Web API

RESTful API endpoints for AI functionality:

- `POST /api/ai/natural` - Natural language interface
- `POST /api/ai/plan` - Generate execution plans
- `POST /api/ai/execute` - Execute generated plans
- `POST /api/ai/capability/:id` - Execute individual capabilities
- `GET /api/ai/capabilities` - Discover available capabilities

### 4. Frontend Interface

AI assistant component integrated into the chat interface with:

- Natural language input processing
- Capability discovery and execution
- Execution history tracking
- Real-time AI responses

## Setup Instructions

### 1. API Keys Configuration

Create environment variables for LLM providers:

```bash
# For Anthropic Claude (recommended)
export ANTHROPIC_API_KEY="your_anthropic_api_key_here"

# For OpenAI GPT (alternative)
export OPENAI_API_KEY="your_openai_api_key_here"
```

Or add to your `.env` file:

```env
ANTHROPIC_API_KEY=your_anthropic_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
```

### 2. Get API Keys

#### Anthropic Claude (Primary)
1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Create an account and add billing
3. Generate an API key
4. Set the `ANTHROPIC_API_KEY` environment variable

#### OpenAI GPT (Fallback)
1. Go to [platform.openai.com](https://platform.openai.com)
2. Create an account and add billing
3. Generate an API key
4. Set the `OPENAI_API_KEY` environment variable

### 3. Start the Application

```bash
# Start the backend (in backend/ directory)
./start.sh

# Start the frontend (in frontend/ directory)  
./start.sh
```

### 4. Test the AI Integration

1. Navigate to the chat application
2. Log in or register an account
3. Look for the "🤖 PacketFlow AI Assistant" section
4. Try natural language commands like:
   - "Analyze the conversation in this room"
   - "What are people talking about?"
   - "Create a summary of recent activity"

## Example Usage

### Natural Language Interface

```javascript
// POST /api/ai/natural
{
  "message": "Can you analyze the conversation in room 123 and tell me the main topics?",
  "context": {
    "user_id": "user_456",
    "room_id": "123"
  }
}
```

### Direct Capability Execution

```javascript
// POST /api/ai/capability/analyze_conversation
{
  "payload": {
    "room_id": "123",
    "message_count": 50
  },
  "context": {
    "user_id": "user_456"
  }
}
```

### Capability Discovery

```javascript
// GET /api/ai/capabilities?intent=analyze
// Returns capabilities matching "analyze" intent
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ Frontend AI Interface (Svelte)                         │
│ - Natural language input                               │
│ - Capability discovery UI                              │
│ - Execution history                                    │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│ AI Controller (Phoenix)                                │
│ - /api/ai/natural - Natural language processing        │
│ - /api/ai/capabilities - Capability discovery          │
│ - /api/ai/execute - Plan execution                     │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│ PacketFlow Core                                        │
│ ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐│
│ │   AI Planner    │ │ Execution Engine│ │  Capability  ││
│ │ - Intent analysis│ │ - Plan execution│ │   Registry   ││
│ │ - Plan generation│ │ - Error handling│ │ - Discovery  ││
│ │ - LLM integration│ │ - Telemetry     │ │ - Management ││
│ └─────────────────┘ └─────────────────┘ └──────────────┘│
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│ Chat Capabilities                                      │
│ - send_message - analyze_conversation                  │
│ - generate_response - moderate_content                 │
│ - create_room_summary                                  │
└─────────────────────────────────────────────────────────┘
```

## Next Steps (Phase 3)

1. **Composition Patterns** - Pipeline, parallel, conditional flows
2. **Advanced AI Features** - Multi-turn conversations, context retention
3. **Performance Optimization** - Caching, load balancing
4. **Actor Model** - Stateful capability actors (Phase 4 preparation)

## Troubleshooting

### Common Issues

1. **"Missing API Key" Errors**
   - Ensure environment variables are set correctly
   - Restart the application after setting keys

2. **"Capability Not Found" Errors**
   - Check that capabilities are being loaded at startup
   - Look for capability registration logs

3. **AI Planning Failures**
   - Verify API key has sufficient credits
   - Check network connectivity to LLM providers

### Debug Information

Check application logs for:
- `PacketFlow.CapabilityRegistry started`
- `Loaded X capabilities from PacketFlow.Capabilities.ChatCapabilities`
- `PacketFlow.AIPlanner started with provider: anthropic`

## Success Metrics

Phase 2 is successful when you can:

1. ✅ Ask natural language questions and get AI responses
2. ✅ Discover capabilities through the web interface
3. ✅ Execute individual capabilities via API
4. ✅ Generate and execute multi-step plans from user intents
5. ✅ See telemetry and execution history

**You've successfully implemented the foundation for AI-native distributed systems!** 🚀

The PacketFlow framework can now understand user intents, discover appropriate capabilities, and execute intelligent plans - setting the stage for the advanced composition and actor patterns in Phase 3 and beyond.