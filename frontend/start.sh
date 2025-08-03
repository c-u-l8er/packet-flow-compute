#!/bin/bash

echo "Starting PacketFlow Chat Frontend..."

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Start the development server
echo "Starting SvelteKit dev server on http://localhost:5173"
npm run dev -- --host