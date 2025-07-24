#!/usr/bin/env node

/**
 * PacketFlow Gateway Server
 * 
 * A production-ready gateway that coordinates multiple PacketFlow reactor clusters
 * with chemical affinity routing, load balancing, and service discovery.
 */

import express from 'express';
import WebSocket from 'ws';
import { createServer } from 'http';
import { v4 as uuidv4 } from 'uuid';
import Redis from 'ioredis';
import consul from 'consul';
import prometheus from 'prom-client';

// ============================================================================
// TYPES AND INTERFACES
// ============================================================================

interface PacketFlowConfig {
  gateway: {
    port: number;
    host: string;
    cors_origins: string[];
  };
  redis: {
    url: string;
    cluster?: boolean;
  };
  consul: {
    host: string;
    port: number;
  };
  security: {
    api_keys: string[];
    rate_limit_per_minute: number;
  };
  routing: {
    strategy: 'chemical_affinity' | 'round_robin' | 'least_connections';
    health_check_interval: number;
    failure_threshold: number;
  };
}

enum PacketGroup {
  CF = 'cf', // Control Flow
  DF = 'df', // Data Flow
  ED = 'ed', // Event Driven
  CO = 'co', // Collective
  MC = 'mc', // Meta-Computational
  RM = 'rm'  // Resource Management
}

enum NodeSpecialization {
  CPU_INTENSIVE = 'cpu_intensive',
  MEMORY_BOUND = 'memory_bound',
  IO_INTENSIVE = 'io_intensive',
  NETWORK_HEAVY = 'network_heavy',
  GENERAL_PURPOSE = 'general_purpose'
}

interface Packet {
  version: string;
  id: string;
  group: PacketGroup;
  element: string;
  data: any;
  priority: number;
  timeout_ms?: number;
  dependencies?: string[];
  metadata?: any;
  created_at: number;
}

interface ReactorEndpoint {
  id: string;
  name: string;
  implementation: 'elixir' | 'javascript' | 'zig';
  specializations: NodeSpecialization[];
  url: string;
  ws_url: string;
  health: ReactorHealth;
  connection?: WebSocket;
  last_heartbeat: number;
}

interface ReactorHealth {
  load_factor: number;        // 0.0 - 1.0
  queue_depth: number;        // pending packets
  error_rate: number;         // 0.0 - 1.0
  avg_latency_ms: number;     // average processing time
  uptime_seconds: number;     // reactor uptime
  is_healthy: boolean;        // overall health status
}

interface MoleculeSpec {
  id: string;
  packets: Packet[];
  bonds: ChemicalBond[];
  properties: { [key: string]: any };
}

interface ChemicalBond {
  from_packet: string;
  to_packet: string;
  bond_type: 'ionic' | 'covalent' | 'metallic' | 'vdw';
  strength: number;
}

// ============================================================================
// CHEMICAL AFFINITY MATRIX
// ============================================================================

const AFFINITY_MATRIX: { [key in PacketGroup]: { [key in NodeSpecialization]: number } } = {
  [PacketGroup.CF]: {
    [NodeSpecialization.CPU_INTENSIVE]: 0.9,
    [NodeSpecialization.MEMORY_BOUND]: 0.4,
    [NodeSpecialization.IO_INTENSIVE]: 0.3,
    [NodeSpecialization.NETWORK_HEAVY]: 0.2,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.6
  },
  [PacketGroup.DF]: {
    [NodeSpecialization.CPU_INTENSIVE]: 0.8,
    [NodeSpecialization.MEMORY_BOUND]: 0.9,
    [NodeSpecialization.IO_INTENSIVE]: 0.7,
    [NodeSpecialization.NETWORK_HEAVY]: 0.6,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.8
  },
  [PacketGroup.ED]: {
    [NodeSpecialization.CPU_INTENSIVE]: 0.3,
    [NodeSpecialization.MEMORY_BOUND]: 0.2,
    [NodeSpecialization.IO_INTENSIVE]: 0.9,
    [NodeSpecialization.NETWORK_HEAVY]: 0.8,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.6
  },
  [PacketGroup.CO]: {
    [NodeSpecialization.CPU_INTENSIVE]: 0.4,
    [NodeSpecialization.MEMORY_BOUND]: 0.6,
    [NodeSpecialization.IO_INTENSIVE]: 0.8,
    [NodeSpecialization.NETWORK_HEAVY]: 0.9,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.7
  },
  [PacketGroup.MC]: {
    [NodeSpecialization.CPU_INTENSIVE]: 0.6,
    [NodeSpecialization.MEMORY_BOUND]: 0.7,
    [NodeSpecialization.IO_INTENSIVE]: 0.5,
    [NodeSpecialization.NETWORK_HEAVY]: 0.6,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.8
  },
  [PacketGroup.RM]: {
    [NodeSpecialization.CPU_INTENSIVE]: 0.5,
    [NodeSpecialization.MEMORY_BOUND]: 0.9,
    [NodeSpecialization.IO_INTENSIVE]: 0.4,
    [NodeSpecialization.NETWORK_HEAVY]: 0.3,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.7
  }
};

// ============================================================================
// PROMETHEUS METRICS
// ============================================================================

const metrics = {
  gateway_requests_total: new prometheus.Counter({
    name: 'packetflow_gateway_requests_total',
    help: 'Total number of requests to the gateway',
    labelNames: ['method', 'route', 'status']
  }),
  packets_routed_total: new prometheus.Counter({
    name: 'packetflow_packets_routed_total', 
    help: 'Total number of packets routed',
    labelNames: ['group', 'element', 'reactor']
  }),
  chemical_affinity_score: new prometheus.Histogram({
    name: 'packetflow_chemical_affinity_score',
    help: 'Chemical affinity scores for routing decisions',
    labelNames: ['packet_group', 'reactor_spec'],
    buckets: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
  }),
  reactor_health: new prometheus.Gauge({
    name: 'packetflow_reactor_health',
    help: 'Health status of reactors',
    labelNames: ['reactor_id', 'implementation']
  }),
  packet_processing_duration: new prometheus.Histogram({
    name: 'packetflow_packet_processing_duration_ms',
    help: 'Time taken to process packets',
    labelNames: ['group', 'element'],
    buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000]
  })
};

// ============================================================================
// SERVICE DISCOVERY
// ============================================================================

class ServiceDiscovery {
  private consul: any;
  private reactors = new Map<string, ReactorEndpoint>();
  private gateway: PacketFlowGateway;

  constructor(consulConfig: any, gateway: PacketFlowGateway) {
    this.consul = consul({
      host: consulConfig.host,
      port: consulConfig.port,
      promisify: true
    });
    this.gateway = gateway;
  }

  async start() {
    console.log('🔍 Starting service discovery...');
    
    // Watch for reactor services
    const watcher = this.consul.watch({
      method: this.consul.health.service,
      options: {
        service: 'packetflow-reactor',
        passing: true
      }
    });

    watcher.on('change', (data: any) => {
      this.updateReactorRegistry(data);
    });

    watcher.on('error', (err: Error) => {
      console.error('❌ Service discovery error:', err);
    });

    // Initial discovery
    try {
      const services = await this.consul.health.service('packetflow-reactor');
      this.updateReactorRegistry(services);
    } catch (error) {
      console.error('❌ Initial service discovery failed:', error);
    }
  }

  private updateReactorRegistry(services: any[]) {
    const discoveredReactors = new Set<string>();

    for (const service of services) {
      const reactorId = service.Service.ID;
      const tags = service.Service.Tags || [];
      
      const reactor: ReactorEndpoint = {
        id: reactorId,
        name: service.Service.Service,
        implementation: this.detectImplementation(tags),
        specializations: this.parseSpecializations(tags),
        url: `http://${service.Service.Address}:${service.Service.Port}`,
        ws_url: `ws://${service.Service.Address}:${service.Service.Port}`,
        health: {
          load_factor: 0.0,
          queue_depth: 0,
          error_rate: 0.0,
          avg_latency_ms: 0,
          uptime_seconds: 0,
          is_healthy: true
        },
        last_heartbeat: Date.now()
      };

      if (!this.reactors.has(reactorId)) {
        console.log(`✅ Discovered reactor: ${reactorId} (${reactor.implementation})`);
        this.reactors.set(reactorId, reactor);
        this.gateway.connectToReactor(reactor);
      }

      discoveredReactors.add(reactorId);
    }

    // Remove reactors that are no longer available
    for (const [reactorId, reactor] of this.reactors) {
      if (!discoveredReactors.has(reactorId)) {
        console.log(`❌ Reactor unavailable: ${reactorId}`);
        this.gateway.disconnectFromReactor(reactor);
        this.reactors.delete(reactorId);
      }
    }
  }

  private detectImplementation(tags: string[]): 'elixir' | 'javascript' | 'zig' {
    if (tags.includes('elixir')) return 'elixir';
    if (tags.includes('javascript') || tags.includes('js')) return 'javascript';
    if (tags.includes('zig')) return 'zig';
    return 'javascript'; // default
  }

  private parseSpecializations(tags: string[]): NodeSpecialization[] {
    const specs: NodeSpecialization[] = [];
    
    for (const tag of tags) {
      if (Object.values(NodeSpecialization).includes(tag as NodeSpecialization)) {
        specs.push(tag as NodeSpecialization);
      }
    }
    
    return specs.length > 0 ? specs : [NodeSpecialization.GENERAL_PURPOSE];
  }

  getHealthyReactors(): ReactorEndpoint[] {
    return Array.from(this.reactors.values())
      .filter(reactor => reactor.health.is_healthy);
  }

  getReactorsBySpecialization(spec: NodeSpecialization): ReactorEndpoint[] {
    return this.getHealthyReactors()
      .filter(reactor => reactor.specializations.includes(spec));
  }
}

// ============================================================================
// CHEMICAL LOAD BALANCER
// ============================================================================

class ChemicalLoadBalancer {
  private serviceDiscovery: ServiceDiscovery;

  constructor(serviceDiscovery: ServiceDiscovery) {
    this.serviceDiscovery = serviceDiscovery;
  }

  route(packet: Packet): ReactorEndpoint | null {
    const candidates = this.getCandidateReactors(packet);
    
    if (candidates.length === 0) {
      return null;
    }

    // Score each candidate based on chemical affinity and current load
    const scoredCandidates = candidates.map(reactor => ({
      reactor,
      score: this.calculateAffinityScore(packet, reactor)
    }));

    // Sort by score (highest first)
    scoredCandidates.sort((a, b) => b.score - a.score);

    const selected = scoredCandidates[0];
    
    // Record metrics
    metrics.chemical_affinity_score
      .labels(packet.group, selected.reactor.specializations[0])
      .observe(selected.score);

    return selected.reactor;
  }

  private getCandidateReactors(packet: Packet): ReactorEndpoint[] {
    const healthyReactors = this.serviceDiscovery.getHealthyReactors();
    
    // Filter reactors that can handle this packet type
    return healthyReactors.filter(reactor => {
      // Check if reactor has capacity
      if (reactor.health.load_factor > 0.9) return false;
      
      // Check if reactor supports this packet group (simplified)
      return true; // In production, check actual capabilities
    });
  }

  private calculateAffinityScore(packet: Packet, reactor: ReactorEndpoint): number {
    // Get chemical affinity for primary specialization
    const primarySpec = reactor.specializations[0] || NodeSpecialization.GENERAL_PURPOSE;
    const chemicalAffinity = AFFINITY_MATRIX[packet.group][primarySpec];
    
    // Load factor (prefer less loaded reactors)
    const loadFactor = 1.0 - reactor.health.load_factor;
    
    // Health bonus
    const healthBonus = reactor.health.is_healthy ? 1.1 : 0.5;
    
    // Priority weight
    const priorityWeight = packet.priority / 10.0;
    
    // Implementation preferences for specific packet types
    let implementationBonus = 1.0;
    if (packet.group === PacketGroup.CF && reactor.implementation === 'elixir') {
      implementationBonus = 1.3; // Elixir excels at control flow
    } else if (packet.group === PacketGroup.DF && reactor.implementation === 'javascript') {
      implementationBonus = 1.2; // JavaScript good for data flow
    } else if (packet.group === PacketGroup.ED && reactor.implementation === 'zig') {
      implementationBonus = 1.4; // Zig excellent for events
    }

    // Recent performance factor
    const latencyFactor = reactor.health.avg_latency_ms > 0 
      ? Math.max(0.1, 1.0 - (reactor.health.avg_latency_ms / 1000.0))
      : 1.0;

    return chemicalAffinity * loadFactor * healthBonus * priorityWeight * implementationBonus * latencyFactor;
  }
}

// ============================================================================
// RATE LIMITER
// ============================================================================

class RateLimiter {
  private redis: Redis;
  private limits: Map<string, { count: number; window: number }>;

  constructor(redis: Redis) {
    this.redis = redis;
    this.limits = new Map();
  }

  async checkLimit(key: string, limit: number, windowMs: number): Promise<boolean> {
    const now = Date.now();
    const windowStart = now - windowMs;
    
    // Use Redis sliding window
    const pipeline = this.redis.pipeline();
    pipeline.zremrangebyscore(key, 0, windowStart);
    pipeline.zadd(key, now, `${now}-${Math.random()}`);
    pipeline.zcard(key);
    pipeline.expire(key, Math.ceil(windowMs / 1000));
    
    const results = await pipeline.exec();
    const count = results?.[2]?.[1] as number || 0;
    
    return count <= limit;
  }
}

// ============================================================================
// MOLECULAR ORCHESTRATOR
// ============================================================================

class MolecularOrchestrator {
  private gateway: PacketFlowGateway;
  private activeMolecules = new Map<string, MoleculeExecution>();

  constructor(gateway: PacketFlowGateway) {
    this.gateway = gateway;
  }

  async executeMolecule(spec: MoleculeSpec): Promise<any> {
    console.log(`🧬 Executing molecule: ${spec.id}`);
    
    const execution = new MoleculeExecution(spec, this.gateway);
    this.activeMolecules.set(spec.id, execution);
    
    try {
      const result = await execution.execute();
      return result;
    } finally {
      this.activeMolecules.delete(spec.id);
    }
  }

  getMoleculeStatus(moleculeId: string) {
    return this.activeMolecules.get(moleculeId)?.getStatus();
  }

  cancelMolecule(moleculeId: string) {
    const execution = this.activeMolecules.get(moleculeId);
    if (execution) {
      execution.cancel();
      this.activeMolecules.delete(moleculeId);
    }
  }
}

class MoleculeExecution {
  private spec: MoleculeSpec;
  private gateway: PacketFlowGateway;
  private packetResults = new Map<string, any>();
  private cancelled = false;

  constructor(spec: MoleculeSpec, gateway: PacketFlowGateway) {
    this.spec = spec;
    this.gateway = gateway;
  }

  async execute(): Promise<any> {
    // Build dependency graph
    const dependencyGraph = this.buildDependencyGraph();
    
    // Execute packets in dependency order
    const executionPlan = this.createExecutionPlan(dependencyGraph);
    
    for (const stage of executionPlan) {
      if (this.cancelled) throw new Error('Molecule execution cancelled');
      
      // Execute packets in parallel within each stage
      const stageResults = await Promise.all(
        stage.map(packet => this.executePacket(packet))
      );
      
      // Store results
      stage.forEach((packet, i) => {
        this.packetResults.set(packet.id, stageResults[i]);
      });
    }
    
    return this.aggregateResults();
  }

  private buildDependencyGraph(): Map<string, string[]> {
    const graph = new Map<string, string[]>();
    
    // Initialize all packets
    for (const packet of this.spec.packets) {
      graph.set(packet.id, []);
    }
    
    // Add dependencies from bonds
    for (const bond of this.spec.bonds) {
      const dependencies = graph.get(bond.to_packet) || [];
      dependencies.push(bond.from_packet);
      graph.set(bond.to_packet, dependencies);
    }
    
    return graph;
  }

  private createExecutionPlan(dependencyGraph: Map<string, string[]>): Packet[][] {
    const plan: Packet[][] = [];
    const executed = new Set<string>();
    const remaining = new Set(this.spec.packets.map(p => p.id));
    
    while (remaining.size > 0) {
      const currentStage: Packet[] = [];
      
      for (const packetId of remaining) {
        const dependencies = dependencyGraph.get(packetId) || [];
        const canExecute = dependencies.every(dep => executed.has(dep));
        
        if (canExecute) {
          const packet = this.spec.packets.find(p => p.id === packetId)!;
          currentStage.push(packet);
        }
      }
      
      if (currentStage.length === 0) {
        throw new Error('Circular dependency detected in molecule');
      }
      
      plan.push(currentStage);
      
      // Mark as executed
      for (const packet of currentStage) {
        executed.add(packet.id);
        remaining.delete(packet.id);
      }
    }
    
    return plan;
  }

  private async executePacket(packet: Packet): Promise<any> {
    return await this.gateway.submitPacket(packet);
  }

  private aggregateResults(): any {
    return {
      molecule_id: this.spec.id,
      packets_executed: this.packetResults.size,
      results: Object.fromEntries(this.packetResults),
      properties: this.spec.properties
    };
  }

  cancel() {
    this.cancelled = true;
  }

  getStatus() {
    return {
      molecule_id: this.spec.id,
      packets_total: this.spec.packets.length,
      packets_completed: this.packetResults.size,
      cancelled: this.cancelled
    };
  }
}

// ============================================================================
// MAIN GATEWAY CLASS
// ============================================================================

class PacketFlowGateway {
  private config: PacketFlowConfig;
  private app: express.Application;
  private server: any;
  private wss: WebSocket.Server;
  private redis: Redis;
  private serviceDiscovery: ServiceDiscovery;
  private loadBalancer: ChemicalLoadBalancer;
  private rateLimiter: RateLimiter;
  private molecularOrchestrator: MolecularOrchestrator;
  private reactorConnections = new Map<string, WebSocket>();
  private pendingRequests = new Map<string, { resolve: Function; reject: Function; timeout: any }>();

  constructor(config: PacketFlowConfig) {
    this.config = config;
    this.app = express();
    this.redis = new Redis(config.redis.url);
    this.serviceDiscovery = new ServiceDiscovery(config.consul, this);
    this.loadBalancer = new ChemicalLoadBalancer(this.serviceDiscovery);
    this.rateLimiter = new RateLimiter(this.redis);
    this.molecularOrchestrator = new MolecularOrchestrator(this);
    
    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware() {
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));
    
    // CORS
    this.app.use((req, res, next) => {
      const origin = req.headers.origin;
      if (this.config.gateway.cors_origins.includes(origin || '')) {
        res.header('Access-Control-Allow-Origin', origin);
      }
      res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-Key');
      next();
    });

    // API Key authentication
    this.app.use('/api', async (req, res, next) => {
      const apiKey = req.headers['x-api-key'] as string;
      
      if (!apiKey || !this.config.security.api_keys.includes(apiKey)) {
        return res.status(401).json({ error: 'Invalid API key' });
      }

      // Rate limiting
      const canProceed = await this.rateLimiter.checkLimit(
        `api_key:${apiKey}`,
        this.config.security.rate_limit_per_minute,
        60000
      );

      if (!canProceed) {
        return res.status(429).json({ error: 'Rate limit exceeded' });
      }

      next();
    });

    // Metrics middleware
    this.app.use((req, res, next) => {
      const start = Date.now();
      
      res.on('finish', () => {
        const duration = Date.now() - start;
        metrics.gateway_requests_total
          .labels(req.method, req.route?.path || req.path, res.statusCode.toString())
          .inc();
      });
      
      next();
    });
  }

  private setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      const healthyReactors = this.serviceDiscovery.getHealthyReactors();
      res.json({
        status: 'healthy',
        version: '1.0.0',
        reactors: {
          total: healthyReactors.length,
          healthy: healthyReactors.filter(r => r.health.is_healthy).length
        },
        uptime: process.uptime()
      });
    });

    // Metrics endpoint
    this.app.get('/metrics', async (req, res) => {
      res.set('Content-Type', prometheus.register.contentType);
      const metrics = await prometheus.register.metrics();
      res.send(metrics);
    });

    // Submit single packet
    this.app.post('/api/v1/packets', async (req, res) => {
      try {
        const packet = this.validatePacket(req.body);
        const result = await this.submitPacket(packet);
        
        metrics.packets_routed_total
          .labels(packet.group, packet.element, 'http')
          .inc();
          
        res.json(result);
      } catch (error) {
        res.status(400).json({ 
          error: 'Invalid packet', 
          message: error instanceof Error ? error.message : 'Unknown error' 
        });
      }
    });

    // Submit molecule
    this.app.post('/api/v1/molecules', async (req, res) => {
      try {
        const moleculeSpec = this.validateMolecule(req.body);
        const result = await this.molecularOrchestrator.executeMolecule(moleculeSpec);
        res.json(result);
      } catch (error) {
        res.status(400).json({ 
          error: 'Invalid molecule', 
          message: error instanceof Error ? error.message : 'Unknown error' 
        });
      }
    });

    // Get molecule status
    this.app.get('/api/v1/molecules/:id', (req, res) => {
      const status = this.molecularOrchestrator.getMoleculeStatus(req.params.id);
      if (status) {
        res.json(status);
      } else {
        res.status(404).json({ error: 'Molecule not found' });
      }
    });

    // Cancel molecule
    this.app.delete('/api/v1/molecules/:id', (req, res) => {
      this.molecularOrchestrator.cancelMolecule(req.params.id);
      res.json({ message: 'Molecule cancelled' });
    });

    // Get cluster status
    this.app.get('/api/v1/cluster', (req, res) => {
      const reactors = this.serviceDiscovery.getHealthyReactors();
      
      res.json({
        total_reactors: reactors.length,
        healthy_reactors: reactors.filter(r => r.health.is_healthy).length,
        implementations: {
          elixir: reactors.filter(r => r.implementation === 'elixir').length,
          javascript: reactors.filter(r => r.implementation === 'javascript').length,
          zig: reactors.filter(r => r.implementation === 'zig').length
        },
        specializations: this.getSpecializationCounts(reactors),
        average_load: this.calculateAverageLoad(reactors)
      });
    });
  }

  private validatePacket(data: any): Packet {
    if (!data.group || !Object.values(PacketGroup).includes(data.group)) {
      throw new Error('Invalid packet group');
    }
    
    if (!data.element || typeof data.element !== 'string') {
      throw new Error('Invalid packet element');
    }

    return {
      version: '1.0',
      id: data.id || uuidv4(),
      group: data.group as PacketGroup,
      element: data.element,
      data: data.data,
      priority: Math.max(1, Math.min(10, data.priority || 5)),
      timeout_ms: data.timeout_ms,
      dependencies: data.dependencies,
      metadata: data.metadata,
      created_at: Date.now()
    };
  }

  private validateMolecule(data: any): MoleculeSpec {
    if (!data.id || typeof data.id !== 'string') {
      throw new Error('Invalid molecule ID');
    }

    if (!Array.isArray(data.packets)) {
      throw new Error('Molecule must have packets array');
    }

    const packets = data.packets.map((p: any) => this.validatePacket(p));
    const bonds = (data.bonds || []).map((b: any) => ({
      from_packet: b.from_packet,
      to_packet: b.to_packet,
      bond_type: b.bond_type || 'ionic',
      strength: b.strength || 1.0
    }));

    return {
      id: data.id,
      packets,
      bonds,
      properties: data.properties || {}
    };
  }

  async submitPacket(packet: Packet): Promise<any> {
    const startTime = Date.now();
    
    // Route packet to optimal reactor
    const reactor = this.loadBalancer.route(packet);
    if (!reactor) {
      throw new Error('No available reactors');
    }

    // Submit packet via WebSocket
    return new Promise((resolve, reject) => {
      const requestId = uuidv4();
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(requestId);
        reject(new Error('Request timeout'));
      }, packet.timeout_ms || 30000);

      this.pendingRequests.set(requestId, { resolve, reject, timeout });

      const message = {
        type: 'submit',
        seq: parseInt(requestId.replace(/-/g, '').slice(0, 8), 16),
        payload: packet,
        request_id: requestId
      };

      const connection = this.reactorConnections.get(reactor.id);
      if (connection && connection.readyState === WebSocket.OPEN) {
        connection.send(JSON.stringify(message));
        
        metrics.packets_routed_total
          .labels(packet.group, packet.element, reactor.id)
          .inc();
      } else {
        clearTimeout(timeout);
        this.pendingRequests.delete(requestId);
        reject(new Error('Reactor connection unavailable'));
      }
    });
  }

  connectToReactor(reactor: ReactorEndpoint) {
    console.log(`🔗 Connecting to reactor: ${reactor.id}`);
    
    const ws = new WebSocket(reactor.ws_url);
    
    ws.on('open', () => {
      console.log(`✅ Connected to reactor: ${reactor.id}`);
      reactor.connection = ws;
      this.reactorConnections.set(reactor.id, ws);
      
      // Update metrics
      metrics.reactor_health
        .labels(reactor.id, reactor.implementation)
        .set(1);
    });

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        this.handleReactorMessage(reactor, message);
      } catch (error) {
        console.error(`❌ Failed to parse message from ${reactor.id}:`, error);
      }
    });

    ws.on('close', () => {
      console.log(`📤 Disconnected from reactor: ${reactor.id}`);
      this.reactorConnections.delete(reactor.id);
      
      // Update metrics
      metrics.reactor_health
        .labels(reactor.id, reactor.implementation)
        .set(0);
    });

    ws.on('error', (error) => {
      console.error(`❌ Reactor connection error ${reactor.id}:`, error);
    });
  }

  disconnectFromReactor(reactor: ReactorEndpoint) {
    const connection = this.reactorConnections.get(reactor.id);
    if (connection) {
      connection.close();
      this.reactorConnections.delete(reactor.id);
    }
  }

  private handleReactorMessage(reactor: ReactorEndpoint, message: any) {
    const { type, payload, request_id } = message;

    switch (type) {
      case 'result':
      case 'error':
        if (request_id) {
          const pending = this.pendingRequests.get(request_id);
          if (pending) {
            clearTimeout(pending.timeout);
            this.pendingRequests.delete(request_id);
            
            if (type === 'result') {
              // Record processing duration
              if (payload.duration_ms) {
                metrics.packet_processing_duration
                  .labels(payload.group || 'unknown', payload.element || 'unknown')
                  .observe(payload.duration_ms);
              }
              pending.resolve(payload);
            } else {
              pending.reject(new Error(payload.error?.message || 'Processing failed'));
            }
          }
        }
        break;

      case 'heartbeat':
        this.updateReactorHealth(reactor, payload);
        break;

      default:
        console.log(`📨 Unknown message type from ${reactor.id}: ${type}`);
    }
  }

  private updateReactorHealth(reactor: ReactorEndpoint, healthData: any) {
    reactor.last_heartbeat = Date.now();
    
    if (healthData.system_health) {
      reactor.health = {
        load_factor: 1.0 - (healthData.system_health.overall_health || 0),
        queue_depth: healthData.queue_depth || 0,
        error_rate: healthData.error_rate || 0,
        avg_latency_ms: healthData.avg_latency_ms || 0,
        uptime_seconds: healthData.uptime_seconds || 0,
        is_healthy: healthData.system_health.overall_health > 0.5
      };

      // Update metrics
      metrics.reactor_health
        .labels(reactor.id, reactor.implementation)
        .set(reactor.health.is_healthy ? 1 : 0);
    }
  }

  private getSpecializationCounts(reactors: ReactorEndpoint[]) {
    const counts: { [key: string]: number } = {};
    
    for (const reactor of reactors) {
      for (const spec of reactor.specializations) {
        counts[spec] = (counts[spec] || 0) + 1;
      }
    }
    
    return counts;
  }

  private calculateAverageLoad(reactors: ReactorEndpoint[]): number {
    if (reactors.length === 0) return 0;
    
    const totalLoad = reactors.reduce((sum, r) => sum + r.health.load_factor, 0);
    return totalLoad / reactors.length;
  }

  async start() {
    // Start HTTP server
    this.server = createServer(this.app);
    
    // Setup WebSocket server for client connections
    this.wss = new WebSocket.Server({ 
      server: this.server,
      path: '/ws'
    });

    this.wss.on('connection', (ws, req) => {
      console.log('🔗 Client WebSocket connected');
      
      ws.on('message', async (data) => {
        try {
          const message = JSON.parse(data.toString());
          await this.handleClientMessage(ws, message);
        } catch (error) {
          ws.send(JSON.stringify({
            type: 'error',
            error: { 
              code: 'INVALID_MESSAGE', 
              message: 'Invalid message format' 
            }
          }));
        }
      });

      ws.on('close', () => {
        console.log('📤 Client WebSocket disconnected');
      });
    });

    // Start service discovery
    await this.serviceDiscovery.start();

    // Start server
    this.server.listen(this.config.gateway.port, this.config.gateway.host, () => {
      console.log(`🌐 PacketFlow Gateway listening on ${this.config.gateway.host}:${this.config.gateway.port}`);
      console.log(`📊 Metrics available at http://${this.config.gateway.host}:${this.config.gateway.port}/metrics`);
    });
  }

  private async handleClientMessage(ws: WebSocket, message: any) {
    const { type, seq, payload } = message;

    try {
      switch (type) {
        case 'submit':
          const packet = this.validatePacket(payload);
          const result = await this.submitPacket(packet);
          ws.send(JSON.stringify({
            type: 'result',
            seq,
            payload: result
          }));
          break;

        case 'heartbeat':
          ws.send(JSON.stringify({
            type: 'heartbeat',
            seq,
            payload: {
              timestamp: Date.now(),
              cluster_status: this.getClusterStatus()
            }
          }));
          break;

        default:
          ws.send(JSON.stringify({
            type: 'error',
            seq,
            error: {
              code: 'UNKNOWN_MESSAGE_TYPE',
              message: `Unknown message type: ${type}`
            }
          }));
      }
    } catch (error) {
      ws.send(JSON.stringify({
        type: 'error',
        seq,
        error: {
          code: 'PROCESSING_ERROR',
          message: error instanceof Error ? error.message : 'Unknown error'
        }
      }));
    }
  }

  private getClusterStatus() {
    const reactors = this.serviceDiscovery.getHealthyReactors();
    return {
      total_reactors: reactors.length,
      healthy_reactors: reactors.filter(r => r.health.is_healthy).length,
      average_load: this.calculateAverageLoad(reactors)
    };
  }

  async stop() {
    console.log('🛑 Stopping PacketFlow Gateway...');
    
    // Close all reactor connections
    for (const connection of this.reactorConnections.values()) {
      connection.close();
    }
    
    // Close WebSocket server
    this.wss.close();
    
    // Close HTTP server
    if (this.server) {
      this.server.close();
    }
    
    // Close Redis connection
    this.redis.disconnect();
  }
}

// ============================================================================
// CONFIGURATION AND STARTUP
// ============================================================================

const DEFAULT_CONFIG: PacketFlowConfig = {
  gateway: {
    port: 8080,
    host: '0.0.0.0',
    cors_origins: ['http://localhost:3000', 'https://app.example.com']
  },
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  },
  consul: {
    host: process.env.CONSUL_HOST || 'localhost',
    port: parseInt(process.env.CONSUL_PORT || '8500')
  },
  security: {
    api_keys: (process.env.API_KEYS || 'dev-key-12345').split(','),
    rate_limit_per_minute: parseInt(process.env.RATE_LIMIT || '1000')
  },
  routing: {
    strategy: 'chemical_affinity',
    health_check_interval: 10000,
    failure_threshold: 3
  }
};

async function main() {
  console.log('🧪 Starting PacketFlow Gateway...');
  
  const gateway = new PacketFlowGateway(DEFAULT_CONFIG);
  
  // Graceful shutdown
  process.on('SIGTERM', async () => {
    console.log('Received SIGTERM, shutting down gracefully...');
    await gateway.stop();
    process.exit(0);
  });

  process.on('SIGINT', async () => {
    console.log('Received SIGINT, shutting down gracefully...');
    await gateway.stop();
    process.exit(0);
  });

  try {
    await gateway.start();
  } catch (error) {
    console.error('❌ Failed to start gateway:', error);
    process.exit(1);
  }
}

// Export for testing
export { PacketFlowGateway, ChemicalLoadBalancer, ServiceDiscovery };

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}
