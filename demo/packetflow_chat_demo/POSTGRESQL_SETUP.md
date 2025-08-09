# PostgreSQL Setup Guide

## Quick Solutions for Database Authentication Error

### Option 1: Docker PostgreSQL (Easiest)
```bash
# Start PostgreSQL in Docker
docker run --name packetflow-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -d postgres:15

# Wait a few seconds, then continue with setup
./setup.sh
```

### Option 2: Use Your Existing PostgreSQL
If you have PostgreSQL installed but with different credentials:

```bash
# Set environment variables for your database
export DATABASE_USER=your_username
export DATABASE_PASSWORD=your_password
export DATABASE_HOST=localhost
export DATABASE_NAME=packetflow_chat_demo_dev

# Then run setup
./setup.sh
```

### Option 3: Install PostgreSQL Locally

#### Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# Create postgres user if needed
sudo -u postgres createuser -s postgres
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### macOS:
```bash
# Install via Homebrew
brew install postgresql
brew services start postgresql

# Create postgres user
createuser -s postgres
psql postgres -c "ALTER USER postgres PASSWORD 'postgres';"
```

#### Windows (WSL):
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo service postgresql start

# Set password for postgres user
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
```

### Option 4: Use Different Database Credentials
If you want to use your own database credentials, create a `.env` file:

```bash
# Create .env file
cat > .env << 'EOF'
DATABASE_USER=your_username
DATABASE_PASSWORD=your_password
DATABASE_HOST=localhost
DATABASE_NAME=packetflow_chat_demo_dev
DATABASE_POOL_SIZE=10
EOF

# Source the environment variables
source .env

# Run setup
./setup.sh
```

## Troubleshooting

### "FATAL 28P01 (invalid_password) password authentication failed"
- Check if PostgreSQL is running: `pg_isready`
- Verify credentials match your PostgreSQL setup
- Try connecting manually: `psql -U postgres -h localhost`

### "could not connect to server"
- PostgreSQL is not running
- Start with: `sudo service postgresql start` (Linux) or `brew services start postgresql` (macOS)

### "database does not exist"
- Run: `mix ecto.create` after PostgreSQL is set up

### "role does not exist"
- Create the postgres user: `sudo -u postgres createuser -s postgres`
- Or use your existing user credentials via environment variables

## Verification
Test your connection:
```bash
# This should work without errors
psql -U postgres -h localhost -c "SELECT version();"
```

## Next Steps
Once PostgreSQL is working:
1. Run `./setup.sh`
2. Start the app with `mix phx.server`
3. Visit `http://localhost:4000`
