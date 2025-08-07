#!/bin/bash

echo "🚀 Starting PacketFlow Chat Application"
echo "======================================"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "Checking prerequisites..."

if ! command_exists mix; then
    echo "❌ Elixir/Mix not found. Please install Elixir first."
    echo "   Ubuntu/Debian: sudo apt install elixir"
    echo "   macOS: brew install elixir"
    exit 1
fi

if ! command_exists node; then
    echo "❌ Node.js not found. Please install Node.js first."
    echo "   Visit: https://nodejs.org/"
    exit 1
fi

if ! command_exists npm; then
    echo "❌ npm not found. Please install npm first."
    exit 1
fi

# Check PostgreSQL
if ! command_exists psql; then
    echo "❌ PostgreSQL not found. Please install PostgreSQL first."
    echo "   Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
    echo "   macOS: brew install postgresql"
    exit 1
fi

if ! pg_isready -q 2>/dev/null; then
    echo "❌ PostgreSQL is not running. Please start PostgreSQL first."
    echo "   Ubuntu/Debian: sudo service postgresql start"
    echo "   macOS: brew services start postgresql"
    exit 1
fi

echo "✅ All prerequisites met!"
echo ""

# Create database user if needed
echo "Setting up database user..."
sudo -u postgres createuser -s $USER 2>/dev/null || echo "Database user already exists"

# Start backend in background
echo "🔧 Starting backend server..."
cd backend
./start.sh &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "⏳ Waiting for backend to start..."
sleep 10

# Check if backend is running
if ! curl -s http://localhost:4000 >/dev/null 2>&1; then
    echo "⚠️  Backend might not be ready yet, but continuing with frontend..."
fi

# Start frontend
echo "🎨 Starting frontend server..."
cd frontend
./start.sh &
FRONTEND_PID=$!
cd ..

echo ""
echo "🎉 PacketFlow Chat is starting up!"
echo "================================"
echo "📱 Frontend: http://localhost:5173"
echo "🔧 Backend:  http://localhost:4000"
echo "📊 Dashboard: http://localhost:4000/dev/dashboard (dev only)"
echo ""
echo "Press Ctrl+C to stop both servers"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down servers..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup INT TERM

# Wait for either process to exit
wait