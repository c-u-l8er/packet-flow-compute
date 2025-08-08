# PacketFlow Chat Demo - LiveView Edition

This demo has been updated to use Phoenix LiveView with Temple syntax for a modern, real-time chat interface.

## Features

- **Real-time Chat Interface**: Built with Phoenix LiveView for instant message updates
- **Temple Syntax**: Uses Temple for declarative HTML generation in Elixir
- **PacketFlow Integration**: Demonstrates intent-context-capability patterns
- **Modern UI**: Beautiful interface with Tailwind CSS
- **Admin Panel**: Real-time configuration updates
- **Responsive Design**: Works on desktop and mobile devices

## Architecture

### LiveView Structure
- `ChatLive`: Main LiveView handling chat interactions
- `ChatComponent`: Temple components for reusable UI elements
- Real-time message updates via WebSocket connections

### Temple Integration
The demo includes both approaches:
1. **HEEx Templates**: Standard Phoenix templates (currently used)
2. **Temple Components**: Demonstrates Temple syntax for reusable components

### PacketFlow Integration
- Uses the existing `ChatSystem` and `ChatReactor`
- Maintains all intent-context-capability patterns
- Real-time communication with PacketFlow reactors

## Running the Demo

1. Install dependencies:
   ```bash
   mix deps.get
   ```

2. Install Node.js dependencies for assets:
   ```bash
   cd assets && npm install
   ```

3. Start the development server:
   ```bash
   mix phx.server
   ```

4. Visit `http://localhost:4000` in your browser

## Temple Syntax Examples

The demo includes Temple components in `lib/packetflow_chat_demo_web/components/chat_component.ex`:

```elixir
def message_bubble(assigns) do
  temple do
    div class: "flex #{if assigns.message.role == :user, do: 'justify-end', else: 'justify-start'}" do
      div class: "max-w-xs lg:max-w-md xl:max-w-lg 2xl:max-w-xl" do
        div class: "#{message_bubble_class(assigns.message.role)} p-3 rounded-lg" do
          p class: "text-sm" do
            assigns.message.content
          end
        end
      end
    end
  end
end
```

## Key Differences from Original

1. **Real-time Updates**: Messages appear instantly without page refreshes
2. **WebSocket Communication**: LiveView maintains persistent connections
3. **Temple Syntax**: Declarative HTML generation in Elixir
4. **Modern Asset Pipeline**: Uses esbuild and Tailwind CSS
5. **Better Error Handling**: Real-time error feedback
6. **Responsive Design**: Mobile-friendly interface

## Development

- **Hot Reload**: Changes to templates and LiveView code reload automatically
- **Asset Watching**: CSS and JS changes are automatically compiled
- **Live Dashboard**: Available at `/dev/dashboard` for monitoring

## Production Deployment

The application is ready for production deployment with:
- Optimized asset compilation
- Environment-specific configurations
- Proper error handling and logging
