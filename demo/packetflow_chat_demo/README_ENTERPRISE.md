# PacketFlow Enterprise Chat Demo

A comprehensive demonstration of PacketFlow's capabilities for building **enterprise-grade, multi-tenant** LLM-powered chat applications.

## 🚀 Enterprise Features

This demo has been transformed into a full enterprise chat application with:

### 🏢 **Multi-Tenant Architecture**
- **Tenant Isolation**: Complete data separation between organizations
- **Custom Branding**: Each tenant can have its own name, logo, and settings
- **URL-based Routing**: Clean URLs like `chat.app/acme-corp/chat`

### 🔐 **Authentication & Authorization**
- **Email/Password/Username Authentication**: Secure user registration and login
- **Role-Based Access Control**: Owner, Admin, and Member roles
- **Guardian JWT Integration**: Secure session management
- **Tenant-Scoped Permissions**: Users can only access their authorized tenants

### 🤖 **Advanced AI Integration**
- **Multiple AI Providers**: Support for OpenAI, Anthropic Claude, Google AI
- **Custom API Keys**: Each tenant can bring their own API keys
- **Model Selection**: Real-time model switching during conversations
- **Auto-Model Selection**: Smart model selection based on availability

### 💬 **Enterprise Chat Experience**
- **Multiple Chat Windows**: Tabbed interface like VS Code/Cursor
- **Session Management**: Create, delete, and organize chat sessions
- **Real-Time Streaming**: Live AI responses with typing indicators
- **Message History**: Persistent chat history per session
- **Modern UI**: Clean, professional interface inspired by Cursor

### ⚙️ **Tenant Settings**
- **API Configuration**: Manage OpenAI, Anthropic, Google, Azure OpenAI keys
- **Chat Defaults**: Set default model, temperature, max tokens
- **Team Management**: View and manage team members
- **Permission Controls**: Toggle model selection permissions

## 🛠️ Quick Setup

```bash
# Clone and navigate to the demo
cd demo/packetflow_chat_demo

# Run the setup script
./setup.sh

# Start the application
mix phx.server
```

Visit `http://localhost:4000` to get started!

## 📋 Usage Flow

1. **Register**: Create your account at `/register`
2. **Create Organization**: Set up your first tenant organization
3. **Configure Settings**: Add your API keys in tenant settings
4. **Start Chatting**: Open multiple chat windows and select models
5. **Invite Team**: Add team members to your organization

## 🏗️ Database Schema

### Core Tables
- **users**: User accounts with email/password authentication
- **tenants**: Organization/tenant configuration and API keys
- **tenant_members**: User-tenant relationships with roles
- **chat_sessions**: Individual chat conversations
- **chat_messages**: Message history with metadata

### Multi-Tenant Isolation
All chat data is scoped to tenants, ensuring complete data isolation between organizations.

## 🔧 Configuration

### Environment Variables
```bash
# Database
DATABASE_URL="postgresql://user:pass@localhost/packetflow_chat_demo_dev"

# Optional: Default API keys (can be overridden per tenant)
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."
GOOGLE_API_KEY="AIza..."
```

### Tenant API Keys
Each tenant can configure their own API keys in the settings panel:
- OpenAI API Key (for GPT models)
- Anthropic API Key (for Claude models)
- Google AI API Key (for Gemini models)
- Azure OpenAI (endpoint + key)

## 🎨 UI/UX Features

### Cursor-Inspired Design
- **Sidebar Navigation**: Collapsible sidebar with chat sessions
- **Tabbed Interface**: Multiple chat windows with easy switching
- **Modern Typography**: Clean, readable fonts and spacing
- **Professional Colors**: Blue/gray enterprise color scheme
- **Responsive Design**: Works on desktop and mobile devices

### Interactive Elements
- **Model Dropdown**: Real-time model selection
- **Settings Panel**: Slide-out configuration panel
- **Typing Indicators**: Visual feedback during AI responses
- **Message Timestamps**: Clear conversation timeline
- **Session Management**: Easy create/delete/rename operations

## 🚀 Deployment Ready

This demo is production-ready with:
- **Database Migrations**: Proper schema versioning
- **Environment Configuration**: Separate dev/prod configs
- **Security**: CSRF protection, secure headers, input validation
- **Error Handling**: Graceful error states and user feedback
- **Performance**: Optimized queries and asset compilation

## 🧪 Testing

```bash
# Run tests
mix test

# Run with coverage
mix test --cover

# Check code quality
mix credo
```

## 📈 Scaling Considerations

- **Database**: PostgreSQL with proper indexing
- **Sessions**: Redis for session storage in production
- **File Storage**: S3/CloudFlare for user avatars and attachments
- **API Rate Limiting**: Built-in rate limiting per user/tenant
- **Monitoring**: Telemetry integration for observability

## 🤝 Contributing

This demo showcases PacketFlow's enterprise capabilities. For the core PacketFlow library, see the main repository.

## 📄 License

MIT License - see the main PacketFlow repository for details.
