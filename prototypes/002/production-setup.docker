# PacketFlow Production Docker Compose Setup
# This demonstrates a complete client-server architecture with multiple reactor types

version: '3.8'

services:
  # ============================================================================
  # INFRASTRUCTURE SERVICES
  # ============================================================================
  
  # Service Discovery
  consul:
    image: consul:1.15
    command: consul agent -dev -ui -client=0.0.0.0
    ports:
      - "8500:8500"
    environment:
      - CONSUL_BIND_INTERFACE=eth0
    volumes:
      - consul_data:/consul/data
    networks:
      - packetflow

  # Redis for caching and rate limiting
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - packetflow
    command: redis-server --appendonly yes

  # Monitoring
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - packetflow
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
      - ./config/grafana-dashboard.json:/var/lib/grafana/dashboards/packetflow.json
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=packetflow
    networks:
      - packetflow

  # ============================================================================
  # PACKETFLOW GATEWAY
  # ============================================================================
  
  gateway:
    build:
      context: ./gateway
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
      - "8081:8081"  # WebSocket port
    environment:
      - NODE_ENV=production
      - REDIS_URL=redis://redis:6379
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - API_KEYS=gateway-key-12345,client-key-67890
      - RATE_LIMIT=5000
      - LOG_LEVEL=info
    depends_on:
      - consul
      - redis
    networks:
      - packetflow
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  # ============================================================================
  # ELIXIR REACTOR CLUSTER (Control Flow & Fault Tolerance)
  # ============================================================================
  
  elixir-reactor-1:
    build:
      context: ./elixir
      dockerfile: Dockerfile
    ports:
      - "8443:8443"
    environment:
      - MIX_ENV=prod
      - ERLANG_COOKIE=packetflow-cluster-secret
      - NODE_NAME=elixir1@elixir-reactor-1
      - SPECIALIZATION=cf,co
      - MAX_CAPACITY=200
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=elixir-reactor-1
      - REACTOR_TAGS=elixir,cf,co,fault-tolerant
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'

  elixir-reactor-2:
    build:
      context: ./elixir
      dockerfile: Dockerfile
    ports:
      - "8453:8443"
    environment:
      - MIX_ENV=prod
      - ERLANG_COOKIE=packetflow-cluster-secret
      - NODE_NAME=elixir2@elixir-reactor-2
      - SPECIALIZATION=cf,co
      - MAX_CAPACITY=200
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=elixir-reactor-2
      - REACTOR_TAGS=elixir,cf,co,fault-tolerant
    depends_on:
      - consul
      - elixir-reactor-1
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'

  elixir-reactor-3:
    build:
      context: ./elixir
      dockerfile: Dockerfile
    ports:
      - "8463:8443"
    environment:
      - MIX_ENV=prod
      - ERLANG_COOKIE=packetflow-cluster-secret
      - NODE_NAME=elixir3@elixir-reactor-3
      - SPECIALIZATION=cf,co
      - MAX_CAPACITY=200
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=elixir-reactor-3
      - REACTOR_TAGS=elixir,cf,co,fault-tolerant
    depends_on:
      - consul
      - elixir-reactor-1
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'

  # ============================================================================
  # JAVASCRIPT REACTOR CLUSTER (Data Flow & Analytics)
  # ============================================================================
  
  js-reactor-1:
    build:
      context: ./javascript
      dockerfile: Dockerfile
    ports:
      - "8444:8444"
    environment:
      - NODE_ENV=production
      - SPECIALIZATION=df,mc
      - MAX_CAPACITY=150
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=js-reactor-1
      - REACTOR_TAGS=javascript,df,mc,analytics
      - UV_THREADPOOL_SIZE=16
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'

  js-reactor-2:
    build:
      context: ./javascript
      dockerfile: Dockerfile
    ports:
      - "8454:8444"
    environment:
      - NODE_ENV=production
      - SPECIALIZATION=df,mc
      - MAX_CAPACITY=150
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=js-reactor-2
      - REACTOR_TAGS=javascript,df,mc,analytics
      - UV_THREADPOOL_SIZE=16
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'

  js-reactor-3:
    build:
      context: ./javascript
      dockerfile: Dockerfile
    ports:
      - "8464:8444"
    environment:
      - NODE_ENV=production
      - SPECIALIZATION=df,mc
      - MAX_CAPACITY=150
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=js-reactor-3
      - REACTOR_TAGS=javascript,df,mc,analytics
      - UV_THREADPOOL_SIZE=16
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'

  js-reactor-4:
    build:
      context: ./javascript
      dockerfile: Dockerfile
    ports:
      - "8474:8444"
    environment:
      - NODE_ENV=production
      - SPECIALIZATION=df,mc
      - MAX_CAPACITY=150
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=js-reactor-4
      - REACTOR_TAGS=javascript,df,mc,analytics
      - UV_THREADPOOL_SIZE=16
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'

  # ============================================================================
  # ZIG REACTOR CLUSTER (Event Processing & Real-time)
  # ============================================================================
  
  zig-reactor-1:
    build:
      context: ./zig
      dockerfile: Dockerfile
    ports:
      - "8445:8445"
    environment:
      - SPECIALIZATION=ed,rm
      - MAX_CAPACITY=300
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=zig-reactor-1
      - REACTOR_TAGS=zig,ed,rm,realtime,low-latency
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.5'

  zig-reactor-2:
    build:
      context: ./zig
      dockerfile: Dockerfile
    ports:
      - "8455:8445"
    environment:
      - SPECIALIZATION=ed,rm
      - MAX_CAPACITY=300
      - CONSUL_HOST=consul
      - CONSUL_PORT=8500
      - REACTOR_ID=zig-reactor-2
      - REACTOR_TAGS=zig,ed,rm,realtime,low-latency
    depends_on:
      - consul
    networks:
      - packetflow
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.5'

  # ============================================================================
  # LOAD BALANCER & REVERSE PROXY
  # ============================================================================
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - gateway
    networks:
      - packetflow
    restart: unless-stopped

  # ============================================================================
  # SAMPLE CLIENT APPLICATIONS
  # ============================================================================
  
  # Web dashboard for monitoring
  dashboard:
    build:
      context: ./dashboard
      dockerfile: Dockerfile
    ports:
      - "3001:3000"
    environment:
      - REACT_APP_GATEWAY_URL=http://localhost:8080
      - REACT_APP_WS_URL=ws://localhost:8081
    depends_on:
      - gateway
    networks:
      - packetflow

  # CLI client for testing
  cli-client:
    build:
      context: ./cli-client
      dockerfile: Dockerfile
    environment:
      - GATEWAY_URL=http://gateway:8080
      - API_KEY=client-key-67890
    depends_on:
      - gateway
    networks:
      - packetflow
    profiles:
      - tools

  # Load testing client
  load-tester:
    build:
      context: ./load-tester
      dockerfile: Dockerfile
    environment:
      - GATEWAY_URL=http://gateway:8080
      - API_KEY=client-key-67890
      - CONCURRENT_USERS=100
      - TEST_DURATION=300s
    depends_on:
      - gateway
    networks:
      - packetflow
    profiles:
      - testing

# ============================================================================
# VOLUMES
# ============================================================================

volumes:
  consul_data:
    driver: local
  redis_data:
    driver: local
  prometheus_data:
    driver: local
  grafana_data:
    driver: local

# ============================================================================
# NETWORKS
# ============================================================================

networks:
  packetflow:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

---
# Additional configuration files referenced in docker-compose.yml

# config/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files: []

scrape_configs:
  - job_name: 'packetflow-gateway'
    static_configs:
      - targets: ['gateway:8080']
    metrics_path: '/metrics'
    scrape_interval: 5s

  - job_name: 'packetflow-elixir'
    consul_sd_configs:
      - server: 'consul:8500'
        services: ['packetflow-reactor']
        tags: ['elixir']
    relabel_configs:
      - source_labels: [__meta_consul_service_port]
        target_label: __address__
        replacement: '${1}'

  - job_name: 'packetflow-javascript'
    consul_sd_configs:
      - server: 'consul:8500'
        services: ['packetflow-reactor']
        tags: ['javascript']

  - job_name: 'packetflow-zig'
    consul_sd_configs:
      - server: 'consul:8500'
        services: ['packetflow-reactor']
        tags: ['zig']

---
# config/nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream gateway {
        least_conn;
        server gateway:8080;
    }

    upstream websocket {
        server gateway:8081;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name packetflow.local;
        return 301 https://$server_name$request_uri;
    }

    # Main HTTPS server
    server {
        listen 443 ssl http2;
        server_name packetflow.local;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

        # API routes
        location /api/ {
            proxy_pass http://gateway;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Enable CORS
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-API-Key";
        }

        # WebSocket upgrade
        location /ws {
            proxy_pass http://websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check
        location /health {
            proxy_pass http://gateway;
            access_log off;
        }

        # Metrics (restrict access)
        location /metrics {
            proxy_pass http://gateway;
            allow 172.20.0.0/16;  # Only internal network
            deny all;
        }

        # Dashboard
        location / {
            proxy_pass http://dashboard:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}

---
# config/grafana-datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

---
# Makefile for easy management
.PHONY: up down logs scale test clean

# Start the full stack
up:
	docker-compose up -d
	@echo "🚀 PacketFlow cluster starting..."
	@echo "🌐 Gateway: http://localhost:8080"
	@echo "📊 Grafana: http://localhost:3000 (admin/packetflow)"
	@echo "🔍 Consul: http://localhost:8500"
	@echo "📈 Prometheus: http://localhost:9090"

# Stop everything
down:
	docker-compose down -v

# Show logs
logs:
	docker-compose logs -f

# Scale reactors
scale-js:
	docker-compose up -d --scale js-reactor=6

scale-elixir:
	docker-compose up -d --scale elixir-reactor=5

scale-zig:
	docker-compose up -d --scale zig-reactor=4

# Run load tests
test:
	docker-compose --profile testing up load-tester

# Clean everything
clean:
	docker-compose down -v --rmi all
	docker system prune -f

# Development mode (with tools)
dev:
	docker-compose --profile tools up -d

# Health check
health:
	@echo "🏥 Cluster Health Check:"
	@curl -s http://localhost:8080/health | jq .
	@echo "\n📊 Reactor Status:"
	@curl -s http://localhost:8080/api/v1/cluster | jq .

# Example usage commands
demo:
	@echo "🧪 Running PacketFlow Demo..."
	@echo "Submitting Control Flow packet..."
	@curl -X POST http://localhost:8080/api/v1/packets \
		-H "Content-Type: application/json" \
		-H "X-API-Key: gateway-key-12345" \
		-d '{"group":"cf","element":"workflow","data":{"steps":["init","process","finalize"]},"priority":8}' | jq .
	
	@echo "\nSubmitting Data Flow packet..."
	@curl -X POST http://localhost:8080/api/v1/packets \
		-H "Content-Type: application/json" \
		-H "X-API-Key: gateway-key-12345" \
		-d '{"group":"df","element":"transform","data":{"input":"hello world","operation":"uppercase"},"priority":6}' | jq .
	
	@echo "\nSubmitting Event packet..."
	@curl -X POST http://localhost:8080/api/v1/packets \
		-H "Content-Type: application/json" \
		-H "X-API-Key: gateway-key-12345" \
		-d '{"group":"ed","element":"signal","data":{"event_type":"user_action","payload":{"user_id":"12345","action":"click"}},"priority":9}' | jq .

# Molecular workflow example
molecule-demo:
	@echo "🧬 Creating Molecular Workflow..."
	@curl -X POST http://localhost:8080/api/v1/molecules \
		-H "Content-Type: application/json" \
		-H "X-API-Key: gateway-key-12345" \
		-d '{
			"id": "user-onboarding-workflow",
			"packets": [
				{"group":"df","element":"validate","data":{"email":"user@example.com","age":25},"priority":8},
				{"group":"cf","element":"provision","data":{"user_id":"new_user_123","plan":"premium"},"priority":7},
				{"group":"ed","element":"notify","data":{"template":"welcome","user_id":"new_user_123"},"priority":6}
			],
			"bonds": [
				{"from_packet":"validate","to_packet":"provision","bond_type":"ionic"},
				{"from_packet":"provision","to_packet":"notify","bond_type":"ionic"}
			],
			"properties": {"workflow_type":"user_onboarding","timeout_ms":30000}
		}' | jq .

---
# docker-compose.override.yml (for development)
version: '3.8'

services:
  gateway:
    environment:
      - LOG_LEVEL=debug
    volumes:
      - ./gateway/src:/app/src
    command: npm run dev

  elixir-reactor-1:
    environment:
      - MIX_ENV=dev
    volumes:
      - ./elixir/lib:/app/lib

  js-reactor-1:
    environment:
      - NODE_ENV=development
    volumes:
      - ./javascript/src:/app/src
    command: npm run dev

  zig-reactor-1:
    volumes:
      - ./zig/src:/app/src

---
# kubernetes/namespace.yaml (for K8s deployment)
apiVersion: v1
kind: Namespace
metadata:
  name: packetflow
  labels:
    name: packetflow

---
# kubernetes/packetflow-gateway.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: packetflow-gateway
  namespace: packetflow
spec:
  replicas: 3
  selector:
    matchLabels:
      app: packetflow-gateway
  template:
    metadata:
      labels:
        app: packetflow-gateway
    spec:
      containers:
      - name: gateway
        image: packetflow/gateway:latest
        ports:
        - containerPort: 8080
        - containerPort: 8081
        env:
        - name: REDIS_URL
          value: "redis://redis-service:6379"
        - name: CONSUL_HOST
          value: "consul-service"
        - name: API_KEYS
          valueFrom:
            secretKeyRef:
              name: packetflow-secrets
              key: api-keys
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: packetflow-gateway-service
  namespace: packetflow
spec:
  selector:
    app: packetflow-gateway
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: websocket
    port: 8081
    targetPort: 8081
  type: LoadBalancer

---
# kubernetes/hpa.yaml (Horizontal Pod Autoscaler)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: packetflow-gateway-hpa
  namespace: packetflow
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: packetflow-gateway
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

---
# scripts/deploy.sh
#!/bin/bash

echo "🚀 Deploying PacketFlow Cluster..."

# Build all images
echo "📦 Building Docker images..."
docker-compose build

# Tag images for registry
docker tag packetflow_gateway:latest registry.example.com/packetflow/gateway:latest
docker tag packetflow_elixir-reactor-1:latest registry.example.com/packetflow/elixir:latest
docker tag packetflow_js-reactor-1:latest registry.example.com/packetflow/javascript:latest
docker tag packetflow_zig-reactor-1:latest registry.example.com/packetflow/zig:latest

# Push to registry
echo "📤 Pushing to registry..."
docker push registry.example.com/packetflow/gateway:latest
docker push registry.example.com/packetflow/elixir:latest
docker push registry.example.com/packetflow/javascript:latest
docker push registry.example.com/packetflow/zig:latest

# Deploy to Kubernetes
echo "☸️  Deploying to Kubernetes..."
kubectl apply -f kubernetes/

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/packetflow-gateway -n packetflow

echo "✅ Deployment complete!"
echo "🌐 Gateway URL: $(kubectl get service packetflow-gateway-service -n packetflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
