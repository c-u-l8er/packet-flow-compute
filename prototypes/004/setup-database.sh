#!/bin/bash

echo "🗄️  Setting up PostgreSQL for PacketFlow Chat"
echo "=============================================="

# Check if PostgreSQL is installed
if ! command -v psql >/dev/null 2>&1; then
    echo "❌ PostgreSQL is not installed. Please install it first:"
    echo "   Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
    echo "   macOS: brew install postgresql"
    exit 1
fi

# Check and install missing Erlang packages for Phoenix
echo "Checking Erlang packages..."
if ! dpkg -l | grep -q erlang-xmerl; then
    echo "Installing missing Erlang packages..."
    sudo apt install -y erlang-xmerl erlang-eunit 2>/dev/null || echo "Could not install Erlang packages automatically"
fi

# Check if PostgreSQL is running
if ! pg_isready -q; then
    echo "❌ PostgreSQL is not running. Starting it..."
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl start postgresql
    elif command -v service >/dev/null 2>&1; then
        sudo service postgresql start
    elif command -v brew >/dev/null 2>&1; then
        brew services start postgresql
    else
        echo "Please start PostgreSQL manually and run this script again."
        exit 1
    fi
    
    # Wait a moment for PostgreSQL to start
    sleep 3
    
    if ! pg_isready -q; then
        echo "❌ Failed to start PostgreSQL. Please start it manually."
        exit 1
    fi
fi

echo "✅ PostgreSQL is running"

# Get the current user
CURRENT_USER=${USER:-$(whoami)}
echo "Setting up database for user: $CURRENT_USER"

# Try different approaches to create the user
echo "Creating database user..."

# Method 1: Try with sudo -u postgres
if sudo -u postgres createuser -s "$CURRENT_USER" 2>/dev/null; then
    echo "✅ Created database user '$CURRENT_USER' with superuser privileges"
elif sudo -u postgres psql -c "ALTER USER $CURRENT_USER CREATEDB;" 2>/dev/null; then
    echo "✅ Updated database user '$CURRENT_USER' with database creation privileges"
else
    echo "⚠️  Could not create/update database user. Trying alternative method..."
    
    # Method 2: Try direct psql connection
    if psql postgres -c "CREATE USER $CURRENT_USER WITH SUPERUSER;" 2>/dev/null; then
        echo "✅ Created database user '$CURRENT_USER' with superuser privileges"
    elif psql postgres -c "ALTER USER $CURRENT_USER CREATEDB;" 2>/dev/null; then
        echo "✅ Updated database user '$CURRENT_USER' with database creation privileges"
    else
        echo "⚠️  Could not automatically set up database user."
        echo "Please run one of these commands manually:"
        echo "  sudo -u postgres createuser -s $CURRENT_USER"
        echo "  OR"
        echo "  sudo -u postgres psql -c \"CREATE USER $CURRENT_USER WITH SUPERUSER;\""
    fi
fi

# Create a database for the user
echo "Creating user database..."
if sudo -u postgres createdb "$CURRENT_USER" 2>/dev/null; then
    echo "✅ Created database '$CURRENT_USER'"
elif createdb "$CURRENT_USER" 2>/dev/null; then
    echo "✅ Created database '$CURRENT_USER'"
else
    echo "ℹ️  Database '$CURRENT_USER' already exists or creation failed (this is usually OK)"
fi

# Test the connection
echo "Testing database connection..."
if psql -d postgres -c "SELECT version();" >/dev/null 2>&1; then
    echo "✅ Database connection successful!"
    echo ""
    echo "🎉 Database setup complete!"
    echo "You can now run: ./start-chat-app.sh"
else
    echo "❌ Database connection failed."
    echo ""
    echo "Manual setup instructions:"
    echo "1. Connect to PostgreSQL as the postgres user:"
    echo "   sudo -u postgres psql"
    echo ""
    echo "2. Create your user and grant permissions:"
    echo "   CREATE USER $CURRENT_USER WITH SUPERUSER;"
    echo "   \\q"
    echo ""
    echo "3. Try running this script again."
fi