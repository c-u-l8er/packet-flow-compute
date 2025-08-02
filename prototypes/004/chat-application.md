# Elixir/SvelteKit Chat Application Design Specification

## Project Overview

A real-time chat application built with Phoenix Channels (Elixir) backend and SvelteKit frontend, using Cloudflare services for persistence and Clerk.com for authentication. Zero traditional database infrastructure required.

## Technology Stack

### Frontend
- **SvelteKit** - Web framework
- **@clerk/sveltekit** - Authentication
- **WebSocket client** - Real-time messaging
- **Deployed to**: Cloudflare Pages

### Backend
- **Phoenix/Elixir** - API server with Phoenix Channels
- **Joken** - JWT verification for Clerk tokens
- **HTTP clients** - Cloudflare D1 and KV API integration
- **Deployed to**: Traditional server or Cloudflare Workers

### Infrastructure
- **Cloudflare D1** - SQLite-based database for persistent data
- **Cloudflare KV** - Key-value store for sessions and cache
- **Cloudflare Durable Objects** - Real-time message coordination
- **Cloudflare R2** - File/media storage
- **Clerk.com** - Authentication service

## Database Schema (Cloudflare D1)

### Users Table
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  clerk_user_id TEXT UNIQUE NOT NULL,
  username TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Chat Rooms Table
```sql
CREATE TABLE chat_rooms (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_by TEXT NOT NULL,
  is_private BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(clerk_user_id)
);
```

### Messages Table
```sql
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text', -- 'text', 'image', 'file'
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
  FOREIGN KEY (user_id) REFERENCES users(clerk_user_id)
);
```

### Room Members Table
```sql
CREATE TABLE room_members (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  role TEXT DEFAULT 'member', -- 'admin', 'moderator', 'member'
  PRIMARY KEY (room_id, user_id),
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
  FOREIGN KEY (user_id) REFERENCES users(clerk_user_id)
);
```

## Authentication Flow

1. User signs in through Clerk UI in SvelteKit
2. Clerk provides JWT token to frontend
3. Frontend includes JWT in API requests and WebSocket connections
4. Phoenix backend verifies JWT using Clerk's public key
5. Durable Objects authenticate WebSocket connections via JWT
6. User operations use Clerk user ID as identifier

## Real-time Architecture

### Phoenix Channels
- Handle WebSocket connections from SvelteKit frontend
- Coordinate with Durable Objects for message broadcasting
- Manage user presence and typing indicators
- Handle room subscriptions and unsubscriptions

### Cloudflare Durable Objects
- One Durable Object per chat room
- Maintains list of connected users
- Broadcasts messages to all room participants
- Handles real-time features (typing indicators, presence)
- Persists messages to D1 database

### Message Flow
1. User sends message via Phoenix Channel
2. Phoenix validates and forwards to appropriate Durable Object
3. Durable Object saves message to D1
4. Durable Object broadcasts message to all connected users
5. Frontend receives message and updates UI

## API Endpoints

### Authentication Required for All Endpoints

### User Management
- `POST /api/users` - Create/update user profile from Clerk data
- `GET /api/users/me` - Get current user profile
- `PUT /api/users/me` - Update user profile

### Chat Rooms
- `GET /api/rooms` - List user's chat rooms
- `POST /api/rooms` - Create new chat room
- `GET /api/rooms/:id` - Get room details and recent messages
- `PUT /api/rooms/:id` - Update room (admin only)
- `DELETE /api/rooms/:id` - Delete room (admin only)
- `POST /api/rooms/:id/join` - Join public room
- `POST /api/rooms/:id/leave` - Leave room
- `POST /api/rooms/:id/invite` - Invite user to private room

### Messages
- `GET /api/rooms/:id/messages` - Get message history (pagination)
- `POST /api/rooms/:id/messages` - Send message
- `PUT /api/messages/:id` - Edit message (own messages only)
- `DELETE /api/messages/:id` - Delete message (own messages or admin)

### File Upload
- `POST /api/upload` - Upload file to Cloudflare R2, return URL

## WebSocket Events

### Client to Server
- `join_room` - Join a chat room
- `leave_room` - Leave a chat room
- `send_message` - Send a message
- `typing_start` - User started typing
- `typing_stop` - User stopped typing

### Server to Client
- `message_received` - New message in room
- `user_joined` - User joined room
- `user_left` - User left room
- `typing_indicator` - Someone is typing
- `presence_update` - User online/offline status

## Cloudflare KV Usage

### Session Cache
- Key: `session:{clerk_user_id}`
- Value: User session data, preferences
- TTL: 24 hours

### User Presence
- Key: `presence:{clerk_user_id}`
- Value: `{"online": true, "last_seen": "2024-01-01T12:00:00Z"}`
- TTL: 5 minutes (auto-refresh)

### Room Cache
- Key: `room:{room_id}:members`
- Value: Array of active room member IDs
- TTL: 1 hour

## Frontend Features

### Authentication Pages
- Sign in/up with Clerk components
- User profile management
- Protected route middleware

### Chat Interface
- Room list sidebar
- Real-time message display
- Message composition with file upload
- Typing indicators
- User presence indicators
- Message history loading (infinite scroll)

### Room Management
- Create new rooms (public/private)
- Join public rooms
- Invite users to private rooms
- Room settings (admin only)

## Security Considerations

### JWT Validation
- Verify Clerk JWT signature on every request
- Check token expiration
- Extract and validate user claims

### Authorization
- Users can only access rooms they're members of
- Message operations limited to message owners or room admins
- File uploads scoped to authenticated users

### Rate Limiting
- Implement message rate limiting per user
- File upload size and type restrictions
- API endpoint rate limiting

## Deployment Strategy

### Frontend (SvelteKit)
1. Build SvelteKit app with Clerk configuration
2. Deploy to Cloudflare Pages
3. Configure environment variables for Clerk

### Backend (Phoenix)
1. Configure Phoenix with Cloudflare API credentials
2. Set up Clerk JWT verification
3. Deploy to VPS/cloud provider or Cloudflare Workers

### Infrastructure Setup
1. Create Cloudflare D1 database and run migrations
2. Set up KV namespace for caching
3. Deploy Durable Objects for chat room coordination
4. Configure R2 bucket for file storage

## Environment Variables

### Frontend (.env)
```
PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
PUBLIC_API_BASE_URL=https://api.yourapp.com
PUBLIC_WS_URL=wss://api.yourapp.com/socket
```

### Backend (.env)
```
CLERK_SECRET_KEY=sk_test_...
CLERK_ISSUER_URL=https://your-app.clerk.accounts.dev
CLOUDFLARE_API_TOKEN=your_api_token
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_D1_DATABASE_ID=your_d1_db_id
CLOUDFLARE_KV_NAMESPACE_ID=your_kv_namespace_id
CLOUDFLARE_R2_BUCKET_NAME=your_r2_bucket
```

## Error Handling

### Frontend
- Network error handling with retry logic
- WebSocket reconnection on disconnect
- User-friendly error messages
- Loading states for all async operations

### Backend
- Graceful JWT validation failures
- Cloudflare service error handling
- WebSocket connection management
- Database transaction error handling

## Performance Optimizations

### Caching Strategy
- Room member lists in KV store
- User session data caching
- Message pagination for large rooms

### Real-time Optimizations
- Debounced typing indicators
- Message batching for high-volume rooms
- Efficient WebSocket connection management

### File Handling
- Direct uploads to R2 with signed URLs
- Image compression and resizing
- File type validation

## Future Enhancements

- Message reactions and threads
- Voice/video calling integration
- Message search functionality
- Push notifications
- Mobile app with shared backend
- Message encryption for private rooms
- Integration with external services (Slack, Discord)

## Testing Strategy

### Frontend Testing
- Component tests with Vitest
- E2E tests with Playwright
- Authentication flow testing

### Backend Testing
- Unit tests for API endpoints
- WebSocket connection testing
- JWT validation testing
- Cloudflare service integration tests

This specification provides a complete foundation for building a production-ready chat application with modern, serverless architecture and zero database maintenance overhead.
