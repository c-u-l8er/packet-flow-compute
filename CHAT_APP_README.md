# PacketFlow Chat Application - MVP

A real-time chat application built with Phoenix (Elixir) backend and SvelteKit frontend, demonstrating the foundation for PacketFlow's capability-oriented architecture.

## 🚀 Quick Start

### Prerequisites

Make sure you have the following installed:

- **Elixir** (>= 1.14): `sudo apt install elixir` (Ubuntu) or `brew install elixir` (macOS)
- **Node.js** (>= 18): Download from [nodejs.org](https://nodejs.org/)
- **PostgreSQL** (>= 12): `sudo apt install postgresql postgresql-contrib` (Ubuntu) or `brew install postgresql` (macOS)

### 1. Start PostgreSQL

```bash
# Ubuntu/Debian
sudo service postgresql start

# macOS with Homebrew
brew services start postgresql

# Create database user (if needed)
sudo -u postgres createuser -s $USER
```

### 2. One-Command Startup

From the project root:

```bash
./start-chat-app.sh
```

This script will:
- Check all prerequisites
- Set up the database
- Start the backend server (Phoenix)
- Start the frontend server (SvelteKit)
- Open the application in your browser

### 3. Access the Application

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:4000
- **Phoenix Dashboard**: http://localhost:4000/dev/dashboard (development only)

## 🛠️ Manual Setup

If you prefer to start services individually:

### Backend (Phoenix)

```bash
cd backend
./start.sh
```

Or manually:

```bash
cd backend
mix deps.get          # Install dependencies
mix ecto.create        # Create database
mix ecto.migrate       # Run migrations
mix phx.server         # Start server
```

### Frontend (SvelteKit)

```bash
cd frontend
./start.sh
```

Or manually:

```bash
cd frontend
npm install            # Install dependencies
npm run dev            # Start dev server
```

## 📋 Features

### Current MVP Features

- ✅ Real-time messaging with Phoenix Channels
- ✅ Multiple chat rooms
- ✅ User presence indicators
- ✅ Message history
- ✅ Responsive UI with Tailwind CSS
- ✅ WebSocket connection status
- ✅ Database persistence

### Architecture Highlights

- **Backend**: Phoenix/Elixir with Ecto (PostgreSQL)
- **Frontend**: SvelteKit with TypeScript
- **Real-time**: Phoenix Channels over WebSockets
- **Styling**: Tailwind CSS
- **Database**: PostgreSQL with binary IDs

## 🗄️ Database Schema

The application uses the following tables:

- `users` - User profiles (linked to Clerk authentication)
- `chat_rooms` - Chat room definitions
- `messages` - Chat messages
- `room_members` - Room membership relationships

## 🔧 API Endpoints

### User Management
- `POST /api/users` - Create/update user profile
- `GET /api/users/me` - Get current user profile
- `PUT /api/users/me` - Update user profile

### Room Management
- `GET /api/rooms` - List user's rooms
- `GET /api/rooms/public` - List public rooms
- `GET /api/rooms/:id` - Get room details and messages
- `POST /api/rooms` - Create new room
- `POST /api/rooms/:id/join` - Join room
- `POST /api/rooms/:id/leave` - Leave room

### WebSocket Events

#### Client to Server
- `send_message` - Send a message
- `typing_start` - Start typing indicator
- `typing_stop` - Stop typing indicator

#### Server to Client
- `message_received` - New message broadcast
- `messages_loaded` - Historical messages
- `user_joined` - User joined room
- `user_left` - User left room
- `typing_indicator` - Typing status update

## 🔐 Authentication

The application now supports **Phoenix built-in authentication** with session-based security:

- ✅ **User Registration**: Create accounts with email, username, and password
- ✅ **Secure Login**: Argon2 password hashing for maximum security
- ✅ **Session Management**: Secure session tokens for API and WebSocket auth
- ✅ **Password Requirements**: Strong password validation
- ✅ **Backward Compatibility**: Still supports Clerk JWT tokens for existing integrations

### Authentication Endpoints

- `POST /api/users/register` - Register new user
- `POST /api/users/log_in` - Login with email/password
- `DELETE /api/users/log_out` - Logout and clear session
- `GET /api/users/me` - Get current user profile
- `GET /api/users/session_token` - Get session token for WebSocket

### Frontend Pages

- `/login` - Login form
- `/register` - Registration form
- Main chat (requires authentication)

## 🚧 Development Notes

### Current Limitations (MVP)

1. **Basic UI**: Minimal styling, no advanced chat features
2. **No File Upload**: Text messages only
3. **Local Development Only**: Not production-ready
4. **Email Confirmation**: Tokens generated but email sending not implemented

### Next Steps for Full Implementation

1. **Email Integration**: Add real email sending for confirmations
2. **File Upload**: Add support for images and files
3. **Advanced Chat Features**: Reactions, threads, search
4. **Mobile Responsive**: Optimize for mobile devices
5. **Production Deployment**: Docker, CI/CD, monitoring
6. **Password Reset**: Complete password reset flow

## 🐛 Troubleshooting

### Common Issues

**PostgreSQL Connection Error**
```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL
sudo service postgresql start  # Ubuntu
brew services start postgresql # macOS
```

**Port Already in Use**
```bash
# Kill processes on ports 4000 or 5173
lsof -ti:4000 | xargs kill -9
lsof -ti:5173 | xargs kill -9
```

**Mix/Elixir Not Found**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install elixir

# macOS
brew install elixir
```

**Node.js/npm Not Found**
- Download and install from [nodejs.org](https://nodejs.org/)

### Logs and Debugging

- **Backend logs**: Check the terminal where Phoenix is running
- **Frontend logs**: Check browser console (F12)
- **Database issues**: Check PostgreSQL logs

## 📁 Project Structure

```
packetflow/
├── backend/                 # Phoenix application
│   ├── lib/
│   │   ├── packetflow_chat/          # Business logic
│   │   │   ├── accounts/             # User management
│   │   │   ├── chat/                 # Chat functionality
│   │   │   └── auth.ex               # Authentication
│   │   └── packetflow_chat_web/      # Web layer
│   │       ├── channels/             # WebSocket channels
│   │       └── controllers/          # HTTP controllers
│   ├── priv/repo/migrations/         # Database migrations
│   └── start.sh                      # Backend startup script
├── frontend/                # SvelteKit application
│   ├── src/
│   │   ├── routes/                   # Pages and layouts
│   │   └── lib/                      # Shared components
│   └── start.sh                      # Frontend startup script
└── start-chat-app.sh        # Main startup script
```

## 🎯 PacketFlow Integration Status

This chat application demonstrates PacketFlow's evolution through multiple phases:

### ✅ **Phase 1 Complete: Actor Model Foundation**
- **Stateful Actors**: Persistent chat agents with conversation memory
- **Actor Lifecycle**: Automatic creation, timeout handling, and cleanup  
- **Message Persistence**: Actors maintain conversation history across sessions
- **Dynamic Supervision**: Fault-tolerant actor process management

### ✅ **Phase 2 Complete: AI Integration**
- **Natural Language Interface**: AI-powered chat analysis and responses
- **LLM Integration**: Anthropic Claude and OpenAI GPT support
- **Capability Discovery**: AI agents can find and use chat capabilities
- **Smart Responses**: AI-generated response suggestions and content analysis

### 🚧 **Phase 3 In Progress: MCP Protocol Integration**
- **Model Context Protocol**: Industry-standard AI tool integration
- **Tool Discovery**: Chat capabilities exposed as MCP tools
- **Cross-System Integration**: Connect with external AI systems
- **Enhanced AI Interface**: MCP-aware chat features

### 🎯 **Current Capabilities**

**Actor-Based Chat Agents**:
```bash
# Test the actor system
cd backend && mix run test_actor_system.exs
```

**AI-Powered Features**:
- Conversation analysis and summarization
- AI response generation and suggestions  
- Content moderation and safety scoring
- Room activity insights and trending topics

**API Endpoints**:
- `POST /api/ai/natural` - Natural language chat interface
- `POST /api/ai/capability/:id` - Execute chat capabilities
- `GET /api/ai/capabilities` - Discover available features

The architecture seamlessly integrates PacketFlow's capability-oriented approach with real-time chat functionality, demonstrating how distributed AI systems can be built with persistent state and intelligent orchestration.

---

**Happy Chatting!** 🎉

For issues or questions, check the troubleshooting section above or review the application logs.