#!/bin/bash

echo "🚀 Setting up PacketFlow Enterprise Chat Demo with SQLite..."

# Install dependencies
echo "📦 Installing dependencies..."
mix deps.get

# Create and run migrations (SQLite will create the DB file automatically)
echo "🗄️  Setting up SQLite database..."
mix ecto.create

# Run migrations
echo "🔄 Running database migrations..."
mix ecto.migrate

# Install Node.js dependencies for assets (if assets directory exists)
if [ -d "assets" ]; then
    echo "🎨 Installing frontend assets..."
    cd assets && npm install && cd ..
    
    # Compile assets
    echo "🎯 Compiling assets..."
    mix assets.deploy
else
    echo "⚠️  No assets directory found, skipping asset compilation..."
fi

echo "✅ Setup complete!"
echo ""
echo "🌟 To start the application:"
echo "   mix phx.server"
echo ""
echo "📖 Then visit: http://localhost:4000"
echo ""
echo "💾 Database: Using SQLite (packetflow_chat_demo_dev.db)"
echo ""
echo "🔧 Configuration:"
echo "   - Set OPENAI_API_KEY environment variable for OpenAI integration"
echo "   - Set ANTHROPIC_API_KEY environment variable for Claude integration"
echo ""
echo "👥 Features included:"
echo "   ✅ Multi-tenant architecture"
echo "   ✅ Email/password/username authentication"
echo "   ✅ Role-based access control (Owner/Admin/Member)"
echo "   ✅ Multiple chat windows with tabs"
echo "   ✅ Model selection dropdown"
echo "   ✅ Custom API key configuration per tenant"
echo "   ✅ Enterprise-grade UI (Cursor-inspired)"
echo "   ✅ Real-time chat with Phoenix LiveView"
echo ""
