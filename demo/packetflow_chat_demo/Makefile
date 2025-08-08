.PHONY: help install compile test run clean docker-build docker-run docker-stop

# Default target
help:
	@echo "PacketFlow LLM Chat Demo - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  install     - Install dependencies"
	@echo "  compile     - Compile the application"
	@echo "  test        - Run tests"
	@echo "  run         - Start the application"
	@echo "  clean       - Clean build artifacts"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run   - Run with Docker Compose"
	@echo "  docker-stop  - Stop Docker containers"
	@echo ""
	@echo "Utilities:"
	@echo "  format      - Format code"
	@echo "  dialyzer    - Run dialyzer analysis"
	@echo "  credo       - Run credo analysis"

# Development commands
install:
	mix deps.get

compile:
	mix compile

test:
	mix test

run:
	mix run --no-halt

clean:
	mix clean
	rm -rf _build

# Docker commands
docker-build:
	docker build -t packetflow-chat-demo .

docker-run:
	docker-compose up --build

docker-stop:
	docker-compose down

# Code quality
format:
	mix format

dialyzer:
	mix dialyzer

credo:
	mix credo

# Interactive development
iex:
	mix run --no-halt

# Documentation
docs:
	mix docs

# Release
release:
	mix release

# Production
prod-run:
	MIX_ENV=prod mix run --no-halt

# Development with hot reload
dev:
	mix run --no-halt --watch
