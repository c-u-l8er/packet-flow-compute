# AI Agent Layer Specification - LLM Users with Memory and Tools

## Overview

This specification defines an AI agent layer that sits on top of the existing chat application, allowing human users to create, manage, and interact with AI agents that function as autonomous chat participants. These AI agents are LLMs with persistent memory, tool capabilities, and the ability to engage in conversations alongside human users.

## Architecture Integration

### Extends Base Chat Application
- **Preserves all existing functionality** from the base chat specification
- **Adds AI agent capabilities** as an overlay system
- **Uses same infrastructure** (Cloudflare D1, KV, Durable Objects, Clerk auth)
- **Maintains same real-time architecture** with Phoenix Channels

### AI Agent Infrastructure
- **Anthropic Claude API** - Primary LLM provider
- **OpenAI GPT API** - Alternative LLM provider
- **Cloudflare AI** - Local edge AI processing for simple tasks
- **Vector Database** - Pinecone or Weaviate for memory embeddings
- **Tool Execution Runtime** - Sandboxed environment for AI tool usage

## Extended Database Schema

### AI Agents Table
```sql
CREATE TABLE ai_agents (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_by TEXT NOT NULL, -- Human user who created this agent
  llm_provider TEXT NOT NULL, -- 'anthropic', 'openai', 'cloudflare'
  model_name TEXT NOT NULL, -- 'claude-3-sonnet', 'gpt-4', etc.
  system_prompt TEXT NOT NULL,
  personality TEXT, -- JSON blob of personality traits
  capabilities TEXT, -- JSON array of enabled tools/capabilities
  memory_enabled BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(clerk_user_id)
);
```

### Agent Memory Table
```sql
CREATE TABLE agent_memories (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  memory_type TEXT NOT NULL, -- 'conversation', 'fact', 'preference', 'skill'
  content TEXT NOT NULL,
  embedding_vector TEXT, -- Serialized vector for similarity search
  importance_score REAL DEFAULT 0.5, -- 0.0 to 1.0, for memory prioritization
  context TEXT, -- JSON metadata about when/where this memory was formed
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  accessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  access_count INTEGER DEFAULT 0,
  FOREIGN KEY (agent_id) REFERENCES ai_agents(id)
);
```

### Agent Conversations Table
```sql
CREATE TABLE agent_conversations (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  room_id TEXT NOT NULL,
  conversation_summary TEXT,
  last_message_at DATETIME,
  message_count INTEGER DEFAULT 0,
  relationship_data TEXT, -- JSON blob tracking relationships with users
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (agent_id) REFERENCES ai_agents(id),
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id)
);
```

### Tool Executions Table
```sql
CREATE TABLE tool_executions (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  tool_name TEXT NOT NULL,
  input_data TEXT NOT NULL, -- JSON
  output_data TEXT, -- JSON
  execution_status TEXT DEFAULT 'pending', -- 'pending', 'success', 'error'
  error_message TEXT,
  executed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  execution_time_ms INTEGER,
  FOREIGN KEY (agent_id) REFERENCES ai_agents(id)
);
```

## AI Agent Capabilities

### Core LLM Features
- **Multi-provider support** - Anthropic Claude, OpenAI GPT, Cloudflare AI
- **Persistent memory** - Remember conversations, facts, preferences across sessions
- **Personality customization** - Defined personality traits and communication styles
- **Context awareness** - Understand conversation history and participant relationships

### Built-in Tools
#### Information Tools
- **Web Search** - Search the internet for current information
- **Knowledge Base** - Query internal knowledge bases
- **Calculator** - Perform mathematical calculations
- **Time/Date** - Get current time, schedule information

#### Communication Tools
- **Direct Message** - Send private messages to specific users
- **Room Management** - Create, join, or leave chat rooms
- **User Lookup** - Find information about other users (with permissions)
- **Translation** - Translate messages between languages

#### Creative Tools
- **Image Generation** - Generate images using DALL-E or Stable Diffusion
- **Code Generation** - Write and execute code snippets
- **Document Creation** - Create formatted documents, presentations
- **Content Summarization** - Summarize long conversations or documents

#### Integration Tools
- **Calendar Integration** - Schedule events, check availability
- **Task Management** - Create and manage todo items
- **File Operations** - Read, create, and modify files
- **API Calls** - Make HTTP requests to external services

### Custom Tool Framework
```typescript
interface AgentTool {
  name: string;
  description: string;
  parameters: ToolParameter[];
  execute: (params: any) => Promise<ToolResult>;
  permissions: string[]; // Required permissions to use this tool
}

interface ToolParameter {
  name: string;
  type: 'string' | 'number' | 'boolean' | 'array' | 'object';
  description: string;
  required: boolean;
  validation?: ValidationRule[];
}
```

## Memory System

### Memory Types
- **Episodic Memory** - Specific conversations and events
- **Semantic Memory** - Facts, knowledge, and learned information
- **Procedural Memory** - How to perform tasks and use tools
- **Social Memory** - Relationships, preferences, and social context

### Memory Storage Strategy
- **Vector Embeddings** - Store memory as embeddings for similarity search
- **Importance Scoring** - Prioritize memories based on relevance and frequency
- **Memory Consolidation** - Merge similar memories to reduce storage
- **Forgetting Mechanism** - Gradually fade old, unused memories

### Memory Retrieval
```typescript
interface MemoryQuery {
  query: string;
  memoryTypes: MemoryType[];
  limit: number;
  minSimilarity: number;
  timeRange?: DateRange;
}

interface MemoryResult {
  memory: AgentMemory;
  similarity: number;
  relevanceScore: number;
}
```

## Extended API Endpoints

### AI Agent Management
- `GET /api/agents` - List user's AI agents
- `POST /api/agents` - Create new AI agent
- `GET /api/agents/:id` - Get agent details
- `PUT /api/agents/:id` - Update agent configuration
- `DELETE /api/agents/:id` - Delete agent
- `POST /api/agents/:id/activate` - Activate/deactivate agent
- `POST /api/agents/:id/clone` - Clone agent configuration

### Agent Memory Management
- `GET /api/agents/:id/memories` - Get agent memories
- `POST /api/agents/:id/memories` - Add memory to agent
- `PUT /api/memories/:id` - Update memory
- `DELETE /api/memories/:id` - Delete memory
- `POST /api/agents/:id/memories/search` - Search agent memories

### Agent Interactions
- `POST /api/agents/:id/chat` - Send direct message to agent
- `POST /api/agents/:id/invoke-tool` - Manually invoke agent tool
- `GET /api/agents/:id/conversations` - Get agent's conversation history
- `POST /api/agents/:id/train` - Train agent with custom data

### Tool Management
- `GET /api/tools` - List available tools
- `GET /api/agents/:id/tools` - Get agent's enabled tools
- `PUT /api/agents/:id/tools` - Update agent's tool permissions
- `GET /api/tools/executions` - Get tool execution history

## Agent Behavior System

### Personality Framework
```typescript
interface AgentPersonality {
  traits: {
    extraversion: number; // 0-1 scale
    agreeableness: number;
    conscientiousness: number;
    neuroticism: number;
    openness: number;
  };
  communicationStyle: {
    formality: 'casual' | 'professional' | 'formal';
    verbosity: 'concise' | 'moderate' | 'verbose';
    humor: 'none' | 'subtle' | 'frequent';
    empathy: 'low' | 'moderate' | 'high';
  };
  interests: string[];
  expertise: string[];
  limitations: string[];
}
```

### Autonomous Behavior
- **Proactive Engagement** - Agents can initiate conversations
- **Context Switching** - Adapt behavior based on conversation context
- **Learning from Feedback** - Improve responses based on user reactions
- **Goal-Oriented Actions** - Pursue objectives across multiple conversations

### Conversation Patterns
- **Natural Turn-Taking** - Wait for appropriate moments to contribute
- **Topic Awareness** - Stay relevant to current conversation topics
- **Social Cues** - Recognize and respond to emotional states
- **Conflict Resolution** - De-escalate tense situations

## Real-time AI Integration

### Extended WebSocket Events

#### Client to Server
- `invoke_agent` - Manually invoke an agent in a room
- `agent_feedback` - Provide feedback on agent response
- `agent_command` - Send command to specific agent

#### Server to Client
- `agent_message` - Message from AI agent
- `agent_action` - Agent performed an action (tool use, etc.)
- `agent_thinking` - Agent is processing (thinking indicator)
- `tool_execution` - Tool execution status update

### Agent Response Pipeline
1. **Message Reception** - Agent receives message in room
2. **Context Assembly** - Gather conversation history and relevant memories
3. **LLM Processing** - Send context to LLM provider
4. **Tool Evaluation** - Determine if tools need to be used
5. **Response Generation** - Generate appropriate response
6. **Memory Storage** - Store new memories from interaction
7. **Message Broadcasting** - Send response to room

## Security and Permissions

### Agent Permissions
- **Room Access** - Which rooms agents can join/participate in
- **Tool Usage** - Which tools agents are allowed to use
- **User Interaction** - Who agents can directly message
- **Memory Access** - What information agents can remember
- **External Access** - Which external APIs agents can call

### Safety Measures
- **Content Filtering** - Filter inappropriate agent responses
- **Rate Limiting** - Limit agent message frequency and API calls
- **Sandbox Execution** - Run agent tools in isolated environments
- **Audit Logging** - Log all agent actions for review
- **Emergency Shutdown** - Ability to immediately disable agents

### Privacy Protection
- **Memory Encryption** - Encrypt sensitive memories at rest
- **User Consent** - Explicit consent for memory storage
- **Data Retention** - Automatic deletion of old memories
- **Cross-Agent Isolation** - Agents cannot access each other's memories

## Cloudflare KV Extensions

### Agent State Cache
- Key: `agent:{agent_id}:state`
- Value: Current agent state, active conversations
- TTL: 1 hour

### Memory Cache
- Key: `agent:{agent_id}:recent_memories`
- Value: Frequently accessed memories for quick retrieval
- TTL: 6 hours

### Tool Results Cache
- Key: `tool:{tool_name}:{hash(input)}`
- Value: Cached tool execution results
- TTL: 24 hours (varies by tool)

## LLM Provider Integration

### Anthropic Claude Integration
```typescript
interface ClaudeConfig {
  model: 'claude-3-sonnet' | 'claude-3-opus' | 'claude-3-haiku';
  maxTokens: number;
  temperature: number;
  systemPrompt: string;
  tools: ToolDefinition[];
}
```

### OpenAI GPT Integration
```typescript
interface OpenAIConfig {
  model: 'gpt-4' | 'gpt-3.5-turbo' | 'gpt-4-turbo';
  maxTokens: number;
  temperature: number;
  systemMessage: string;
  functions: FunctionDefinition[];
}
```

### Cloudflare AI Integration
- **Local Processing** - Use Cloudflare Workers AI for simple tasks
- **Cost Optimization** - Route simple queries to cheaper models
- **Latency Reduction** - Process at edge for faster responses

## Monitoring and Analytics

### Agent Performance Metrics
- **Response Time** - Time to generate responses
- **User Satisfaction** - Ratings and feedback scores
- **Tool Usage** - Frequency and success rate of tool usage
- **Memory Efficiency** - Memory retrieval accuracy and speed
- **Conversation Quality** - Engagement and retention metrics

### Usage Analytics
- **Active Agents** - Number of active agents per user
- **Message Volume** - Agent message frequency and volume
- **Tool Execution Stats** - Most used tools and execution times
- **Cost Tracking** - LLM API usage and costs per agent

### Health Monitoring
- **Error Rates** - Agent failures and error patterns
- **Performance Degradation** - Response time increases
- **Resource Usage** - Memory and compute consumption
- **API Limits** - Track approaching rate limits

## Deployment Considerations

### Scaling Strategy
- **Agent Load Balancing** - Distribute agents across instances
- **Memory Sharding** - Partition agent memories for performance
- **Tool Runtime Scaling** - Auto-scale tool execution environments
- **Cost Management** - Monitor and optimize LLM API costs

### Configuration Management
- **Environment-Specific Settings** - Different configs for dev/prod
- **Feature Flags** - Enable/disable agent features dynamically
- **A/B Testing** - Test different agent configurations
- **Rollback Strategy** - Quick rollback for problematic agents

This AI agent layer transforms the chat application into a sophisticated platform where humans and AI agents can collaborate, learn, and interact naturally while maintaining all the security, performance, and reliability of the base system.
