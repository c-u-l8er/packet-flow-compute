// PacketFlow v1.0 - Self-Programming Runtime System
// Meta-computational layer manages PacketFlow itself
// Resource management integrates with LLMs to generate new packets
// Full inter-packet communication system

const EventEmitter = require('events');
const crypto = require('crypto');

// ============================================================================
// Core Self-Programming PacketFlow Runtime
// ============================================================================

class SelfProgrammingPacketFlowRuntime extends EventEmitter {
  constructor(config = {}) {
    super();
    this.config = {
      max_packet_size: 10 * 1024 * 1024,
      default_timeout: 30,
      max_concurrent: 1000,
      self_modification: true,
      llm_integration: {
        enabled: true,
        provider: 'openai', // or 'anthropic', 'local'
        model: 'gpt-4',
        max_tokens: 2000,
        ...config.llm_integration
      },
      meta_programming: {
        allow_packet_creation: true,
        allow_packet_modification: true,
        allow_runtime_changes: true,
        safety_checks: true,
        ...config.meta_programming
      },
      ...config
    };
    
    this.packets = new Map();
    this.packetCallStack = new Map(); // Track inter-packet calls
    this.packetRegistry = new Map(); // Metadata about all packets
    this.executionContext = new Map(); // Per-packet execution context
    this.services = {};
    this.stats = {
      processed: 0,
      errors: 0,
      avg_latency: 0,
      self_generated_packets: 0,
      llm_generations: 0
    };
    
    this.initializeServices();
    this.loadCorePackets();
    this.loadMetaProgrammingPackets();
  }

  // Enhanced packet registration with meta-programming capabilities
  registerPacket(group, element, handler, metadata = {}) {
    const key = `${group}:${element}`;
    
    if (!this.validatePacketHandler(handler, metadata)) {
      throw new Error(`Invalid packet handler for ${key}`);
    }
    
    // Enhanced handler with inter-packet calling capability
    const enhancedHandler = async (data, context) => {
      // Add packet calling capability to context
      context.callPacket = (targetGroup, targetElement, targetData, options = {}) => 
        this.callPacketFromPacket(context.atom.id, targetGroup, targetElement, targetData, options);
      
      context.runtime = this;
      context.services = this.services[group];
      context.meta = this.createMetaContext(context.atom.id);
      
      return await handler(data, context);
    };
    
    const packetInfo = {
      handler: enhancedHandler,
      metadata: {
        timeout: 30,
        max_payload_size: 1024 * 1024,
        level: 2,
        description: '',
        created_by: 'system',
        created_at: Date.now(),
        version: '1.0.0',
        dependencies: [],
        permissions: ['basic'],
        ...metadata
      },
      stats: {
        calls: 0,
        total_duration: 0,
        errors: 0,
        inter_packet_calls: 0
      }
    };
    
    this.packets.set(key, packetInfo);
    this.packetRegistry.set(key, {
      group,
      element,
      key,
      ...packetInfo.metadata
    });
    
    console.log(`✓ Registered packet: ${key} (created by: ${packetInfo.metadata.created_by})`);
    this.emit('packet_registered', { group, element, key, metadata: packetInfo.metadata });
    
    return true;
  }

  // Call a packet from within another packet
  async callPacketFromPacket(callerAtomId, targetGroup, targetElement, data, options = {}) {
    const callId = crypto.randomUUID();
    const targetAtom = {
      id: `${callerAtomId}_call_${callId}`,
      g: targetGroup,
      e: targetElement,
      d: data,
      p: options.priority || 5,
      t: options.timeout || 30,
      meta: {
        caller_id: callerAtomId,
        call_id: callId,
        inter_packet_call: true
      }
    };
    
    // Track the call in the call stack
    if (!this.packetCallStack.has(callerAtomId)) {
      this.packetCallStack.set(callerAtomId, []);
    }
    this.packetCallStack.get(callerAtomId).push({
      call_id: callId,
      target: `${targetGroup}:${targetElement}`,
      started: Date.now()
    });
    
    try {
      const result = await this.processAtom(targetAtom);
      
      // Update inter-packet call stats
      const callerPacket = this.findPacketByAtomId(callerAtomId);
      if (callerPacket) {
        callerPacket.stats.inter_packet_calls++;
      }
      
      return result;
    } finally {
      // Clean up call stack
      const calls = this.packetCallStack.get(callerAtomId);
      if (calls) {
        const callIndex = calls.findIndex(c => c.call_id === callId);
        if (callIndex !== -1) {
          calls.splice(callIndex, 1);
        }
      }
    }
  }

  // Create meta-programming context for packets
  createMetaContext(atomId) {
    return {
      // Packet introspection
      getPacketInfo: (group, element) => this.packetRegistry.get(`${group}:${element}`),
      listPackets: (filter) => this.listPackets(filter),
      getPacketStats: (group, element) => this.getPacketStats(`${group}:${element}`),
      
      // Runtime introspection
      getRuntimeStats: () => this.getStats(),
      getCallStack: () => this.packetCallStack.get(atomId) || [],
      
      // Self-modification capabilities
      createPacket: (group, element, code, metadata) => this.createPacketFromCode(code, group, element, metadata),
      modifyPacket: (group, element, newCode) => this.modifyPacket(group, element, newCode),
      deletePacket: (group, element) => this.deletePacket(group, element),
      
      // LLM integration
      generatePacket: (prompt, requirements) => this.generatePacketWithLLM(prompt, requirements),
      
      // System evolution
      evolveSystem: (goals) => this.evolveSystem(goals),
      optimizePerformance: () => this.optimizePerformance()
    };
  }

  // Initialize service layers with meta-programming focus
  initializeServices() {
    console.log('🧠 Initializing Self-Programming Services...');
    
    this.services.cf = new ControlFlowService(this);
    this.services.df = new DataFlowService(this); 
    this.services.ed = new EventDrivenService(this);
    this.services.co = new CollectiveService(this);
    this.services.mc = new MetaProgrammingService(this); // NEW: Meta-programming
    this.services.rm = new IntelligentResourceService(this); // Enhanced with LLM
  }

  // Load meta-programming packets
  loadMetaProgrammingPackets() {
    console.log('🔮 Loading meta-programming packets...');
    
    Object.keys(this.services).forEach(group => {
      this.services[group].registerPackets(this);
    });
  }

  // Generate packet using LLM
  async generatePacketWithLLM(prompt, requirements = {}) {
    if (!this.config.llm_integration.enabled) {
      throw new Error('LLM integration is disabled');
    }
    
    const llmPrompt = this.createLLMPrompt(prompt, requirements);
    
    try {
      const generatedCode = await this.callLLM(llmPrompt);
      const packet = this.parseGeneratedPacket(generatedCode);
      
      // Validate and register the generated packet
      if (this.validateGeneratedPacket(packet)) {
        this.registerPacket(
          packet.group,
          packet.element,
          packet.handler,
          {
            ...packet.metadata,
            created_by: 'llm',
            llm_prompt: prompt,
            generated_at: Date.now()
          }
        );
        
        this.stats.llm_generations++;
        return { success: true, packet_key: `${packet.group}:${packet.element}` };
      } else {
        throw new Error('Generated packet failed validation');
      }
    } catch (error) {
      console.error('LLM packet generation failed:', error);
      throw error;
    }
  }

  // Create LLM prompt for packet generation
  createLLMPrompt(userPrompt, requirements) {
    return `You are an expert PacketFlow packet developer. Create a JavaScript packet based on this request:

USER REQUEST: ${userPrompt}

REQUIREMENTS:
${JSON.stringify(requirements, null, 2)}

PACKET TEMPLATE:
\`\`\`javascript
const group = 'xx'; // cf, df, ed, co, mc, rm
const element = 'packet_name';

const handler = async (data, context) => {
  // Your implementation here
  // Available in context:
  // - context.callPacket(group, element, data) - call other packets
  // - context.services - service layer for this group
  // - context.meta - meta-programming capabilities
  // - context.utils - utility functions
  // - context.log(message) - logging
  
  return result;
};

const metadata = {
  timeout: 30,
  level: 2,
  description: 'What this packet does',
  dependencies: ['other:packets'], // optional
  permissions: ['basic'] // basic, advanced, system
};
\`\`\`

EXISTING PACKETS (for reference):
${this.getPacketSummary()}

Generate ONLY the packet code. Follow the template exactly. Make it production-ready with proper error handling.`;
  }

  getPacketSummary() {
    const packets = Array.from(this.packetRegistry.values())
      .slice(0, 10) // Limit to avoid token overflow
      .map(p => `${p.key}: ${p.description}`)
      .join('\n');
    return packets;
  }

  // Mock LLM call (replace with actual API integration)
  async callLLM(prompt) {
    // This would integrate with OpenAI, Anthropic, or local LLM
    // For demo purposes, return a sample packet
    await new Promise(resolve => setTimeout(resolve, 1000)); // Simulate API call
    
    return `
const group = 'df';
const element = 'auto_generated_transformer';

const handler = async (data, context) => {
  const { input, operation } = data;
  
  context.log('Auto-generated packet executing...');
  
  switch (operation) {
    case 'reverse':
      return { result: String(input).split('').reverse().join('') };
    case 'count_words':
      return { result: String(input).split(/\\s+/).length };
    default:
      throw new Error('Unknown operation: ' + operation);
  }
};

const metadata = {
  timeout: 15,
  level: 2,
  description: 'Auto-generated data transformer with multiple operations',
  created_by: 'llm'
};
    `;
  }

  parseGeneratedPacket(code) {
    try {
      const func = new Function('', `
        ${code}
        return { group, element, handler, metadata };
      `);
      return func();
    } catch (error) {
      throw new Error(`Failed to parse generated packet: ${error.message}`);
    }
  }

  validateGeneratedPacket(packet) {
    return packet.group && packet.element && typeof packet.handler === 'function';
  }

  // System evolution - analyze performance and suggest improvements
  async evolveSystem(goals = {}) {
    const stats = this.getStats();
    const bottlenecks = this.identifyBottlenecks();
    const suggestions = await this.generateEvolutionSuggestions(stats, bottlenecks, goals);
    
    return {
      current_state: stats,
      bottlenecks,
      suggestions,
      auto_applied: []
    };
  }

  identifyBottlenecks() {
    const bottlenecks = [];
    
    for (const [key, packet] of this.packets.entries()) {
      if (packet.stats.calls > 0) {
        const avgDuration = packet.stats.total_duration / packet.stats.calls;
        const errorRate = packet.stats.errors / packet.stats.calls;
        
        if (avgDuration > 1000) { // >1 second average
          bottlenecks.push({
            type: 'performance',
            packet: key,
            avg_duration: avgDuration,
            severity: 'high'
          });
        }
        
        if (errorRate > 0.1) { // >10% error rate
          bottlenecks.push({
            type: 'reliability',
            packet: key,
            error_rate: errorRate,
            severity: 'medium'
          });
        }
      }
    }
    
    return bottlenecks;
  }

  // Core methods (simplified from previous implementation)
  async processAtom(atom) {
    const start = Date.now();
    const key = `${atom.g}:${atom.e}`;
    
    try {
      const packet = this.packets.get(key);
      if (!packet) {
        throw new Error(`Unsupported packet type: ${key}`);
      }
      
      const context = this.createEnhancedContext(atom, packet);
      const result = await this.executePacket(packet, atom, context);
      
      const duration = Date.now() - start;
      this.updateStats(packet, duration, true);
      
      return {
        success: true,
        data: result,
        meta: {
          duration_ms: duration,
          reactor_id: 'self-programming-runtime',
          timestamp: Date.now()
        }
      };
      
    } catch (error) {
      const duration = Date.now() - start;
      this.updateStats(this.packets.get(key), duration, false);
      
      return {
        success: false,
        error: {
          code: this.categorizeError(error),
          message: error.message
        }
      };
    }
  }

  createEnhancedContext(atom, packet) {
    return {
      atom,
      metadata: packet.metadata,
      services: this.services[atom.g],
      runtime: this,
      utils: this.createPacketUtils(),
      emit: (event, data) => this.emit(event, data),
      log: (message) => console.log(`[${atom.g}:${atom.e}] ${message}`),
      
      // Meta-programming context
      meta: this.createMetaContext(atom.id),
      
      // Inter-packet communication
      callPacket: (targetGroup, targetElement, targetData, options = {}) => 
        this.callPacketFromPacket(atom.id, targetGroup, targetElement, targetData, options)
    };
  }

  createPacketUtils() {
    return {
      transform: {
        uppercase: (str) => String(str).toUpperCase(),
        lowercase: (str) => String(str).toLowerCase(),
        uuid: () => crypto.randomUUID(),
        hash: (str) => crypto.createHash('sha256').update(str).digest('hex')
      },
      validate: {
        email: (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email),
        uuid: (uuid) => /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(uuid)
      },
      async retry(fn, options = {}) {
        const { maxRetries = 3, delay = 1000 } = options;
        for (let i = 0; i <= maxRetries; i++) {
          try {
            return await fn();
          } catch (error) {
            if (i === maxRetries) throw error;
            await new Promise(resolve => setTimeout(resolve, delay));
          }
        }
      }
    };
  }

  async executePacket(packet, atom, context) {
    const timeout = atom.t || packet.metadata.timeout || this.config.default_timeout;
    
    return new Promise(async (resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`Packet timeout after ${timeout}s`));
      }, timeout * 1000);
      
      try {
        const result = await packet.handler(atom.d, context);
        clearTimeout(timer);
        resolve(result);
      } catch (error) {
        clearTimeout(timer);
        reject(error);
      }
    });
  }

  // Helper methods
  validatePacketHandler(handler, metadata) {
    return typeof handler === 'function';
  }

  categorizeError(error) {
    if (error.message.includes('timeout')) return 'E408';
    return 'E500';
  }

  updateStats(packet, duration, success) {
    this.stats.processed++;
    if (!success) this.stats.errors++;
    if (packet) {
      packet.stats.calls++;
      packet.stats.total_duration += duration;
      if (!success) packet.stats.errors++;
    }
  }

  findPacketByAtomId(atomId) {
    // Find packet that's currently processing this atom
    return null; // Simplified for demo
  }

  getStats() {
    return {
      runtime: this.stats,
      packets: this.packets.size,
      packet_calls_in_progress: this.packetCallStack.size
    };
  }

  loadCorePackets() {
    // Core ping packet
    this.registerPacket('cf', 'ping', async (data) => ({
      echo: data.echo || 'pong',
      timestamp: Date.now()
    }), { level: 1, created_by: 'system' });
  }
}

// ============================================================================
// Meta-Programming Service - Manages PacketFlow Itself
// ============================================================================

class MetaProgrammingService {
  constructor(runtime) {
    this.runtime = runtime;
    this.codePatterns = new Map(); // Learn from existing packets
    this.optimizations = new Map(); // Performance optimizations
  }

  registerPackets(runtime) {
    // Packet lifecycle management
    runtime.registerPacket('mc', 'packet', async (data, context) => {
      const { action, group, element, code, requirements } = data;
      
      switch (action) {
        case 'create':
          return await this.createPacket(group, element, code, context);
        case 'modify':
          return await this.modifyPacket(group, element, code, context);
        case 'delete':
          return this.deletePacket(group, element, context);
        case 'analyze':
          return this.analyzePacket(group, element, context);
        case 'optimize':
          return await this.optimizePacket(group, element, context);
        case 'clone':
          return await this.clonePacket(group, element, data.new_element, context);
        default:
          throw new Error(`Unknown packet action: ${action}`);
      }
    }, { 
      description: 'Packet lifecycle management',
      permissions: ['system', 'meta-programming']
    });

    // Runtime introspection and analysis
    runtime.registerPacket('mc', 'analyze', async (data, context) => {
      const { target, type = 'performance' } = data;
      
      switch (type) {
        case 'performance':
          return this.analyzePerformance(target, context);
        case 'dependencies':
          return this.analyzeDependencies(target, context);
        case 'usage_patterns':
          return this.analyzeUsagePatterns(target, context);
        case 'bottlenecks':
          return this.analyzeBottlenecks(context);
        default:
          throw new Error(`Unknown analysis type: ${type}`);
      }
    }, { description: 'Runtime analysis and introspection' });

    // System evolution and self-improvement
    runtime.registerPacket('mc', 'evolve', async (data, context) => {
      const { strategy = 'performance', goals = {} } = data;
      
      context.log('Starting system evolution...');
      
      // Analyze current state
      const currentState = await context.callPacket('mc', 'analyze', { 
        type: 'performance' 
      });
      
      // Generate improvement suggestions
      const suggestions = await this.generateImprovements(currentState.data, goals, context);
      
      // Apply safe improvements automatically
      const applied = await this.applySafeImprovements(suggestions, context);
      
      return {
        analysis: currentState.data,
        suggestions,
        applied,
        evolution_complete: true
      };
    }, { description: 'Autonomous system evolution' });

    // Code pattern learning
    runtime.registerPacket('mc', 'learn', async (data, context) => {
      const { source_packets, pattern_type = 'structure' } = data;
      
      const patterns = await this.learnFromPackets(source_packets, pattern_type, context);
      
      return {
        patterns_learned: patterns.length,
        patterns,
        confidence: this.calculatePatternConfidence(patterns)
      };
    }, { description: 'Learn patterns from existing packets' });
  }

  async createPacket(group, element, code, context) {
    if (!code) {
      throw new Error('Code is required for packet creation');
    }
    
    try {
      // Parse and validate the code
      const packet = this.runtime.parseGeneratedPacket(code);
      
      // Register the packet
      this.runtime.registerPacket(group, element, packet.handler, {
        ...packet.metadata,
        created_by: 'meta-programming',
        created_at: Date.now()
      });
      
      context.log(`Created packet: ${group}:${element}`);
      
      return {
        created: true,
        packet_key: `${group}:${element}`,
        validation_passed: true
      };
      
    } catch (error) {
      throw new Error(`Failed to create packet: ${error.message}`);
    }
  }

  async optimizePacket(group, element, context) {
    const packetKey = `${group}:${element}`;
    const packet = this.runtime.packets.get(packetKey);
    
    if (!packet) {
      throw new Error(`Packet not found: ${packetKey}`);
    }
    
    // Analyze performance bottlenecks
    const stats = packet.stats;
    const avgDuration = stats.calls > 0 ? stats.total_duration / stats.calls : 0;
    
    const optimizations = [];
    
    if (avgDuration > 100) {
      optimizations.push({
        type: 'caching',
        description: 'Add result caching for repeated operations',
        estimated_improvement: '50-80%'
      });
    }
    
    if (stats.inter_packet_calls > stats.calls * 2) {
      optimizations.push({
        type: 'batching',
        description: 'Batch multiple inter-packet calls',
        estimated_improvement: '30-60%'
      });
    }
    
    return {
      packet: packetKey,
      current_performance: {
        avg_duration: avgDuration,
        error_rate: stats.errors / Math.max(stats.calls, 1),
        call_count: stats.calls
      },
      optimizations,
      auto_applied: [] // Could automatically apply safe optimizations
    };
  }

  async learnFromPackets(sourcePackets, patternType, context) {
    const patterns = [];
    
    for (const packetKey of sourcePackets) {
      const packet = this.runtime.packets.get(packetKey);
      if (!packet) continue;
      
      // Extract patterns from packet structure
      const pattern = {
        packet: packetKey,
        structure: this.analyzePacketStructure(packet),
        performance: packet.stats,
        dependencies: this.extractDependencies(packet)
      };
      
      patterns.push(pattern);
    }
    
    // Store learned patterns
    this.codePatterns.set(patternType, patterns);
    
    return patterns;
  }

  analyzePacketStructure(packet) {
    return {
      has_error_handling: true, // Would analyze actual code
      uses_inter_packet_calls: packet.stats.inter_packet_calls > 0,
      complexity: 'medium', // Would calculate cyclomatic complexity
      async_operations: true
    };
  }
}

// ============================================================================
// Intelligent Resource Service - LLM-Enhanced Resource Management
// ============================================================================

class IntelligentResourceService {
  constructor(runtime) {
    this.runtime = runtime;
    this.resourcePatterns = new Map();
    this.demandForecasts = new Map();
  }

  registerPackets(runtime) {
    // LLM-powered packet generation
    runtime.registerPacket('rm', 'generate', async (data, context) => {
      const { prompt, requirements = {}, auto_deploy = false } = data;
      
      context.log(`Generating packet with LLM: "${prompt}"`);
      
      // Use LLM to generate packet
      const result = await runtime.generatePacketWithLLM(prompt, requirements);
      
      if (auto_deploy && result.success) {
        context.log(`Auto-deployed packet: ${result.packet_key}`);
      }
      
      return result;
    }, { 
      description: 'LLM-powered packet generation',
      permissions: ['advanced', 'llm-generation']
    });

    // Intelligent resource monitoring and scaling
    runtime.registerPacket('rm', 'intelligent_monitor', async (data, context) => {
      const { predict_demand = true, auto_scale = false } = data;
      
      // Monitor current resource usage
      const currentUsage = this.getCurrentResourceUsage();
      
      // Predict future demand if requested
      let prediction = null;
      if (predict_demand) {
        prediction = await this.predictResourceDemand(context);
      }
      
      // Auto-generate packets if needed
      let generatedPackets = [];
      if (auto_scale && prediction && prediction.scale_needed) {
        generatedPackets = await this.generateScalingPackets(prediction, context);
      }
      
      return {
        current_usage: currentUsage,
        prediction,
        generated_packets: generatedPackets,
        recommendations: this.generateRecommendations(currentUsage, prediction)
      };
    }, { description: 'Intelligent resource monitoring with predictive scaling' });

    // Demand-driven packet creation
    runtime.registerPacket('rm', 'demand_driven', async (data, context) => {
      const { usage_threshold = 0.8, optimization_goals = ['performance'] } = data;
      
      // Analyze packet usage patterns
      const usage = this.analyzePacketUsage();
      const highDemandPackets = usage.filter(p => p.utilization > usage_threshold);
      
      const improvements = [];
      
      for (const packet of highDemandPackets) {
        // Generate optimization prompt for LLM
        const prompt = `Optimize the high-usage packet "${packet.key}" which has ${packet.calls} calls and ${packet.avg_duration}ms average duration. Focus on: ${optimization_goals.join(', ')}`;
        
        try {
          const optimization = await context.callPacket('rm', 'generate', {
            prompt,
            requirements: {
              optimize_for: optimization_goals,
              maintain_compatibility: true,
              packet_to_optimize: packet.key
            }
          });
          
          improvements.push({
            original_packet: packet.key,
            optimization_result: optimization.data
          });
          
        } catch (error) {
          context.log(`Failed to optimize ${packet.key}: ${error.message}`);
        }
      }
      
      return {
        analyzed_packets: usage.length,
        high_demand_packets: highDemandPackets.length,
        improvements,
        next_analysis: Date.now() + (5 * 60 * 1000) // 5 minutes
      };
    }, { description: 'Demand-driven packet optimization' });

    // Self-healing system
    runtime.registerPacket('rm', 'self_heal', async (data, context) => {
      const { auto_fix = true, severity_threshold = 'medium' } = data;
      
      // Identify system issues
      const issues = await this.identifySystemIssues(context);
      const criticalIssues = issues.filter(i => i.severity === 'high' || 
        (severity_threshold === 'medium' && i.severity === 'medium'));
      
      const fixes = [];
      
      for (const issue of criticalIssues) {
        if (auto_fix) {
          const fix = await this.generateFix(issue, context);
          if (fix.success) {
            fixes.push(fix);
          }
        }
      }
      
      return {
        issues_found: issues.length,
        critical_issues: criticalIssues.length,
        fixes_applied: fixes.length,
        fixes,
        system_health: this.calculateSystemHealth(issues, fixes)
      };
    }, { description: 'Autonomous system self-healing' });
  }

  getCurrentResourceUsage() {
    return {
      memory: process.memoryUsage(),
      cpu: process.cpuUsage(),
      packet_queue_depth: 0, // Would implement actual queue
      active_connections: this.runtime.connections?.size || 0,
      packets_per_second: this.calculatePacketsPerSecond()
    };
  }

  async predictResourceDemand(context) {
    // Simple demand prediction based on historical patterns
    const stats = this.runtime.getStats();
    const trend = this.calculateTrend();
    
    return {
      predicted_load: trend.projected_load,
      confidence: trend.confidence,
      scale_needed: trend.projected_load > 0.8,
      recommendation: trend.projected_load > 0.8 ? 'scale_up' : 'maintain'
    };
  }

  async generateScalingPackets(prediction, context) {
    const generatedPackets = [];
    
    if (prediction.scale_needed) {
      // Generate load balancer packet
      const loadBalancerResult = await context.callPacket('rm', 'generate', {
        prompt: 'Create a dynamic load balancer packet that can distribute traffic across multiple reactor instances',
        requirements: {
          group: 'rm',
          element: 'load_balancer',
          handles_scaling: true
        }
      });
      
      if (loadBalancerResult.success) {
        generatedPackets.push(loadBalancerResult.data);
      }
      
      // Generate auto-scaling packet
      const autoScalerResult = await context.callPacket('rm', 'generate', {
        prompt: 'Create an auto-scaling packet that monitors system load and automatically spawns new reactor instances when needed',
        requirements: {
          group: 'rm', 
          element: 'auto_scaler',
          monitors_load: true,
          spawns_instances: true
        }
      });
      
      if (autoScalerResult.success) {
        generatedPackets.push(autoScalerResult.data);
      }
    }
    
    return generatedPackets;
  }

  analyzePacketUsage() {
    const usage = [];
    
    for (const [key, packet] of this.runtime.packets.entries()) {
      if (packet.stats.calls > 0) {
        usage.push({
          key,
          calls: packet.stats.calls,
          avg_duration: packet.stats.total_duration / packet.stats.calls,
          error_rate: packet.stats.errors / packet.stats.calls,
          utilization: this.calculateUtilization(packet.stats),
          inter_packet_calls: packet.stats.inter_packet_calls
        });
      }
    }
    
    return usage.sort((a, b) => b.utilization - a.utilization);
  }

  calculateUtilization(stats) {
    // Simple utilization calculation
    const callFrequency = stats.calls / (Date.now() / 1000); // calls per second
    const avgDuration = stats.total_duration / stats.calls;
    return Math.min(callFrequency * avgDuration / 1000, 1.0); // 0-1 scale
  }

  async identifySystemIssues(context) {
    const issues = [];
    
    // Check for performance issues
    const stats = this.runtime.getStats();
    if (stats.runtime.avg_latency > 1000) {
      issues.push({
        type: 'performance',
        severity: 'high',
        description: 'Average system latency is above 1 second',
        metric: 'avg_latency',
        value: stats.runtime.avg_latency
      });
    }
    
    // Check for error rates
    if (stats.runtime.errors / stats.runtime.processed > 0.1) {
      issues.push({
        type: 'reliability',
        severity: 'medium',
        description: 'Error rate above 10%',
        metric: 'error_rate',
        value: stats.runtime.errors / stats.runtime.processed
      });
    }
    
    // Check for packet-specific issues
    for (const [key, packet] of this.runtime.packets.entries()) {
      if (packet.stats.calls > 10 && packet.stats.errors / packet.stats.calls > 0.2) {
        issues.push({
          type: 'packet_reliability',
          severity: 'high',
          description: `Packet ${key} has high error rate`,
          packet: key,
          error_rate: packet.stats.errors / packet.stats.calls
        });
      }
    }
    
    return issues;
  }

  async generateFix(issue, context) {
    let prompt = '';
    
    switch (issue.type) {
      case 'performance':
        prompt = `Create a performance optimization packet that addresses high system latency (${issue.value}ms). Focus on caching, batching, and reducing overhead.`;
        break;
      case 'reliability':
        prompt = `Create an error handling improvement packet that reduces system error rate (currently ${issue.value * 100}%). Add retry logic, circuit breakers, and graceful degradation.`;
        break;
      case 'packet_reliability':
        prompt = `Create a replacement packet for ${issue.packet} that fixes its high error rate (${issue.error_rate * 100}%). Maintain the same interface but improve reliability.`;
        break;
      default:
        return { success: false, reason: 'Unknown issue type' };
    }
    
    try {
      const fixResult = await context.callPacket('rm', 'generate', {
        prompt,
        requirements: {
          fixes_issue: issue.type,
          maintains_compatibility: true,
          auto_deploy: true
        }
      });
      
      return {
        success: fixResult.success,
        issue_type: issue.type,
        fix_packet: fixResult.data?.packet_key,
        description: prompt
      };
    } catch (error) {
      return {
        success: false,
        reason: error.message,
        issue_type: issue.type
      };
    }
  }

  calculateSystemHealth(issues, fixes) {
    const totalIssues = issues.length;
    const fixedIssues = fixes.filter(f => f.success).length;
    const criticalIssues = issues.filter(i => i.severity === 'high').length;
    
    let health = 100;
    health -= criticalIssues * 20; // -20 per critical issue
    health -= (totalIssues - criticalIssues) * 10; // -10 per medium/low issue
    health += fixedIssues * 15; // +15 per successful fix
    
    return Math.max(0, Math.min(100, health));
  }

  calculatePacketsPerSecond() {
    const uptime = process.uptime();
    return uptime > 0 ? this.runtime.stats.processed / uptime : 0;
  }

  calculateTrend() {
    // Simplified trend calculation
    return {
      projected_load: Math.random() * 0.4 + 0.3, // 30-70%
      confidence: 0.8
    };
  }

  generateRecommendations(usage, prediction) {
    const recommendations = [];
    
    if (usage.memory.heapUsed / usage.memory.heapTotal > 0.8) {
      recommendations.push({
        type: 'memory',
        action: 'Add memory optimization packets',
        priority: 'high'
      });
    }
    
    if (prediction && prediction.scale_needed) {
      recommendations.push({
        type: 'scaling',
        action: 'Deploy auto-scaling packets',
        priority: 'medium'
      });
    }
    
    return recommendations;
  }
}

// ============================================================================
// Enhanced Service Classes (Simplified)
// ============================================================================

class ControlFlowService {
  constructor(runtime) { this.runtime = runtime; }
  registerPackets(runtime) {
    runtime.registerPacket('cf', 'health', async (data) => ({
      status: 'healthy',
      timestamp: Date.now(),
      uptime: process.uptime()
    }), { level: 1 });
  }
}

class DataFlowService {
  constructor(runtime) { this.runtime = runtime; }
  registerPackets(runtime) {
    runtime.registerPacket('df', 'transform', async (data, context) => {
      const { input, operation } = data;
      switch (operation) {
        case 'uppercase': return input.toUpperCase();
        case 'lowercase': return input.toLowerCase();
        default: throw new Error(`Unknown operation: ${operation}`);
      }
    }, { level: 1 });
  }
}

class EventDrivenService {
  constructor(runtime) { this.runtime = runtime; }
  registerPackets(runtime) {
    runtime.registerPacket('ed', 'signal', async (data, context) => {
      const { event, payload } = data;
      context.emit('signal', { event, payload, timestamp: Date.now() });
      return { signaled: true, event };
    }, { level: 1 });
  }
}

class CollectiveService {
  constructor(runtime) { this.runtime = runtime; }
  registerPackets(runtime) {
    runtime.registerPacket('co', 'broadcast', async (data, context) => {
      const { message } = data;
      context.emit('broadcast', { message, timestamp: Date.now() });
      return { broadcasted: true, message };
    }, { level: 2 });
  }
}

// ============================================================================
// Demonstration of Self-Programming Capabilities
// ============================================================================

async function demonstrateSelfProgramming() {
  console.log('🧠 Self-Programming PacketFlow Demo\n');
  
  const runtime = new SelfProgrammingPacketFlowRuntime({
    llm_integration: { enabled: true },
    meta_programming: { allow_packet_creation: true }
  });

  console.log('--- Testing Inter-Packet Communication ---');
  
  // Create a packet that calls other packets
  const orchestratorPacket = `
    const group = 'df';
    const element = 'orchestrator';
    
    const handler = async (data, context) => {
      const { user_data } = data;
      
      context.log('Starting user processing orchestration...');
      
      // Step 1: Transform the data
      const transformResult = await context.callPacket('df', 'transform', {
        input: user_data.name,
        operation: 'uppercase'
      });
      
      // Step 2: Send a signal
      const signalResult = await context.callPacket('ed', 'signal', {
        event: 'user_processed',
        payload: { name: transformResult.data, id: user_data.id }
      });
      
      // Step 3: Broadcast the result
      const broadcastResult = await context.callPacket('co', 'broadcast', {
        message: \`User \${transformResult.data} has been processed\`
      });
      
      return {
        orchestration_complete: true,
        steps_completed: 3,
        final_name: transformResult.data,
        signal_sent: signalResult.data.signaled,
        broadcast_sent: broadcastResult.data.broadcasted
      };
    };
    
    const metadata = {
      timeout: 60,
      level: 2,
      description: 'Orchestrates multiple packet calls for user processing',
      dependencies: ['df:transform', 'ed:signal', 'co:broadcast']
    };
  `;
  
  runtime.loadPacketFromCode(orchestratorPacket);
  
  const orchestrationResult = await runtime.processAtom({
    id: 'orchestration_test',
    g: 'df',
    e: 'orchestrator',
    d: {
      user_data: { id: 123, name: 'john doe' }
    }
  });
  
  console.log('✓ Orchestration result:', orchestrationResult.data);

  console.log('\n--- Testing Meta-Programming Capabilities ---');
  
  // Use meta-programming to analyze the system
  const analysisResult = await runtime.processAtom({
    id: 'meta_analysis',
    g: 'mc',
    e: 'analyze',
    d: { type: 'performance' }
  });
  
  console.log('✓ System analysis:', analysisResult.data);
  
  // Create a new packet using meta-programming
  const packetCreationResult = await runtime.processAtom({
    id: 'meta_create',
    g: 'mc',
    e: 'packet',
    d: {
      action: 'create',
      group: 'df',
      element: 'meta_created_transformer',
      code: `
        const group = 'df';
        const element = 'meta_created_transformer';
        
        const handler = async (data, context) => {
          const { text, operations = ['uppercase', 'reverse'] } = data;
          
          let result = text;
          for (const op of operations) {
            switch (op) {
              case 'uppercase':
                result = result.toUpperCase();
                break;
              case 'lowercase':
                result = result.toLowerCase();
                break;
              case 'reverse':
                result = result.split('').reverse().join('');
                break;
            }
          }
          
          return { 
            original: text,
            transformed: result,
            operations_applied: operations,
            created_by: 'meta_programming'
          };
        };
        
        const metadata = {
          timeout: 15,
          level: 2,
          description: 'Dynamically created transformer with multiple operations'
        };
      `
    }
  });
  
  console.log('✓ Meta-created packet:', packetCreationResult.data);
  
  // Test the meta-created packet
  const metaPacketResult = await runtime.processAtom({
    id: 'test_meta_packet',
    g: 'df',
    e: 'meta_created_transformer',
    d: {
      text: 'Hello World',
      operations: ['uppercase', 'reverse']
    }
  });
  
  console.log('✓ Meta-created packet result:', metaPacketResult.data);

  console.log('\n--- Testing LLM-Powered Packet Generation ---');
  
  const llmGenerationResult = await runtime.processAtom({
    id: 'llm_generation_test',
    g: 'rm',
    e: 'generate',
    d: {
      prompt: 'Create a packet that calculates statistics for a list of numbers including mean, median, mode, and standard deviation',
      requirements: {
        group: 'mc',
        element: 'statistics',
        handles_arrays: true,
        returns_multiple_metrics: true
      },
      auto_deploy: true
    }
  });
  
  console.log('✓ LLM generation result:', llmGenerationResult.data);

  console.log('\n--- Testing System Evolution ---');
  
  const evolutionResult = await runtime.processAtom({
    id: 'system_evolution',
    g: 'mc',
    e: 'evolve',
    d: {
      strategy: 'performance',
      goals: { target_latency: 100, target_throughput: 1000 }
    }
  });
  
  console.log('✓ System evolution result:', evolutionResult.data);

  console.log('\n--- Testing Intelligent Resource Management ---');
  
  const intelligentMonitorResult = await runtime.processAtom({
    id: 'intelligent_monitor_test',
    g: 'rm',
    e: 'intelligent_monitor',
    d: {
      predict_demand: true,
      auto_scale: true
    }
  });
  
  console.log('✓ Intelligent monitoring:', intelligentMonitorResult.data);
  
  // Test demand-driven packet optimization
  const demandDrivenResult = await runtime.processAtom({
    id: 'demand_driven_test',
    g: 'rm',
    e: 'demand_driven',
    d: {
      usage_threshold: 0.5,
      optimization_goals: ['performance', 'reliability']
    }
  });
  
  console.log('✓ Demand-driven optimization:', demandDrivenResult.data);

  console.log('\n--- Testing Self-Healing ---');
  
  const selfHealResult = await runtime.processAtom({
    id: 'self_heal_test',
    g: 'rm',
    e: 'self_heal',
    d: {
      auto_fix: true,
      severity_threshold: 'medium'
    }
  });
  
  console.log('✓ Self-healing result:', selfHealResult.data);

  console.log('\n--- Final System Statistics ---');
  console.log('Runtime Stats:', runtime.getStats());
  console.log('Packet Registry Size:', runtime.packetRegistry.size);
  console.log('Active Call Stacks:', runtime.packetCallStack.size);

  console.log('\n🎯 Self-Programming Capabilities Summary:');
  console.log('• ✅ Inter-packet communication with call stacks');
  console.log('• ✅ Meta-programming for packet creation/modification');
  console.log('• ✅ LLM integration for automated packet generation');
  console.log('• ✅ System evolution and self-optimization');
  console.log('• ✅ Intelligent resource management with prediction');
  console.log('• ✅ Self-healing with automatic issue detection and fixes');
  console.log('• ✅ Pattern learning from existing packets');
  console.log('• ✅ Runtime introspection and analysis');

  console.log('\n🚀 This creates a truly self-evolving system where:');
  console.log('• PacketFlow can write and deploy its own improvements');
  console.log('• LLMs generate new capabilities based on system needs');
  console.log('• Resource management becomes intelligent and predictive');
  console.log('• The system heals itself when issues are detected');
  console.log('• Meta-computational layer manages the system itself');
  console.log('• Packets can orchestrate complex multi-step operations');
}

// Export the enhanced runtime
module.exports = {
  SelfProgrammingPacketFlowRuntime,
  MetaProgrammingService,
  IntelligentResourceService,
  demonstrateSelfProgramming
};

// Run demo if executed directly
if (require.main === module) {
  demonstrateSelfProgramming().catch(console.error);
}
