# Use the official Elixir image as base
FROM elixir:1.14-alpine

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Install hex package manager
RUN mix local.hex --force

# Install rebar
RUN mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod

# Copy application code
COPY . .

# Compile the application
RUN mix compile

# Create release
RUN mix release

# Create a non-root user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

# Change ownership of the app directory
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 4000

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000
ENV HOST=0.0.0.0

# Start the application
CMD ["mix", "run", "--no-halt"]

