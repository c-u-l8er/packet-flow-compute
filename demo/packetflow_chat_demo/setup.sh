#!/bin/bash

echo "🚀 Setting up PacketFlow Enterprise Chat Demo..."

# Function to check if PostgreSQL is running
check_postgresql() {
    if command -v pg_isready >/dev/null 2>&1; then
        if pg_isready -q; then
            echo "✅ PostgreSQL is running"
            return 0
        else
            echo "❌ PostgreSQL is not running"
            return 1
        fi
    else
        echo "❌ PostgreSQL is not installed"
        return 1
    fi
}

# Function to setup PostgreSQL
setup_postgresql() {
    echo "🗄️  Setting up PostgreSQL..."
    
    if ! check_postgresql; then
        echo "📋 PostgreSQL Setup Options:"
        echo "   1. Install PostgreSQL on Ubuntu/Debian: sudo apt-get update && sudo apt-get install postgresql postgresql-contrib"
        echo "   2. Install PostgreSQL on macOS: brew install postgresql"
        echo "   3. Use Docker: docker run --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres"
        echo "   4. Use existing PostgreSQL with custom credentials (set environment variables)"
        echo ""
        echo "🔧 Environment Variables (optional):"
        echo "   export DATABASE_USER=your_username"
        echo "   export DATABASE_PASSWORD=your_password"
        echo "   export DATABASE_HOST=localhost"
        echo "   export DATABASE_NAME=packetflow_chat_demo_dev"
        echo ""
        
        read -p "Do you want to continue with Docker PostgreSQL setup? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🐳 Starting PostgreSQL with Docker..."
            docker run --name packetflow-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15
            echo "⏳ Waiting for PostgreSQL to start..."
            sleep 5
        else
            echo "⚠️  Please set up PostgreSQL manually and run this script again."
            exit 1
        fi
    fi
}

# Check and setup PostgreSQL
setup_postgresql

# Install dependencies
echo "📦 Installing dependencies..."
mix deps.get

# Create database
echo "🗄️  Creating database..."
if ! mix ecto.create; then
    echo "❌ Failed to create database. Please check your PostgreSQL setup."
    echo ""
    echo "💡 Quick fixes:"
    echo "   1. Make sure PostgreSQL is running"
    echo "   2. Check your database credentials"
    echo "   3. Try: createuser -s postgres (if user doesn't exist)"
    echo "   4. Try: sudo -u postgres createuser -s $USER"
    echo ""
    exit 1
fi

# Run migrations
echo "🔄 Running database migrations..."
mix ecto.migrate

# Install Node.js dependencies for assets
echo "🎨 Installing frontend assets..."
if [ -d "assets" ]; then
    cd assets && npm install && cd ..
else
    echo "⚠️  No assets directory found, skipping npm install"
fi

# Compile assets
echo "🎯 Compiling assets..."
mix assets.deploy

echo "✅ Setup complete!"
echo ""
echo "🌟 To start the application:"
echo "   mix phx.server"
echo ""
echo "📖 Then visit: http://localhost:4000"
echo ""
echo "🔧 Configuration:"
echo "   - Set OPENAI_API_KEY environment variable for OpenAI integration"
echo "   - Set ANTHROPIC_API_KEY environment variable for Claude integration"
echo "   - Update config/dev.exs for database settings if needed"
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
