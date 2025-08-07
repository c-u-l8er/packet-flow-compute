#!/bin/bash

echo "Starting PacketFlow Chat Backend..."

# Check if PostgreSQL is running
if ! pg_isready -q; then
    echo "PostgreSQL is not running. Please start PostgreSQL first."
    echo "On Ubuntu/Debian: sudo service postgresql start"
    echo "On macOS with Homebrew: brew services start postgresql"
    exit 1
fi

# Set up database user and permissions
echo "Setting up database user..."
DB_USER=${DB_USERNAME:-${USER:-postgres}}

# Try to create database user if it doesn't exist
sudo -u postgres createuser -s "$DB_USER" 2>/dev/null || echo "Database user '$DB_USER' already exists or creation failed"

# Try to create database for the user
sudo -u postgres createdb "$DB_USER" 2>/dev/null || echo "Database '$DB_USER' already exists or creation failed"

# Install dependencies if needed
if [ ! -d "deps" ]; then
    echo "Installing dependencies..."
    mix deps.get
fi

# Compile if needed
if [ ! -d "_build" ]; then
    echo "Compiling application..."
    mix compile
fi

# Create database if it doesn't exist
echo "Setting up application database..."
mix ecto.create 2>/dev/null || echo "Application database already exists"

# Run migrations
echo "Running migrations..."
mix ecto.migrate

# Start the Phoenix server
echo "Starting Phoenix server on http://localhost:4000"
mix phx.server