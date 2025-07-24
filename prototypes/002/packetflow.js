#!/usr/bin/env node

/**
 * PacketFlow: A Periodic Table Approach to Distributed Computing
 * Full JavaScript Implementation
 * 
 * Usage:
 *   npm install ws uuid
 *   node packetflow.js
 */

const crypto = require('crypto');
const EventEmitter = require('events');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

// ============================================================================
// CORE CONSTANTS AND ENUMS
// ============================================================================

const PACKETFLOW_VERSION = '1.0';
const DEFAULT_TIMEOUT_MS = 30000;
const MAX_PACKET_SIZE = 1024 * 1024; // 1MB
const HEARTBEAT_INTERVAL_MS = 30000;

// Periodic Groups - The Six Families of Computational Packets
const PacketGroup = {
  CF: 'cf', // Control Flow
  DF: 'df', // Data Flow
  ED: 'ed', // Event Driven
  CO: 'co', // Collective
  MC: 'mc', // Meta-Computational
  RM: 'rm'  // Resource Management
};

// Chemical Bond Types
const BondType = {
  IONIC: 'ionic',         // Strong dependency (A must complete before B)
  COVALENT: 'covalent',   // Shared resources/state
  METALLIC: 'metallic',   // Loose coordination
  VDW: 'vdw'             // Van der Waals - weak environmental coupling
};

// Node Specialization Types
const NodeSpecialization = {
  CPU_INTENSIVE: 'cpu_intensive',
  MEMORY_BOUND: 'memory_bound',
  IO_INTENSIVE: 'io_intensive',
  NETWORK_HEAVY: 'network_heavy',
  GENERAL_PURPOSE: 'general_purpose'
};

// Message Types for WebSocket Protocol
const MessageType = {
  SUBMIT: 'submit',
  RESULT: 'result',
  ERROR: 'error',
  HEARTBEAT: 'heartbeat'
};

// ============================================================================
// CHEMICAL AFFINITY MATRIX
// ============================================================================

const AFFINITY_MATRIX = {
  [PacketGroup.CF]: { // Control Flow
    [NodeSpecialization.CPU_INTENSIVE]: 0.9,
    [NodeSpecialization.MEMORY_BOUND]: 0.4,
    [NodeSpecialization.IO_INTENSIVE]: 0.3,
    [NodeSpecialization.NETWORK_HEAVY]: 0.2,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.6
  },
  [PacketGroup.DF]: { // Data Flow
    [NodeSpecialization.CPU_INTENSIVE]: 0.8,
    [NodeSpecialization.MEMORY_BOUND]: 0.9,
    [NodeSpecialization.IO_INTENSIVE]: 0.7,
    [NodeSpecialization.NETWORK_HEAVY]: 0.6,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.8
  },
  [PacketGroup.ED]: { // Event Driven
    [NodeSpecialization.CPU_INTENSIVE]: 0.3,
    [NodeSpecialization.MEMORY_BOUND]: 0.2,
    [NodeSpecialization.IO_INTENSIVE]: 0.9,
    [NodeSpecialization.NETWORK_HEAVY]: 0.8,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.6
  },
  [PacketGroup.CO]: { // Collective
    [NodeSpecialization.CPU_INTENSIVE]: 0.4,
    [NodeSpecialization.MEMORY_BOUND]: 0.6,
    [NodeSpecialization.IO_INTENSIVE]: 0.8,
    [NodeSpecialization.NETWORK_HEAVY]: 0.9,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.7
  },
  [PacketGroup.MC]: { // Meta-Computational
    [NodeSpecialization.CPU_INTENSIVE]: 0.6,
    [NodeSpecialization.MEMORY_BOUND]: 0.7,
    [NodeSpecialization.IO_INTENSIVE]: 0.5,
    [NodeSpecialization.NETWORK_HEAVY]: 0.6,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.8
  },
  [PacketGroup.RM]: { // Resource Management
    [NodeSpecialization.CPU_INTENSIVE]: 0.5,
    [NodeSpecialization.MEMORY_BOUND]: 0.9,
    [NodeSpecialization.IO_INTENSIVE]: 0.4,
    [NodeSpecialization.NETWORK_HEAVY]: 0.3,
    [NodeSpecialization.GENERAL_PURPOSE]: 0.7
  }
};

function calculateChemicalAffinity(packetGroup, nodeSpecialization) {
  return AFFINITY_MATRIX[packetGroup]?.[nodeSpecialization] || 0.1;
}

// ============================================================================
// CORE DATA STRUCTURES
// ============================================================================

/**
 * Computational Packet - The atomic unit of work
 */
class Packet {
  constructor(group, element, data, priority = 5, options = {}) {
    this.version = PACKETFLOW_VERSION;
    this.id = uuidv4();
    this.group = group;
    this.element = element;
    this.data = data;
    this.priority = Math.max(1, Math.min(10, priority));
    this.timeout_ms = options.timeout_ms || null;
    this.dependencies = options.dependencies || null;
    this.metadata = options.metadata || null;
    this.created_at = Date.now();
  }

  // Chemical Properties
  get reactivity() {
    const reactivityMap = {
      [PacketGroup.ED]: 0.9, // Event Driven - highest reactivity
      [PacketGroup.DF]: 0.8, // Data Flow - high reactivity
      [PacketGroup.CF]: 0.6, // Control Flow - medium reactivity
      [PacketGroup.RM]: 0.5, // Resource Management - medium-low
      [PacketGroup.CO]: 0.4, // Collective - low (coordination-bound)
      [PacketGroup.MC]: 0.3  // Meta-Computational - lowest (analysis-intensive)
    };
    return reactivityMap[this.group] || 0.5;
  }

  get ionizationEnergy() {
    const baseComplexity = this.priority / 10.0;
    const groupFactors = {
      [PacketGroup.MC]: 2.0, // Meta-computational is expensive
      [PacketGroup.CO]: 1.8, // Collective operations are costly
      [PacketGroup.CF]: 1.5, // Control flow has overhead
      [PacketGroup.RM]: 1.3, // Resource management has bookkeeping
      [PacketGroup.DF]: 1.0, // Data flow is efficient
      [PacketGroup.ED]: 0.8  // Events are lightweight
    };
    return baseComplexity * (groupFactors[this.group] || 1.0);
  }

  get atomicRadius() {
    // Scope of influence - how many other packets this affects
    const radiusMap = {
      [PacketGroup.CO]: 3.0, // Collective operations affect many
      [PacketGroup.MC]: 2.5, // Meta-computational affects system
      [PacketGroup.ED]: 2.0, // Events propagate
      [PacketGroup.RM]: 1.5, // Resources are shared
      [PacketGroup.CF]: 1.2, // Control flow has dependencies
      [PacketGroup.DF]: 1.0  // Data flow is localized
    };
    return radiusMap[this.group] || 1.0;
  }

  get electronegativity() {
    return (this.priority / 10.0) * this.ionizationEnergy;
  }

  // Serialization for network transport
  toJSON() {
    return {
      version: this.version,
      id: this.id,
      group: this.group,
      element: this.element,
      data: this.data,
      priority: this.priority,
      timeout_ms: this.timeout_ms,
      dependencies: this.dependencies,
      metadata: this.metadata
    };
  }

  static fromJSON(json) {
    const packet = new Packet(json.group, json.element, json.data, json.priority, {
      timeout_ms: json.timeout_ms,
      dependencies: json.dependencies,
      metadata: json.metadata
    });
    packet.id = json.id;
    packet.version = json.version;
    return packet;
  }
}

/**
 * Chemical Bond between packets
 */
class ChemicalBond {
  constructor(fromPacket, toPacket, bondType) {
    this.fromPacket = fromPacket;
    this.toPacket = toPacket;
    this.bondType = bondType;
    this.strength = this.calculateStrength();
    this.created_at = Date.now();
  }

  calculateStrength() {
    const strengthMap = {
      [BondType.IONIC]: 1.0,
      [BondType.COVALENT]: 0.8,
      [BondType.METALLIC]: 0.6,
      [BondType.VDW]: 0.3
    };
    return strengthMap[this.bondType] || 0.5;
  }

  get bondEnergy() {
    return this.strength * (this.fromPacket.priority + this.toPacket.priority) / 2;
  }

  isCompatible(otherBond) {
    // Check if bonds can coexist without conflicts
    return !(this.fromPacket === otherBond.fromPacket && 
             this.toPacket === otherBond.toPacket &&
             this.bondType === BondType.IONIC && 
             otherBond.bondType === BondType.IONIC);
  }
}

/**
 * Molecular Structure - Complex patterns of packets
 */
class Molecule extends EventEmitter {
  constructor(id, options = {}) {
    super();
    this.id = id;
    this.composition = new Set();
    this.bonds = new Map();
    this.properties = new Map();
    this.stability = 0.0;
    this.created_at = Date.now();
    this.options = options;
  }

  addPacket(packet) {
    if (!(packet instanceof Packet)) {
      throw new Error('Can only add Packet instances to molecules');
    }
    
    this.composition.add(packet);
    this.updateStability();
    this.emit('packet_added', packet);
    return this;
  }

  removePacket(packet) {
    this.composition.delete(packet);
    // Remove all bonds involving this packet
    for (const [key, bond] of this.bonds) {
      if (bond.fromPacket === packet || bond.toPacket === packet) {
        this.bonds.delete(key);
      }
    }
    this.updateStability();
    this.emit('packet_removed', packet);
    return this;
  }

  addBond(bond) {
    if (!(bond instanceof ChemicalBond)) {
      throw new Error('Can only add ChemicalBond instances to molecules');
    }

    // Verify both packets are in the molecule
    if (!this.composition.has(bond.fromPacket) || !this.composition.has(bond.toPacket)) {
      throw new Error('Both packets must be in the molecule before bonding');
    }

    const bondKey = `${bond.fromPacket.id}-${bond.toPacket.id}`;
    this.bonds.set(bondKey, bond);
    this.updateStability();
    this.emit('bond_added', bond);
    return this;
  }

  removeBond(fromPacketId, toPacketId) {
    const bondKey = `${fromPacketId}-${toPacketId}`;
    const removed = this.bonds.delete(bondKey);
    if (removed) {
      this.updateStability();
      this.emit('bond_removed', { fromPacketId, toPacketId });
    }
    return this;
  }

  updateStability() {
    let bindingEnergy = 0;
    let internalStress = 0;

    // Calculate binding energy from bonds
    for (const bond of this.bonds.values()) {
      bindingEnergy += bond.bondEnergy;
    }

    // Calculate internal stress from packet interactions
    for (const packet of this.composition) {
      internalStress += packet.ionizationEnergy * packet.atomicRadius;
    }

    // Stability = binding energy - internal stress per packet
    const packetCount = this.composition.size || 1;
    this.stability = bindingEnergy - (internalStress / packetCount);
    
    this.emit('stability_changed', this.stability);
  }

  get isStable() {
    return this.stability > 0.5; // Stability threshold
  }

  get resonanceStability() {
    // Multiple valid configurations increase stability
    const configCount = Math.max(1, this.bonds.size);
    return Math.log(configCount);
  }

  get totalBindingEnergy() {
    return Array.from(this.bonds.values())
      .reduce((sum, bond) => sum + bond.bondEnergy, 0);
  }

  // Molecular reactions
  synthesize(otherMolecule) {
    // Combine two molecules into one
    const newMolecule = new Molecule(`${this.id}+${otherMolecule.id}`);
    
    for (const packet of this.composition) {
      newMolecule.addPacket(packet);
    }
    for (const packet of otherMolecule.composition) {
      newMolecule.addPacket(packet);
    }
    
    for (const bond of this.bonds.values()) {
      newMolecule.addBond(bond);
    }
    for (const bond of otherMolecule.bonds.values()) {
      newMolecule.addBond(bond);
    }
    
    return newMolecule;
  }

  decompose() {
    // Break molecule into constituent packets
    const packets = Array.from(this.composition);
    this.composition.clear();
    this.bonds.clear();
    this.stability = 0;
    this.emit('decomposed', packets);
    return packets;
  }

  clone() {
    const cloned = new Molecule(`${this.id}_clone`);
    for (const packet of this.composition) {
      cloned.addPacket(packet);
    }
    for (const bond of this.bonds.values()) {
      cloned.addBond(bond);
    }
    return cloned;
  }

  toJSON() {
    return {
      id: this.id,
      composition: Array.from(this.composition).map(p => p.toJSON()),
      bonds: Array.from(this.bonds.values()).map(b => ({
        from: b.fromPacket.id,
        to: b.toPacket.id,
        type: b.bondType,
        strength: b.strength
      })),
      stability: this.stability,
      properties: Object.fromEntries(this.properties)
    };
  }
}

/**
 * Processing Result
 */
class PacketResult {
  constructor(packetId, status, data = null, error = null, durationMs = 0) {
    this.packet_id = packetId;
    this.status = status; // 'success' or 'error'
    this.data = data;
    this.error = error;
    this.duration_ms = durationMs;
    this.timestamp = Date.now();
  }

  static success(packetId, data, durationMs) {
    return new PacketResult(packetId, 'success', data, null, durationMs);
  }

  static failure(packetId, code, message, durationMs) {
    return new PacketResult(packetId, 'error', null, { code, message }, durationMs);
  }

  toJSON() {
    return {
      packet_id: this.packet_id,
      status: this.status,
      data: this.data,
      error: this.error,
      duration_ms: this.duration_ms,
      timestamp: this.timestamp
    };
  }
}

/**
 * WebSocket Message Frame
 */
class Message {
  constructor(type, seq, payload) {
    this.type = type;
    this.seq = seq;
    this.payload = payload;
    this.timestamp = Date.now();
  }

  toJSON() {
    return {
      type: this.type,
      seq: this.seq,
      payload: this.payload,
      timestamp: this.timestamp
    };
  }

  static fromJSON(json) {
    return new Message(json.type, json.seq, json.payload);
  }
}

// ============================================================================
// PACKET HANDLER SYSTEM
// ============================================================================

/**
 * Packet Handler - Defines how to process specific packet types
 */
class PacketHandler {
  constructor(group, element, handlerFn, options = {}) {
    this.group = group;
    this.element = element;
    this.handlerFn = handlerFn;
    this.options = options;
    this.stats = {
      total_processed: 0,
      total_errors: 0,
      avg_duration_ms: 0,
      last_processed: null
    };
  }

  get key() {
    return `${this.group}:${this.element}`;
  }

  async handle(packet) {
    const startTime = Date.now();
    
    try {
      const result = await this.handlerFn(packet.data, packet);
      const duration = Date.now() - startTime;
      
      this.updateStats(duration, false);
      return PacketResult.success(packet.id, result, duration);
    } catch (error) {
      const duration = Date.now() - startTime;
      
      this.updateStats(duration, true);
      return PacketResult.failure(packet.id, 'PF500', error.message, duration);
    }
  }

  updateStats(duration, isError) {
    this.stats.total_processed++;
    if (isError) this.stats.total_errors++;
    
    // Calculate running average
    const oldAvg = this.stats.avg_duration_ms;
    const count = this.stats.total_processed;
    this.stats.avg_duration_ms = (oldAvg * (count - 1) + duration) / count;
    this.stats.last_processed = Date.now();
  }

  get errorRate() {
    return this.stats.total_processed > 0 
      ? this.stats.total_errors / this.stats.total_processed 
      : 0;
  }
}

// ============================================================================
// PROCESSING NODE
// ============================================================================

/**
 * Processing Node - Specialized compute node for packet processing
 */
class ProcessingNode extends EventEmitter {
  constructor(id, specialization, maxCapacity = 100) {
    super();
    this.id = id;
    this.specialization = specialization;
    this.maxCapacity = maxCapacity;
    this.currentLoad = 0;
    this.packetQueue = [];
    this.handlers = new Map();
    this.processing = false;
    this.stats = {
      packets_processed: 0,
      total_duration_ms: 0,
      errors: 0,
      last_activity: Date.now()
    };
  }

  registerHandler(group, element, handlerFn, options = {}) {
    const handler = new PacketHandler(group, element, handlerFn, options);
    this.handlers.set(handler.key, handler);
    this.emit('handler_registered', handler);
    return this;
  }

  unregisterHandler(group, element) {
    const key = `${group}:${element}`;
    const removed = this.handlers.delete(key);
    if (removed) {
      this.emit('handler_unregistered', { group, element });
    }
    return this;
  }

  async enqueue(packet) {
    if (!this.canAccept(packet)) {
      throw new Error(`Node ${this.id} is overloaded (load: ${this.currentLoad}/${this.maxCapacity})`);
    }

    this.packetQueue.push(packet);
    this.currentLoad += packet.ionizationEnergy;
    this.emit('packet_queued', packet);
    
    // Start processing if not already processing
    if (!this.processing) {
      setImmediate(() => this.processQueue());
    }
    
    return this;
  }

  async processQueue() {
    if (this.processing || this.packetQueue.length === 0) return;
    
    this.processing = true;
    this.emit('processing_started');

    while (this.packetQueue.length > 0) {
      const packet = this.packetQueue.shift();
      this.currentLoad -= packet.ionizationEnergy;
      
      try {
        const result = await this.processPacket(packet);
        this.emit('packet_processed', result);
      } catch (error) {
        this.emit('packet_error', { packet, error });
      }
    }

    this.processing = false;
    this.emit('processing_finished');
  }

  async processPacket(packet) {
    const handlerKey = `${packet.group}:${packet.element}`;
    const handler = this.handlers.get(handlerKey);

    if (!handler) {
      const result = PacketResult.failure(packet.id, 'PF001', `No handler for ${handlerKey}`, 0);
      this.updateStats(0, true);
      return result;
    }

    const startTime = Date.now();
    const result = await handler.handle(packet);
    const duration = Date.now() - startTime;
    
    this.updateStats(duration, result.status === 'error');
    return result;
  }

  canAccept(packet) {
    return (this.currentLoad + packet.ionizationEnergy) <= this.maxCapacity;
  }

  get loadFactor() {
    return this.currentLoad / this.maxCapacity;
  }

  get isHealthy() {
    const recentActivity = Date.now() - this.stats.last_activity < 60000; // 1 minute
    const lowErrorRate = this.errorRate < 0.1; // Less than 10% errors
    const notOverloaded = this.loadFactor < 0.9; // Less than 90% loaded
    
    return recentActivity && lowErrorRate && notOverloaded;
  }

  get errorRate() {
    return this.stats.packets_processed > 0 
      ? this.stats.errors / this.stats.packets_processed 
      : 0;
  }

  get averageDuration() {
    return this.stats.packets_processed > 0 
      ? this.stats.total_duration_ms / this.stats.packets_processed 
      : 0;
  }

  updateStats(duration, isError) {
    this.stats.packets_processed++;
    this.stats.total_duration_ms += duration;
    if (isError) this.stats.errors++;
    this.stats.last_activity = Date.now();
  }

  getHealthStatus() {
    return {
      id: this.id,
      specialization: this.specialization,
      load_factor: this.loadFactor,
      queue_length: this.packetQueue.length,
      error_rate: this.errorRate,
      avg_duration_ms: this.averageDuration,
      is_healthy: this.isHealthy,
      handlers: Array.from(this.handlers.keys())
    };
  }
}

// ============================================================================
// ROUTING TABLE
// ============================================================================

/**
 * Chemical Routing Table - Routes packets based on chemical affinity
 */
class RoutingTable {
  constructor() {
    this.nodes = new Map();
    this.routingPolicies = new Map();
    this.stats = {
      total_routes: 0,
      successful_routes: 0,
      failed_routes: 0
    };
  }

  addNode(node) {
    if (!(node instanceof ProcessingNode)) {
      throw new Error('Can only add ProcessingNode instances');
    }
    
    this.nodes.set(node.id, node);
    return this;
  }

  removeNode(nodeId) {
    return this.nodes.delete(nodeId);
  }

  addRoutingPolicy(packetGroup, policyFn) {
    this.routingPolicies.set(packetGroup, policyFn);
    return this;
  }

  route(packet) {
    this.stats.total_routes++;
    
    // Check for custom routing policy
    const customPolicy = this.routingPolicies.get(packet.group);
    if (customPolicy) {
      const node = customPolicy(packet, Array.from(this.nodes.values()));
      if (node) {
        this.stats.successful_routes++;
        return node;
      }
    }

    // Default chemical affinity routing
    const availableNodes = Array.from(this.nodes.values())
      .filter(node => node.canAccept(packet) && node.isHealthy);

    if (availableNodes.length === 0) {
      this.stats.failed_routes++;
      return null;
    }

    let bestNode = null;
    let bestScore = -1;

    for (const node of availableNodes) {
      const affinity = calculateChemicalAffinity(packet.group, node.specialization);
      const loadFactor = 1 - node.loadFactor;
      const priorityFactor = packet.priority / 10;
      const healthBonus = node.isHealthy ? 1.1 : 0.9;
      
      const score = affinity * loadFactor * priorityFactor * healthBonus;
      
      if (score > bestScore) {
        bestScore = score;
        bestNode = node;
      }
    }

    if (bestNode) {
      this.stats.successful_routes++;
    } else {
      this.stats.failed_routes++;
    }

    return bestNode;
  }

  getHealthyNodes() {
    return Array.from(this.nodes.values()).filter(node => node.isHealthy);
  }

  getStats() {
    return {
      ...this.stats,
      success_rate: this.stats.total_routes > 0 
        ? this.stats.successful_routes / this.stats.total_routes 
        : 0,
      total_nodes: this.nodes.size,
      healthy_nodes: this.getHealthyNodes().length
    };
  }
}

// ============================================================================
// MOLECULAR OPTIMIZATION ENGINE
// ============================================================================

/**
 * Molecular Optimization Engine - Automatically optimizes molecular structures
 */
class OptimizationEngine extends EventEmitter {
  constructor(options = {}) {
    super();
    this.optimizationThreshold = options.threshold || 0.1; // 10% improvement threshold
    this.maxOptimizationRounds = options.maxRounds || 5;
    this.stats = {
      molecules_optimized: 0,
      total_improvement: 0,
      optimization_time_ms: 0
    };
  }

  shouldOptimize(molecule) {
    return !molecule.isStable || molecule.composition.size > 10;
  }

  async optimizeMolecule(molecule) {
    const startTime = Date.now();
    const initialStability = molecule.stability;
    
    this.emit('optimization_started', molecule);
    
    let rounds = 0;
    let improved = true;
    
    while (improved && rounds < this.maxOptimizationRounds) {
      const previousStability = molecule.stability;
      
      // Try different optimization strategies
      await this.optimizeBonds(molecule);
      await this.optimizeLocality(molecule);
      await this.optimizeParallelism(molecule);
      
      const improvement = molecule.stability - previousStability;
      improved = improvement > this.optimizationThreshold;
      rounds++;
      
      this.emit('optimization_round', { molecule, round: rounds, improvement });
    }
    
    const finalImprovement = molecule.stability - initialStability;
    const duration = Date.now() - startTime;
    
    this.updateStats(finalImprovement, duration);
    this.emit('optimization_completed', { molecule, improvement: finalImprovement, duration });
    
    return molecule;
  }

  async optimizeBonds(molecule) {
    // Convert weak ionic bonds to metallic if strict ordering not required
    for (const [key, bond] of molecule.bonds) {
      if (bond.bondType === BondType.IONIC && bond.strength < 0.7) {
        // Check if strict ordering is actually required
        if (!this.requiresStrictOrdering(bond.fromPacket, bond.toPacket)) {
          const newBond = new ChemicalBond(bond.fromPacket, bond.toPacket, BondType.METALLIC);
          molecule.bonds.set(key, newBond);
        }
      }
    }
  }

  async optimizeLocality(molecule) {
    // Co-locate packets with high communication frequency
    const highCommunicationPairs = this.findHighCommunicationPairs(molecule);
    
    for (const [packet1, packet2] of highCommunicationPairs) {
      // Add van der Waals bonds for locality preferences
      const bondKey = `${packet1.id}-${packet2.id}`;
      if (!molecule.bonds.has(bondKey)) {
        const localityBond = new ChemicalBond(packet1, packet2, BondType.VDW);
        molecule.bonds.set(bondKey, localityBond);
      }
    }
  }

  async optimizeParallelism(molecule) {
    // Identify parallelizable packet groups
    const parallelizableGroups = this.findParallelizableGroups(molecule);
    
    for (const group of parallelizableGroups) {
      // Reduce bond strength to allow parallel execution
      for (const packet of group) {
        for (const [key, bond] of molecule.bonds) {
          if (bond.fromPacket === packet || bond.toPacket === packet) {
            if (bond.bondType === BondType.IONIC) {
              const newBond = new ChemicalBond(bond.fromPacket, bond.toPacket, BondType.METALLIC);
              molecule.bonds.set(key, newBond);
            }
          }
        }
      }
    }
  }

  requiresStrictOrdering(packet1, packet2) {
    // Heuristic: Control flow packets typically require strict ordering
    return packet1.group === PacketGroup.CF || packet2.group === PacketGroup.CF;
  }

  findHighCommunicationPairs(molecule) {
    // Simplified: assume data flow packets communicate frequently
    const pairs = [];
    const dfPackets = Array.from(molecule.composition)
      .filter(p => p.group === PacketGroup.DF);
    
    for (let i = 0; i < dfPackets.length; i++) {
      for (let j = i + 1; j < dfPackets.length; j++) {
        pairs.push([dfPackets[i], dfPackets[j]]);
      }
    }
    
    return pairs;
  }

  findParallelizableGroups(molecule) {
    // Group packets that can execute in parallel (same group, no dependencies)
    const groups = new Map();
    
    for (const packet of molecule.composition) {
      if (packet.group === PacketGroup.DF || packet.group === PacketGroup.ED) {
        if (!groups.has(packet.group)) {
          groups.set(packet.group, []);
        }
        groups.get(packet.group).push(packet);
      }
    }
    
    return Array.from(groups.values()).filter(group => group.length > 1);
  }

  updateStats(improvement, duration) {
    this.stats.molecules_optimized++;
    this.stats.total_improvement += improvement;
    this.stats.optimization_time_ms += duration;
  }

  getStats() {
    return {
      ...this.stats,
      avg_improvement: this.stats.molecules_optimized > 0 
        ? this.stats.total_improvement / this.stats.molecules_optimized 
        : 0,
      avg_duration_ms: this.stats.molecules_optimized > 0 
        ? this.stats.optimization_time_ms / this.stats.molecules_optimized 
        : 0
    };
  }
}

// ============================================================================
// FAULT DETECTOR
// ============================================================================

/**
 * Fault Detector - Monitors system health and detects failures
 */
class FaultDetector extends EventEmitter {
  constructor(options = {}) {
    super();
    this.failureThreshold = options.failureThreshold || 3;
    this.timeWindow = options.timeWindow || 60000; // 1 minute
    this.recentFailures = new Map();
    this.nodeHealth = new Map();
    this.monitoringInterval = null;
    
    // Start monitoring
    this.startMonitoring();
  }

  startMonitoring() {
    this.monitoringInterval = setInterval(() => {
      this.cleanupOldFailures();
      this.assessSystemHealth();
    }, 10000); // Check every 10 seconds
  }

  stopMonitoring() {
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
    }
  }

  monitorPacket(packet) {
    // Track packet for monitoring (simplified implementation)
    this.emit('packet_monitored', packet);
  }

  recordFailure(nodeId, error = null) {
    const now = Date.now();
    
    if (!this.recentFailures.has(nodeId)) {
      this.recentFailures.set(nodeId, []);
    }
    
    this.recentFailures.get(nodeId).push({ timestamp: now, error });
    
    // Check if node has exceeded failure threshold
    const failures = this.getRecentFailures(nodeId);
    if (failures.length >= this.failureThreshold) {
      this.emit('node_unhealthy', { nodeId, failures });
    }
    
    this.emit('failure_recorded', { nodeId, error });
  }

  getRecentFailures(nodeId) {
    const failures = this.recentFailures.get(nodeId) || [];
    const cutoff = Date.now() - this.timeWindow;
    return failures.filter(f => f.timestamp > cutoff);
  }

  isNodeHealthy(nodeId) {
    const recentFailures = this.getRecentFailures(nodeId);
    return recentFailures.length < this.failureThreshold;
  }

  cleanupOldFailures() {
    const cutoff = Date.now() - this.timeWindow;
    
    for (const [nodeId, failures] of this.recentFailures) {
      const recentFailures = failures.filter(f => f.timestamp > cutoff);
      if (recentFailures.length === 0) {
        this.recentFailures.delete(nodeId);
      } else {
        this.recentFailures.set(nodeId, recentFailures);
      }
    }
  }

  assessSystemHealth() {
    const healthReport = {
      timestamp: Date.now(),
      total_nodes: this.nodeHealth.size,
      healthy_nodes: 0,
      unhealthy_nodes: 0,
      failure_rate: 0
    };

    let totalFailures = 0;
    let totalChecks = 0;

    for (const [nodeId, _] of this.nodeHealth) {
      const failures = this.getRecentFailures(nodeId);
      totalFailures += failures.length;
      totalChecks++;
      
      if (this.isNodeHealthy(nodeId)) {
        healthReport.healthy_nodes++;
      } else {
        healthReport.unhealthy_nodes++;
      }
    }

    if (totalChecks > 0) {
      healthReport.failure_rate = totalFailures / totalChecks;
    }

    this.emit('health_assessment', healthReport);
    return healthReport;
  }

  async healMolecule(molecule, failedPackets) {
    // Attempt to heal a molecule by removing failed packets
    this.emit('healing_started', { molecule, failedPackets });
    
    let healed = false;
    const remainingPackets = new Set(molecule.composition);
    
    // Remove failed packets
    for (const failedPacket of failedPackets) {
      remainingPackets.delete(failedPacket);
      molecule.removePacket(failedPacket);
    }
    
    // Check if remaining molecule can still function
    if (remainingPackets.size > 0 && molecule.stability > 0.3) {
      healed = true;
      this.emit('healing_successful', molecule);
    } else {
      this.emit('healing_failed', molecule);
    }
    
    return healed;
  }

  getSystemHealth() {
    return this.assessSystemHealth();
  }
}

// ============================================================================
// REACTOR CORE
// ============================================================================

/**
 * Main Reactor Core - The heart of the PacketFlow system
 */
class ReactorCore extends EventEmitter {
  constructor(options = {}) {
    super();
    this.nodes = new Map();
    this.molecules = new Map();
    this.routingTable = new RoutingTable();
    this.optimizationEngine = new OptimizationEngine(options.optimization || {});
    this.faultDetector = new FaultDetector(options.faultDetection || {});
    this.packetSequence = 0;
    this.running = false;
    this.stats = {
      packets_processed: 0,
      molecules_created: 0,
      optimizations_run: 0,
      uptime_start: null
    };

    // Wire up event handlers
    this.setupEventHandlers();
  }

  setupEventHandlers() {
    this.faultDetector.on('node_unhealthy', ({ nodeId }) => {
      this.emit('node_unhealthy', nodeId);
    });

    this.optimizationEngine.on('optimization_completed', ({ molecule, improvement }) => {
      this.emit('molecule_optimized', { molecule, improvement });
    });
  }

  async start() {
    this.running = true;
    this.stats.uptime_start = Date.now();
    
    // Start periodic optimization
    this.optimizationInterval = setInterval(async () => {
      await this.optimizeMolecules();
    }, 30000); // Optimize every 30 seconds

    this.emit('reactor_started');
    console.log('🧪 PacketFlow Reactor started with', this.nodes.size, 'nodes');
  }

  async stop() {
    this.running = false;
    
    if (this.optimizationInterval) {
      clearInterval(this.optimizationInterval);
    }
    
    this.faultDetector.stopMonitoring();
    this.emit('reactor_stopped');
    console.log('⚡ PacketFlow Reactor stopped');
  }

  addNode(specialization, maxCapacity = 100) {
    const nodeId = `node_${this.nodes.size + 1}`;
    const node = new ProcessingNode(nodeId, specialization, maxCapacity);
    
    this.nodes.set(nodeId, node);
    this.routingTable.addNode(node);
    
    // Monitor node health
    node.on('packet_error', ({ packet, error }) => {
      this.faultDetector.recordFailure(nodeId, error);
    });
    
    this.emit('node_added', node);
    return node;
  }

  removeNode(nodeId) {
    const node = this.nodes.get(nodeId);
    if (node) {
      this.nodes.delete(nodeId);
      this.routingTable.removeNode(nodeId);
      this.emit('node_removed', nodeId);
    }
    return node;
  }

  createMolecule(id, options = {}) {
    const molecule = new Molecule(id, options);
    this.molecules.set(id, molecule);
    this.stats.molecules_created++;
    
    molecule.on('stability_changed', (stability) => {
      if (stability < 0.3) {
        this.emit('molecule_unstable', molecule);
      }
    });
    
    this.emit('molecule_created', molecule);
    return molecule;
  }

  removeMolecule(id) {
    const molecule = this.molecules.get(id);
    if (molecule) {
      this.molecules.delete(id);
      this.emit('molecule_removed', id);
    }
    return molecule;
  }

  async submitPacket(packet) {
    if (!(packet instanceof Packet)) {
      throw new Error('Can only submit Packet instances');
    }

    this.stats.packets_processed++;
    this.emit('packet_submitted', packet);
    
    // Monitor packet
    this.faultDetector.monitorPacket(packet);
    
    // Route packet to appropriate node
    const targetNode = this.routingTable.route(packet);
    if (!targetNode) {
      const result = PacketResult.failure(packet.id, 'PF003', 'No available nodes', 0);
      this.emit('packet_failed', result);
      return result;
    }

    try {
      await targetNode.enqueue(packet);
      
      // Return a promise that resolves when the packet is processed
      return new Promise((resolve) => {
        const onProcessed = (result) => {
          if (result.packet_id === packet.id) {
            targetNode.off('packet_processed', onProcessed);
            targetNode.off('packet_error', onError);
            this.emit('packet_completed', result);
            resolve(result);
          }
        };
        
        const onError = ({ packet: errorPacket, error }) => {
          if (errorPacket.id === packet.id) {
            targetNode.off('packet_processed', onProcessed);
            targetNode.off('packet_error', onError);
            const result = PacketResult.failure(packet.id, 'PF500', error.message, 0);
            this.emit('packet_failed', result);
            resolve(result);
          }
        };
        
        targetNode.on('packet_processed', onProcessed);
        targetNode.on('packet_error', onError);
      });
    } catch (error) {
      const result = PacketResult.failure(packet.id, 'PF004', error.message, 0);
      this.emit('packet_failed', result);
      return result;
    }
  }

  async optimizeMolecules() {
    const unstableMolecules = Array.from(this.molecules.values())
      .filter(molecule => this.optimizationEngine.shouldOptimize(molecule));

    for (const molecule of unstableMolecules) {
      try {
        await this.optimizationEngine.optimizeMolecule(molecule);
        this.stats.optimizations_run++;
      } catch (error) {
        this.emit('optimization_error', { molecule, error });
      }
    }
  }

  getSystemHealth() {
    const nodeHealths = Array.from(this.nodes.values()).map(node => ({
      id: node.id,
      health: node.isHealthy,
      load: node.loadFactor,
      errors: node.errorRate
    }));

    const healthyNodes = nodeHealths.filter(n => n.health).length;
    const totalLoad = nodeHealths.reduce((sum, n) => sum + n.load, 0);
    const avgLoad = nodeHealths.length > 0 ? totalLoad / nodeHealths.length : 0;

    return {
      overall_health: healthyNodes / Math.max(1, nodeHealths.length),
      healthy_nodes: healthyNodes,
      total_nodes: nodeHealths.length,
      average_load: avgLoad,
      uptime_ms: this.stats.uptime_start ? Date.now() - this.stats.uptime_start : 0,
      molecules: this.molecules.size,
      routing_stats: this.routingTable.getStats(),
      nodes: nodeHealths
    };
  }

  getStats() {
    return {
      ...this.stats,
      uptime_ms: this.stats.uptime_start ? Date.now() - this.stats.uptime_start : 0,
      nodes: this.nodes.size,
      molecules: this.molecules.size,
      routing: this.routingTable.getStats(),
      optimization: this.optimizationEngine.getStats(),
      health: this.getSystemHealth()
    };
  }
}

// ============================================================================
// WEBSOCKET REACTOR
// ============================================================================

/**
 * WebSocket Reactor - Network-enabled PacketFlow reactor
 */
class WebSocketReactor extends EventEmitter {
  constructor(options = {}) {
    super();
    this.reactorCore = new ReactorCore(options.reactor || {});
    this.server = null;
    this.clients = new Set();
    this.sequenceCounter = 0;
    this.port = options.port || 8443;
    this.host = options.host || 'localhost';

    // Wire up reactor events
    this.reactorCore.on('packet_completed', (result) => {
      this.broadcast('result', result);
    });
  }

  async listen() {
    return new Promise((resolve, reject) => {
      this.server = new WebSocket.Server({ 
        port: this.port, 
        host: this.host 
      });

      this.server.on('listening', () => {
        console.log(`🌐 PacketFlow WebSocket Reactor listening on ws://${this.host}:${this.port}`);
        this.emit('listening', { host: this.host, port: this.port });
        resolve();
      });

      this.server.on('error', (error) => {
        console.error('❌ WebSocket server error:', error);
        reject(error);
      });

      this.server.on('connection', (ws, req) => {
        this.handleNewConnection(ws, req);
      });
    });
  }

  handleNewConnection(ws, req) {
    const clientId = uuidv4();
    const clientInfo = {
      id: clientId,
      ws,
      address: req.socket.remoteAddress,
      connected_at: Date.now(),
      last_activity: Date.now()
    };

    this.clients.add(clientInfo);
    console.log(`🔗 Client ${clientId} connected from ${clientInfo.address}`);
    this.emit('client_connected', clientInfo);

    ws.on('message', async (data) => {
      clientInfo.last_activity = Date.now();
      await this.handleMessage(clientInfo, data);
    });

    ws.on('close', () => {
      this.clients.delete(clientInfo);
      console.log(`📤 Client ${clientId} disconnected`);
      this.emit('client_disconnected', clientInfo);
    });

    ws.on('error', (error) => {
      console.error(`❌ Client ${clientId} error:`, error);
      this.emit('client_error', { client: clientInfo, error });
    });

    // Send welcome message
    this.sendMessage(ws, MessageType.HEARTBEAT, 0, {
      message: 'Welcome to PacketFlow Reactor',
      server_time: Date.now(),
      client_id: clientId
    });
  }

  async handleMessage(client, data) {
    try {
      const message = JSON.parse(data.toString());
      const { type, seq, payload } = message;

      switch (type) {
        case MessageType.SUBMIT:
          await this.handleSubmit(client, seq, payload);
          break;
        case MessageType.HEARTBEAT:
          await this.handleHeartbeat(client, seq);
          break;
        default:
          this.sendError(client.ws, seq, 'PF002', `Unknown message type: ${type}`);
      }
    } catch (error) {
      console.error('❌ Failed to handle message:', error);
      this.sendError(client.ws, 0, 'PF001', 'Invalid message format');
    }
  }

  async handleSubmit(client, seq, payload) {
    try {
      // Parse packet from payload
      const packet = Packet.fromJSON(payload);
      
      // Submit to reactor core
      const result = await this.reactorCore.submitPacket(packet);
      
      // Send result back to client
      this.sendMessage(client.ws, MessageType.RESULT, seq, result.toJSON());
      
    } catch (error) {
      this.sendError(client.ws, seq, 'PF500', error.message);
    }
  }

  async handleHeartbeat(client, seq) {
    this.sendMessage(client.ws, MessageType.HEARTBEAT, seq, {
      server_time: Date.now(),
      client_id: client.id,
      system_health: this.reactorCore.getSystemHealth()
    });
  }

  sendMessage(ws, type, seq, payload) {
    if (ws.readyState !== WebSocket.OPEN) return;
    
    const message = new Message(type, seq, payload);
    const data = JSON.stringify(message.toJSON());
    
    try {
      ws.send(data);
    } catch (error) {
      console.error('❌ Failed to send message:', error);
    }
  }

  sendError(ws, seq, code, message) {
    this.sendMessage(ws, MessageType.ERROR, seq, {
      error: { code, message },
      timestamp: Date.now()
    });
  }

  broadcast(type, payload) {
    const message = new Message(type, ++this.sequenceCounter, payload);
    const data = JSON.stringify(message.toJSON());
    
    for (const client of this.clients) {
      if (client.ws.readyState === WebSocket.OPEN) {
        try {
          client.ws.send(data);
        } catch (error) {
          console.error('❌ Failed to broadcast to client:', error);
        }
      }
    }
  }

  async start() {
    await this.reactorCore.start();
    await this.listen();
    
    // Start heartbeat interval
    this.heartbeatInterval = setInterval(() => {
      this.broadcast(MessageType.HEARTBEAT, {
        server_time: Date.now(),
        system_health: this.reactorCore.getSystemHealth()
      });
    }, HEARTBEAT_INTERVAL_MS);
  }

  async stop() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
    
    // Close all client connections
    for (const client of this.clients) {
      client.ws.close();
    }
    
    // Close server
    if (this.server) {
      this.server.close();
    }
    
    await this.reactorCore.stop();
  }

  // Convenience methods for adding handlers
  registerHandler(group, element, handlerFn, nodeSpecialization = NodeSpecialization.GENERAL_PURPOSE) {
    // Find or create appropriate node
    let targetNode = null;
    for (const node of this.reactorCore.nodes.values()) {
      if (node.specialization === nodeSpecialization) {
        targetNode = node;
        break;
      }
    }
    
    if (!targetNode) {
      targetNode = this.reactorCore.addNode(nodeSpecialization);
    }
    
    targetNode.registerHandler(group, element, handlerFn);
    return this;
  }

  getStats() {
    return {
      ...this.reactorCore.getStats(),
      websocket: {
        connected_clients: this.clients.size,
        server_port: this.port,
        server_host: this.host
      }
    };
  }
}

// ============================================================================
// MOLECULAR PATTERNS LIBRARY
// ============================================================================

/**
 * Pre-built molecular patterns for common distributed computing scenarios
 */
class MolecularPatterns {
  static createStreamPipeline(reactor, id = 'stream_pipeline') {
    const molecule = reactor.createMolecule(id);
    
    // Create producer → transform → consumer pipeline
    const producer = new Packet(PacketGroup.DF, 'producer', { source: 'data_stream' }, 5);
    const transform = new Packet(PacketGroup.DF, 'transform', { function: 'process_data' }, 7);
    const consumer = new Packet(PacketGroup.DF, 'consumer', { sink: 'output_stream' }, 4);
    
    molecule.addPacket(producer);
    molecule.addPacket(transform);
    molecule.addPacket(consumer);
    
    // Add ionic bonds for sequential processing
    molecule.addBond(new ChemicalBond(producer, transform, BondType.IONIC));
    molecule.addBond(new ChemicalBond(transform, consumer, BondType.IONIC));
    
    return molecule;
  }

  static createFaultTolerantService(reactor, id = 'fault_tolerant_service') {
    const molecule = reactor.createMolecule(id);
    
    // Create fault tolerance pattern
    const service = new Packet(PacketGroup.CF, 'service', { type: 'main_service' }, 8);
    const monitor = new Packet(PacketGroup.ED, 'monitor', { metrics: ['uptime', 'errors'] }, 9);
    const recovery = new Packet(PacketGroup.MC, 'recovery', { strategy: 'restart' }, 7);
    const allocator = new Packet(PacketGroup.RM, 'allocator', { resources: ['memory', 'cpu'] }, 6);
    
    molecule.addPacket(service);
    molecule.addPacket(monitor);
    molecule.addPacket(recovery);
    molecule.addPacket(allocator);
    
    // Add bonds for fault tolerance coordination
    molecule.addBond(new ChemicalBond(monitor, recovery, BondType.IONIC));
    molecule.addBond(new ChemicalBond(recovery, allocator, BondType.COVALENT));
    molecule.addBond(new ChemicalBond(service, monitor, BondType.VDW));
    
    return molecule;
  }

  static createAutoScalingCluster(reactor, id = 'autoscaling_cluster') {
    const molecule = reactor.createMolecule(id);
    
    // Create auto-scaling pattern
    const loadBalancer = new Packet(PacketGroup.DF, 'load_balancer', { algorithm: 'round_robin' }, 6);
    const monitor = new Packet(PacketGroup.ED, 'threshold_monitor', { cpu_threshold: 80 }, 8);
    const scaler = new Packet(PacketGroup.MC, 'auto_scaler', { min_instances: 2, max_instances: 10 }, 7);
    const broadcaster = new Packet(PacketGroup.CO, 'config_broadcast', { config_version: 1 }, 5);
    
    molecule.addPacket(loadBalancer);
    molecule.addPacket(monitor);
    molecule.addPacket(scaler);
    molecule.addPacket(broadcaster);
    
    // Add bonds for auto-scaling coordination
    molecule.addBond(new ChemicalBond(monitor, scaler, BondType.IONIC));
    molecule.addBond(new ChemicalBond(scaler, broadcaster, BondType.COVALENT));
    molecule.addBond(new ChemicalBond(loadBalancer, monitor, BondType.METALLIC));
    
    return molecule;
  }

  static createDistributedCache(reactor, id = 'distributed_cache') {
    const molecule = reactor.createMolecule(id);
    
    // Create distributed caching pattern
    const coordinator = new Packet(PacketGroup.CO, 'cache_coordinator', { consistency: 'eventual' }, 6);
    const replicator = new Packet(PacketGroup.CO, 'data_replicator', { replicas: 3 }, 7);
    const eviction = new Packet(PacketGroup.RM, 'cache_eviction', { policy: 'lru', size_limit: '1GB' }, 5);
    const validator = new Packet(PacketGroup.CF, 'data_validator', { checksum: true }, 8);
    
    molecule.addPacket(coordinator);
    molecule.addPacket(replicator);
    molecule.addPacket(eviction);
    molecule.addPacket(validator);
    
    // Add bonds for cache coordination
    molecule.addBond(new ChemicalBond(coordinator, replicator, BondType.COVALENT));
    molecule.addBond(new ChemicalBond(replicator, validator, BondType.IONIC));
    molecule.addBond(new ChemicalBond(eviction, coordinator, BondType.METALLIC));
    
    return molecule;
  }
}

// ============================================================================
// EXAMPLE PACKET HANDLERS
// ============================================================================

// Data Flow Handlers
const dataFlowHandlers = {
  async transform(data, packet) {
    // Transform data (e.g., uppercase strings, multiply numbers)
    if (typeof data === 'string') {
      return data.toUpperCase();
    } else if (typeof data === 'number') {
      return data * 2;
    } else if (Array.isArray(data)) {
      return data.map(item => typeof item === 'string' ? item.toUpperCase() : item * 2);
    }
    return data;
  },

  async producer(data, packet) {
    // Generate data stream
    const count = data.count || 10;
    const items = [];
    for (let i = 0; i < count; i++) {
      items.push(`item_${i}_${Date.now()}`);
    }
    return { items, produced_at: Date.now() };
  },

  async consumer(data, packet) {
    // Consume data stream
    console.log(`📦 Consuming data:`, data);
    return { consumed: true, item_count: Array.isArray(data) ? data.length : 1 };
  }
};

// Control Flow Handlers
const controlFlowHandlers = {
  async sequential(data, packet) {
    // Sequential processing with artificial delay
    await new Promise(resolve => setTimeout(resolve, 10));
    return { result: data, processed_at: Date.now(), sequence: true };
  },

  async branch(data, packet) {
    // Conditional branching
    const condition = data.condition || Math.random() > 0.5;
    const path = condition ? 'path_a' : 'path_b';
    return { path, condition, timestamp: Date.now() };
  },

  async gate(data, packet) {
    // Synchronization gate
    const waitTime = data.wait_ms || 50;
    await new Promise(resolve => setTimeout(resolve, waitTime));
    return { gate_passed: true, wait_time: waitTime };
  }
};

// Event Driven Handlers
const eventDrivenHandlers = {
  async signal(data, packet) {
    // Handle event signals
    console.log(`📡 Signal received:`, data);
    return { 
      signal_processed: true, 
      event_type: data.event_type || 'generic',
      timestamp: Date.now() 
    };
  },

  async threshold(data, packet) {
    // Monitor thresholds
    const value = data.value || Math.random() * 100;
    const threshold = data.threshold || 50;
    const exceeded = value > threshold;
    
    if (exceeded) {
      console.log(`⚠️  Threshold exceeded: ${value} > ${threshold}`);
    }
    
    return { value, threshold, exceeded, checked_at: Date.now() };
  }
};

// Resource Management Handlers
const resourceManagementHandlers = {
  async allocate(data, packet) {
    // Allocate resources
    const resourceType = data.type || 'memory';
    const amount = data.amount || 100;
    
    console.log(`🔧 Allocating ${amount}MB of ${resourceType}`);
    
    return {
      allocated: true,
      resource_type: resourceType,
      amount,
      resource_id: uuidv4(),
      allocated_at: Date.now()
    };
  },

  async cache(data, packet) {
    // Cache management
    const operation = data.operation || 'store';
    const key = data.key || 'default_key';
    const value = data.value;
    
    console.log(`💾 Cache ${operation}: ${key}`);
    
    return {
      operation,
      key,
      success: true,
      cache_hit: operation === 'get' ? Math.random() > 0.3 : null,
      timestamp: Date.now()
    };
  }
};

// ============================================================================
// PERFORMANCE BENCHMARK
// ============================================================================

class PerformanceBenchmark {
  constructor(reactor) {
    this.reactor = reactor;
    this.results = [];
  }

  async runLatencyTest(packetCount = 1000, packetType = { group: PacketGroup.DF, element: 'transform' }) {
    console.log(`🏁 Running latency benchmark with ${packetCount} packets...`);
    
    const latencies = [];
    const errors = [];

    for (let i = 0; i < packetCount; i++) {
      const packet = new Packet(
        packetType.group, 
        packetType.element, 
        { test_data: `test_${i}`, iteration: i }, 
        5
      );

      const startTime = Date.now();
      
      try {
        const result = await this.reactor.submitPacket(packet);
        const latency = Date.now() - startTime;
        latencies.push(latency);
        
        if (result.status === 'error') {
          errors.push(result.error);
        }
      } catch (error) {
        errors.push(error);
        latencies.push(Date.now() - startTime);
      }
    }

    // Calculate statistics
    latencies.sort((a, b) => a - b);
    const mean = latencies.reduce((sum, l) => sum + l, 0) / latencies.length;
    const p50 = latencies[Math.floor(latencies.length * 0.5)];
    const p95 = latencies[Math.floor(latencies.length * 0.95)];
    const p99 = latencies[Math.floor(latencies.length * 0.99)];

    const results = {
      packet_count: packetCount,
      total_time_ms: latencies.reduce((sum, l) => sum + l, 0),
      mean_latency_ms: mean,
      p50_latency_ms: p50,
      p95_latency_ms: p95,
      p99_latency_ms: p99,
      min_latency_ms: latencies[0],
      max_latency_ms: latencies[latencies.length - 1],
      error_count: errors.length,
      error_rate: errors.length / packetCount,
      throughput_pps: packetCount / (latencies.reduce((sum, l) => sum + l, 0) / 1000)
    };

    console.log('📊 Latency Results:');
    console.log(`   Mean: ${results.mean_latency_ms.toFixed(2)} ms`);
    console.log(`   P50:  ${results.p50_latency_ms.toFixed(2)} ms`);
    console.log(`   P95:  ${results.p95_latency_ms.toFixed(2)} ms`);
    console.log(`   P99:  ${results.p99_latency_ms.toFixed(2)} ms`);
    console.log(`   Throughput: ${results.throughput_pps.toFixed(0)} packets/second`);
    console.log(`   Error rate: ${(results.error_rate * 100).toFixed(2)}%\n`);

    this.results.push({ type: 'latency', ...results });
    return results;
  }

  async runThroughputTest(durationSeconds = 10, concurrency = 10) {
    console.log(`🚀 Running throughput benchmark for ${durationSeconds} seconds with ${concurrency} concurrent streams...`);
    
    const startTime = Date.now();
    const endTime = startTime + (durationSeconds * 1000);
    const workers = [];
    const results = { packets: 0, errors: 0, durations: [] };

    // Create concurrent workers
    for (let i = 0; i < concurrency; i++) {
      workers.push(this.throughputWorker(endTime, i, results));
    }

    // Wait for all workers to complete
    await Promise.all(workers);

    const actualDuration = Date.now() - startTime;
    const throughput = (results.packets / actualDuration) * 1000;
    const errorRate = results.errors / results.packets;
    const avgDuration = results.durations.length > 0 
      ? results.durations.reduce((sum, d) => sum + d, 0) / results.durations.length 
      : 0;

    const testResults = {
      duration_ms: actualDuration,
      packets_processed: results.packets,
      errors: results.errors,
      error_rate: errorRate,
      throughput_pps: throughput,
      avg_processing_time_ms: avgDuration,
      concurrency
    };

    console.log('📊 Throughput Results:');
    console.log(`   Packets processed: ${testResults.packets_processed}`);
    console.log(`   Duration: ${testResults.duration_ms} ms`);
    console.log(`   Throughput: ${testResults.throughput_pps.toFixed(0)} packets/second`);
    console.log(`   Error rate: ${(testResults.error_rate * 100).toFixed(2)}%`);
    console.log(`   Avg processing time: ${testResults.avg_processing_time_ms.toFixed(2)} ms\n`);

    this.results.push({ type: 'throughput', ...testResults });
    return testResults;
  }

  async throughputWorker(endTime, workerId, results) {
    let packetCounter = 0;
    
    while (Date.now() < endTime) {
      const packet = new Packet(
        PacketGroup.DF, 
        'transform', 
        { worker_id: workerId, packet_num: packetCounter++ }, 
        5
      );

      const startTime = Date.now();
      
      try {
        const result = await this.reactor.submitPacket(packet);
        const duration = Date.now() - startTime;
        
        results.packets++;
        results.durations.push(duration);
        
        if (result.status === 'error') {
          results.errors++;
        }
      } catch (error) {
        results.errors++;
      }
    }
  }

  async runScalabilityTest(maxNodes = 8) {
    console.log(`📈 Running scalability test with up to ${maxNodes} nodes...`);
    
    const scalabilityResults = [];
    
    for (let nodeCount = 1; nodeCount <= maxNodes; nodeCount++) {
      // Add nodes if needed
      while (this.reactor.reactorCore.nodes.size < nodeCount) {
        const node = this.reactor.reactorCore.addNode(NodeSpecialization.GENERAL_PURPOSE);
        node.registerHandler(PacketGroup.DF, 'transform', dataFlowHandlers.transform);
      }

      // Run throughput test
      const result = await this.runThroughputTest(5, nodeCount); // 5 seconds, nodeCount concurrency
      scalabilityResults.push({
        node_count: nodeCount,
        throughput_pps: result.throughput_pps,
        efficiency: result.throughput_pps / nodeCount // packets per second per node
      });

      console.log(`   ${nodeCount} nodes: ${result.throughput_pps.toFixed(0)} pps (${(result.throughput_pps / nodeCount).toFixed(0)} pps/node)`);
    }

    return scalabilityResults;
  }

  getSummary() {
    return {
      total_tests: this.results.length,
      results: this.results
    };
  }
}

// ============================================================================
// DEMO AND EXAMPLES
// ============================================================================

async function runComprehensiveDemo() {
  console.log('🧪⚡ PacketFlow - Periodic Table Distributed Computing System');
  console.log('===========================================================\n');

  // Create WebSocket reactor
  const reactor = new WebSocketReactor({
    port: 8443,
    reactor: {
      optimization: { threshold: 0.1, maxRounds: 3 },
      faultDetection: { failureThreshold: 3, timeWindow: 60000 }
    }
  });

  // Add specialized nodes
  console.log('🏗️  Setting up specialized processing nodes...');
  const cpuNode = reactor.reactorCore.addNode(NodeSpecialization.CPU_INTENSIVE, 150);
  const memoryNode = reactor.reactorCore.addNode(NodeSpecialization.MEMORY_BOUND, 120);
  const ioNode = reactor.reactorCore.addNode(NodeSpecialization.IO_INTENSIVE, 100);
  const networkNode = reactor.reactorCore.addNode(NodeSpecialization.NETWORK_HEAVY, 80);

  // Register handlers on appropriate nodes
  cpuNode.registerHandler(PacketGroup.DF, 'transform', dataFlowHandlers.transform);
  cpuNode.registerHandler(PacketGroup.CF, 'sequential', controlFlowHandlers.sequential);
  cpuNode.registerHandler(PacketGroup.CF, 'branch', controlFlowHandlers.branch);
  
  memoryNode.registerHandler(PacketGroup.DF, 'producer', dataFlowHandlers.producer);
  memoryNode.registerHandler(PacketGroup.DF, 'consumer', dataFlowHandlers.consumer);
  memoryNode.registerHandler(PacketGroup.RM, 'cache', resourceManagementHandlers.cache);
  memoryNode.registerHandler(PacketGroup.RM, 'allocate', resourceManagementHandlers.allocate);
  
  ioNode.registerHandler(PacketGroup.ED, 'signal', eventDrivenHandlers.signal);
  ioNode.registerHandler(PacketGroup.ED, 'threshold', eventDrivenHandlers.threshold);

  networkNode.registerHandler(PacketGroup.CF, 'gate', controlFlowHandlers.gate);

  // Start reactor
  await reactor.start();

  console.log('🧪 ===== Chemical Computing Demonstration =====\n');

  // 1. Basic Packet Processing
  console.log('1️⃣  Basic Packet Processing & Chemical Routing:\n');

  const testPackets = [
    new Packet(PacketGroup.DF, 'transform', 'hello world', 5),
    new Packet(PacketGroup.CF, 'sequential', { data: 42 }, 7),
    new Packet(PacketGroup.ED, 'signal', { event_type: 'user_action', data: 'click' }, 9),
    new Packet(PacketGroup.RM, 'cache', { operation: 'store', key: 'user:123', value: { name: 'John' } }, 4)
  ];

  for (const packet of testPackets) {
    console.log(`   📦 ${packet.group.toUpperCase()} Packet (${packet.element})`);
    console.log(`      Reactivity: ${packet.reactivity.toFixed(2)}, Ionization Energy: ${packet.ionizationEnergy.toFixed(2)}, Atomic Radius: ${packet.atomicRadius.toFixed(2)}`);
    
    const result = await reactor.reactorCore.submitPacket(packet);
    console.log(`      ✅ Result: ${result.status.toUpperCase()} (${result.duration_ms}ms)\n`);
  }

  // 2. Molecular Composition
  console.log('2️⃣  Molecular Composition & Bond Formation:\n');

  const streamPipeline = MolecularPatterns.createStreamPipeline(reactor.reactorCore, 'demo_stream');
  console.log(`   🧬 Stream Pipeline Molecule:`);
  console.log(`      Composition: ${streamPipeline.composition.size} packets`);
  console.log(`      Bonds: ${streamPipeline.bonds.size} chemical bonds`);
  console.log(`      Stability: ${streamPipeline.stability.toFixed(2)}`);
  console.log(`      Is Stable: ${streamPipeline.isStable}\n`);

  const faultTolerant = MolecularPatterns.createFaultTolerantService(reactor.reactorCore, 'demo_ft');
  console.log(`   🛡️  Fault Tolerant Service Molecule:`);
  console.log(`      Composition: ${faultTolerant.composition.size} packets`);
  console.log(`      Bonds: ${faultTolerant.bonds.size} chemical bonds`);
  console.log(`      Stability: ${faultTolerant.stability.toFixed(2)}`);
  console.log(`      Is Stable: ${faultTolerant.isStable}\n`);

  // 3. Chemical Affinity Matrix Demo
  console.log('3️⃣  Chemical Affinity Matrix:\n');
  const groups = [PacketGroup.CF, PacketGroup.DF, PacketGroup.ED, PacketGroup.CO, PacketGroup.MC, PacketGroup.RM];
  const specs = [NodeSpecialization.CPU_INTENSIVE, NodeSpecialization.MEMORY_BOUND, NodeSpecialization.IO_INTENSIVE, NodeSpecialization.NETWORK_HEAVY];
  
  console.log('   Group    CPU   Mem   I/O   Net');
  console.log('   ─────────────────────────────────');
  for (const group of groups) {
    let line = `   ${group.toUpperCase().padEnd(8)}`;
    for (const spec of specs) {
      const affinity = calculateChemicalAffinity(group, spec);
      line += ` ${affinity.toFixed(1)}`;
    }
    console.log(line);
  }
  console.log();

  // 4. Performance Benchmarking
  console.log('4️⃣  Performance Benchmarking:\n');
  const benchmark = new PerformanceBenchmark(reactor.reactorCore);
  
  await benchmark.runLatencyTest(500, { group: PacketGroup.DF, element: 'transform' });
  await benchmark.runThroughputTest(5, 4);

  // 5. System Health Monitoring
  console.log('5️⃣  System Health Report:\n');
  const health = reactor.reactorCore.getSystemHealth();
  console.log(`   Overall Health: ${(health.overall_health * 100).toFixed(1)}%`);
  console.log(`   Healthy Nodes: ${health.healthy_nodes}/${health.total_nodes}`);
  console.log(`   Average Load: ${(health.average_load * 100).toFixed(1)}%`);
  console.log(`   Uptime: ${(health.uptime_ms / 1000).toFixed(1)} seconds`);
  console.log(`   Molecules: ${health.molecules}\n`);

  for (const node of health.nodes) {
    console.log(`   Node ${node.id}: ${node.health ? '✅' : '❌'} (load: ${(node.load * 100).toFixed(1)}%, errors: ${(node.errors * 100).toFixed(1)}%)`);
  }

  // 6. Advanced Molecular Patterns
  console.log('\n6️⃣  Advanced Molecular Patterns:\n');
  
  const autoScaling = MolecularPatterns.createAutoScalingCluster(reactor.reactorCore, 'demo_autoscale');
  const distributedCache = MolecularPatterns.createDistributedCache(reactor.reactorCore, 'demo_cache');
  
  console.log(`   📈 Auto-scaling Cluster: ${autoScaling.composition.size} packets, stability: ${autoScaling.stability.toFixed(2)}`);
  console.log(`   💾 Distributed Cache: ${distributedCache.composition.size} packets, stability: ${distributedCache.stability.toFixed(2)}`);

  // 7. Molecular Optimization
  console.log('\n7️⃣  Molecular Optimization Engine:\n');
  console.log('   Running optimization on all molecules...');
  
  await reactor.reactorCore.optimizeMolecules();
  
  console.log(`   ✨ Stream Pipeline stability: ${streamPipeline.stability.toFixed(2)} (${streamPipeline.isStable ? 'stable' : 'unstable'})`);
  console.log(`   ✨ Fault Tolerant stability: ${faultTolerant.stability.toFixed(2)} (${faultTolerant.isStable ? 'stable' : 'unstable'})`);
  console.log(`   ✨ Auto-scaling stability: ${autoScaling.stability.toFixed(2)} (${autoScaling.isStable ? 'stable' : 'unstable'})`);
  console.log(`   ✨ Distributed Cache stability: ${distributedCache.stability.toFixed(2)} (${distributedCache.isStable ? 'stable' : 'unstable'})`);

  // 8. Final Statistics
  console.log('\n8️⃣  Final System Statistics:\n');
  const finalStats = reactor.getStats();
  console.log(`   📊 Packets Processed: ${finalStats.packets_processed}`);
  console.log(`   🧬 Molecules Created: ${finalStats.molecules_created}`);
  console.log(`   ⚡ Optimizations Run: ${finalStats.optimizations_run}`);
  console.log(`   🌐 WebSocket Clients: ${finalStats.websocket.connected_clients}`);
  console.log(`   ✅ Routing Success Rate: ${(finalStats.routing.success_rate * 100).toFixed(1)}%`);
  
  console.log('\n🎉 PacketFlow demonstration complete!\n');
  console.log('Key Features Demonstrated:');
  console.log('✅ Chemical packet classification (CF, DF, ED, CO, MC, RM)');
  console.log('✅ Periodic properties (reactivity, ionization energy, atomic radius)');
  console.log('✅ Chemical affinity-based routing');
  console.log('✅ Molecular composition with chemical bonds');
  console.log('✅ Molecular stability analysis and optimization');
  console.log('✅ Fault detection and system health monitoring');
  console.log('✅ WebSocket protocol implementation');
  console.log('✅ Advanced molecular patterns library');
  console.log('✅ Real-time performance benchmarking');
  console.log('✅ Event-driven architecture with comprehensive monitoring');
  
  console.log('\n🚀 Ready for production distributed computing!');
  console.log(`📡 WebSocket server running on ws://localhost:${reactor.port}`);
  console.log('   Use any WebSocket client to connect and submit packets\n');

  // Keep server running for external connections
  process.on('SIGINT', async () => {
    console.log('\n🛑 Shutting down PacketFlow Reactor...');
    await reactor.stop();
    process.exit(0);
  });

  return reactor;
}

// ============================================================================
// CLIENT EXAMPLE
// ============================================================================

class PacketFlowClient {
  constructor(url = 'ws://localhost:8443') {
    this.url = url;
    this.ws = null;
    this.sequence = 0;
    this.pendingRequests = new Map();
    this.connected = false;
  }

  async connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);
      
      this.ws.on('open', () => {
        this.connected = true;
        console.log(`🔗 Connected to PacketFlow Reactor at ${this.url}`);
        resolve();
      });

      this.ws.on('message', (data) => {
        this.handleMessage(JSON.parse(data.toString()));
      });

      this.ws.on('error', (error) => {
        console.error('❌ WebSocket error:', error);
        reject(error);
      });

      this.ws.on('close', () => {
        this.connected = false;
        console.log('📤 Disconnected from PacketFlow Reactor');
      });
    });
  }

  handleMessage(message) {
    const { type, seq, payload } = message;
    
    switch (type) {
      case MessageType.RESULT:
        this.handleResult(seq, payload);
        break;
      case MessageType.ERROR:
        this.handleError(seq, payload);
        break;
      case MessageType.HEARTBEAT:
        console.log('💓 Heartbeat:', payload);
        break;
    }
  }

  handleResult(seq, result) {
    const pending = this.pendingRequests.get(seq);
    if (pending) {
      this.pendingRequests.delete(seq);
      pending.resolve(result);
    }
  }

  handleError(seq, error) {
    const pending = this.pendingRequests.get(seq);
    if (pending) {
      this.pendingRequests.delete(seq);
      pending.reject(new Error(`${error.error.code}: ${error.error.message}`));
    }
  }

  async submit(group, element, data, priority = 5) {
    if (!this.connected) {
      throw new Error('Not connected to reactor');
    }

    const packet = new Packet(group, element, data, priority);
    const seq = ++this.sequence;
    
    const message = new Message(MessageType.SUBMIT, seq, packet.toJSON());
    this.ws.send(JSON.stringify(message.toJSON()));

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(seq, { resolve, reject });
      
      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(seq)) {
          this.pendingRequests.delete(seq);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
    }
  }
}

// ============================================================================
// CLIENT DEMO
// ============================================================================

async function runClientDemo() {
  console.log('🔌 PacketFlow Client Demo\n');
  
  const client = new PacketFlowClient();
  
  try {
    await client.connect();
    
    // Submit various packets
    console.log('📤 Submitting test packets...\n');
    
    const results = await Promise.all([
      client.submit(PacketGroup.DF, 'transform', 'hello client', 5),
      client.submit(PacketGroup.CF, 'sequential', { value: 123 }, 7),
      client.submit(PacketGroup.ED, 'signal', { event: 'client_test' }, 8),
      client.submit(PacketGroup.RM, 'cache', { operation: 'get', key: 'test_key' }, 6)
    ]);
    
    results.forEach((result, i) => {
      console.log(`Result ${i + 1}:`, result);
    });
    
  } catch (error) {
    console.error('❌ Client error:', error);
  } finally {
    client.disconnect();
  }
}

// ============================================================================
// UNIT TESTS
// ============================================================================

class TestSuite {
  constructor() {
    this.tests = [];
    this.passed = 0;
    this.failed = 0;
  }

  test(name, testFn) {
    this.tests.push({ name, testFn });
  }

  async run() {
    console.log('🧪 Running PacketFlow Test Suite\n');
    
    for (const { name, testFn } of this.tests) {
      try {
        await testFn();
        console.log(`✅ ${name}`);
        this.passed++;
      } catch (error) {
        console.log(`❌ ${name}: ${error.message}`);
        this.failed++;
      }
    }
    
    console.log(`\n📊 Test Results: ${this.passed} passed, ${this.failed} failed\n`);
  }

  assert(condition, message) {
    if (!condition) {
      throw new Error(message || 'Assertion failed');
    }
  }

  assertEqual(actual, expected, message) {
    if (actual !== expected) {
      throw new Error(message || `Expected ${expected}, got ${actual}`);
    }
  }
}

async function runTests() {
  const suite = new TestSuite();

  suite.test('Packet creation and properties', async () => {
    const packet = new Packet(PacketGroup.DF, 'transform', 'test', 5);
    
    suite.assertEqual(packet.group, PacketGroup.DF);
    suite.assertEqual(packet.element, 'transform');
    suite.assertEqual(packet.priority, 5);
    suite.assertEqual(packet.reactivity, 0.8); // DF group reactivity
    suite.assert(packet.ionizationEnergy > 0);
    suite.assert(packet.atomicRadius > 0);
  });

  suite.test('Chemical affinity calculation', async () => {
    const affinity1 = calculateChemicalAffinity(PacketGroup.CF, NodeSpecialization.CPU_INTENSIVE);
    const affinity2 = calculateChemicalAffinity(PacketGroup.DF, NodeSpecialization.MEMORY_BOUND);
    
    suite.assertEqual(affinity1, 0.9);
    suite.assertEqual(affinity2, 0.9);
  });

  suite.test('Molecule creation and stability', async () => {
    const molecule = new Molecule('test_molecule');
    
    const packet1 = new Packet(PacketGroup.DF, 'transform', 'test1', 5);
    const packet2 = new Packet(PacketGroup.CF, 'sequential', 'test2', 7);
    
    molecule.addPacket(packet1);
    molecule.addPacket(packet2);
    
    const bond = new ChemicalBond(packet1, packet2, BondType.IONIC);
    molecule.addBond(bond);
    
    suite.assert(molecule.composition.size === 2);
    suite.assert(molecule.bonds.size === 1);
    suite.assert(typeof molecule.stability === 'number');
  });

  suite.test('Processing node functionality', async () => {
    const node = new ProcessingNode('test_node', NodeSpecialization.CPU_INTENSIVE, 100);
    
    node.registerHandler(PacketGroup.DF, 'test', async (data) => {
      return data.toUpperCase();
    });
    
    const packet = new Packet(PacketGroup.DF, 'test', 'hello', 5);
    
    suite.assert(node.canAccept(packet));
    
    await node.enqueue(packet);
    suite.assert(node.packetQueue.length === 1);
  });

  suite.test('Reactor core integration', async () => {
    const reactor = new ReactorCore();
    const node = reactor.addNode(NodeSpecialization.CPU_INTENSIVE, 100);
    
    node.registerHandler(PacketGroup.DF, 'test', async (data) => {
      return { processed: data };
    });
    
    await reactor.start();
    
    const packet = new Packet(PacketGroup.DF, 'test', 'integration_test', 5);
    const result = await reactor.submitPacket(packet);
    
    suite.assertEqual(result.status, 'success');
    suite.assert(result.data.processed === 'integration_test');
    
    await reactor.stop();
  });

  await suite.run();
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'demo';

  switch (command) {
    case 'demo':
      await runComprehensiveDemo();
      break;
    case 'client':
      await runClientDemo();
      break;
    case 'test':
      await runTests();
      break;
    case 'benchmark':
      const reactor = new ReactorCore();
      const node = reactor.addNode(NodeSpecialization.GENERAL_PURPOSE, 200);
      node.registerHandler(PacketGroup.DF, 'transform', dataFlowHandlers.transform);
      await reactor.start();
      
      const benchmark = new PerformanceBenchmark(reactor);
      await benchmark.runLatencyTest(2000);
      await benchmark.runThroughputTest(15, 8);
      await benchmark.runScalabilityTest(6);
      
      await reactor.stop();
      break;
    default:
      console.log('Available commands:');
      console.log('  demo      - Run comprehensive demonstration');
      console.log('  client    - Run client connection demo');
      console.log('  test      - Run unit tests');
      console.log('  benchmark - Run performance benchmarks');
  }
}

// Run if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}

// Export for use as module
module.exports = {
  PacketGroup,
  BondType,
  NodeSpecialization,
  MessageType,
  Packet,
  ChemicalBond,
  Molecule,
  PacketResult,
  Message,
  PacketHandler,
  ProcessingNode,
  RoutingTable,
  OptimizationEngine,
  FaultDetector,
  ReactorCore,
  WebSocketReactor,
  MolecularPatterns,
  PerformanceBenchmark,
  PacketFlowClient,
  calculateChemicalAffinity
};
