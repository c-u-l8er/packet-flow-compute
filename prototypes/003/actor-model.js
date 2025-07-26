// Pure PacketFlow Actor Model Implementation
// Using ONLY atoms, packets, reactors, and pipelines
// No external actor frameworks - pure PacketFlow primitives

const crypto = require('crypto');
const EventEmitter = require('events');

// ============================================================================
// Core PacketFlow Actor Model
// Actors are represented as specialized reactors with mailboxes
// ============================================================================

class PacketFlowActorSystem {
  constructor() {
    this.reactors = new Map();           // All actor-reactors
    this.mailboxes = new Map();          // Actor mailboxes (packet queues)
    this.supervisors = new Map();        // Supervision hierarchies
    this.routers = new Map();            // Message routing tables
    this.pipelines = new Map();          // Active pipeline actors
    
    // System-level metrics
    this.stats = {
      actors_created: 0,
      messages_sent: 0,
      messages_processed: 0,
      supervision_restarts: 0,
      pipeline_executions: 0
    };
    
    // Core system packets for actor management
    this.registerSystemPackets();
    
    console.log('🎭 Pure PacketFlow Actor System initialized');
  }

  // ========================================================================
  // Actor Creation and Management (using reactor primitives)
  // ========================================================================

  async createActor(actorType, initialState = {}, supervisor = null) {
    const actorId = this.generateActorId();
    
    // Create actor as specialized reactor with built-in packets
    const actorReactor = {
      id: actorId,
      type: actorType,
      state: initialState,
      supervisor: supervisor,
      mailbox: [],
      running: true,
      packets: new Map(),
      created_at: Date.now(),
      message_count: 0,
      restart_count: 0
    };

    // Create mailbox for message queuing
    this.mailboxes.set(actorId, {
      queue: [],
      processing: false,
      max_size: 10000,
      overflow_strategy: 'drop_oldest'
    });

    // Register core actor packets
    this.registerActorPackets(actorReactor);
    
    // Add to reactor registry
    this.reactors.set(actorId, actorReactor);
    
    // Register with supervisor if provided
    if (supervisor) {
      this.addToSupervision(actorId, supervisor);
    }
    
    this.stats.actors_created++;
    
    // Send initialization message
    await this.send(actorId, {
      type: 'init',
      state: initialState,
      sender: 'system'
    });
    
    console.log(`🎭 Actor created: ${actorId} (type: ${actorType})`);
    return actorId;
  }

  async send(targetActorId, message, senderActorId = 'system') {
    // Convert message to PacketFlow atom
    const atom = {
      id: this.generateMessageId(),
      g: 'ac',  // Actor group
      e: 'msg', // Message element
      d: {
        type: message.type || 'message',
        payload: message,
        sender: senderActorId,
        timestamp: Date.now()
      },
      p: message.priority || 5,
      t: message.timeout || 30
    };

    return this.deliverAtom(targetActorId, atom);
  }

  async deliverAtom(targetActorId, atom) {
    const mailbox = this.mailboxes.get(targetActorId);
    const reactor = this.reactors.get(targetActorId);
    
    if (!mailbox || !reactor || !reactor.running) {
      return {
        success: false,
        error: `Actor ${targetActorId} not found or not running`
      };
    }

    // Handle mailbox overflow
    if (mailbox.queue.length >= mailbox.max_size) {
      if (mailbox.overflow_strategy === 'drop_oldest') {
        mailbox.queue.shift();
      } else if (mailbox.overflow_strategy === 'drop_new') {
        return { success: false, error: 'Mailbox full' };
      }
    }

    // Add to mailbox
    mailbox.queue.push(atom);
    this.stats.messages_sent++;

    // Process mailbox if not already processing
    if (!mailbox.processing) {
      this.processMailbox(targetActorId);
    }

    return { success: true, message_id: atom.id };
  }

  async processMailbox(actorId) {
    const mailbox = this.mailboxes.get(actorId);
    const reactor = this.reactors.get(actorId);
    
    if (!mailbox || !reactor || mailbox.processing) return;
    
    mailbox.processing = true;
    
    try {
      while (mailbox.queue.length > 0 && reactor.running) {
        const atom = mailbox.queue.shift();
        
        try {
          await this.processActorMessage(reactor, atom);
          reactor.message_count++;
          this.stats.messages_processed++;
        } catch (error) {
          console.error(`❌ Actor ${actorId} message processing failed:`, error);
          await this.handleActorError(reactor, error, atom);
        }
      }
    } finally {
      mailbox.processing = false;
    }
  }

  async processActorMessage(reactor, atom) {
    const messageType = atom.d.type;
    const packetKey = `ac:${messageType}`;
    
    // Try to find specific packet handler
    let packet = reactor.packets.get(packetKey);
    
    // Fallback to generic message handler
    if (!packet) {
      packet = reactor.packets.get('ac:msg');
    }
    
    if (!packet) {
      throw new Error(`No handler for message type: ${messageType}`);
    }

    // Create actor context
    const context = this.createActorContext(reactor, atom);
    
    // Execute packet handler
    const result = await packet.handler(atom.d, context);
    
    return result;
  }

  createActorContext(reactor, atom) {
    return {
      self: reactor.id,
      sender: atom.d.sender,
      state: reactor.state,
      atom: atom,
      
      // Actor operations
      send: (targetId, message) => this.send(targetId, message, reactor.id),
      spawn: (type, state, supervisor) => this.createActor(type, state, supervisor || reactor.id),
      stop: (reason) => this.stopActor(reactor.id, reason),
      become: (newBehavior) => this.updateActorBehavior(reactor.id, newBehavior),
      
      // State management
      setState: (newState) => {
        reactor.state = { ...reactor.state, ...newState };
      },
      getState: () => reactor.state,
      
      // Pipeline creation
      pipeline: (steps) => this.createPipeline(reactor.id, steps),
      
      // Supervision
      supervise: (childId, strategy) => this.supervise(reactor.id, childId, strategy),
      
      // Utilities
      log: (message) => console.log(`[${reactor.id}] ${message}`),
      schedule: (delay, message) => this.scheduleMessage(reactor.id, delay, message)
    };
  }

  // ========================================================================
  // Supervision System (using packet-based error handling)
  // ========================================================================

  addToSupervision(childId, supervisorId) {
    if (!this.supervisors.has(supervisorId)) {
      this.supervisors.set(supervisorId, {
        children: new Set(),
        strategy: 'one_for_one', // restart only failed child
        max_restarts: 5,
        restart_period: 60000
      });
    }
    
    this.supervisors.get(supervisorId).children.add(childId);
  }

  async handleActorError(reactor, error, failedAtom) {
    console.error(`💥 Actor ${reactor.id} crashed:`, error.message);
    
    if (reactor.supervisor) {
      // Send error notification to supervisor
      await this.send(reactor.supervisor, {
        type: 'child_error',
        child_id: reactor.id,
        error: error.message,
        failed_atom: failedAtom,
        restart_count: reactor.restart_count
      });
      
      // Apply supervision strategy
      await this.applySupervisorStrategy(reactor.supervisor, reactor.id, error);
    } else {
      // No supervisor - stop actor
      await this.stopActor(reactor.id, `Crashed: ${error.message}`);
    }
  }

  async applySupervisorStrategy(supervisorId, failedChildId, error) {
    const supervision = this.supervisors.get(supervisorId);
    if (!supervision) return;
    
    const failedReactor = this.reactors.get(failedChildId);
    if (!failedReactor) return;
    
    // Check restart limits
    if (failedReactor.restart_count >= supervision.max_restarts) {
      console.error(`🚫 Actor ${failedChildId} exceeded restart limit`);
      await this.stopActor(failedChildId, 'Restart limit exceeded');
      return;
    }
    
    switch (supervision.strategy) {
      case 'one_for_one':
        await this.restartActor(failedChildId);
        break;
        
      case 'one_for_all':
        // Restart all children
        for (const childId of supervision.children) {
          await this.restartActor(childId);
        }
        break;
        
      case 'rest_for_one':
        // Restart failed actor and all started after it
        const children = Array.from(supervision.children);
        const failedIndex = children.indexOf(failedChildId);
        for (let i = failedIndex; i < children.length; i++) {
          await this.restartActor(children[i]);
        }
        break;
    }
    
    this.stats.supervision_restarts++;
  }

  async restartActor(actorId) {
    const reactor = this.reactors.get(actorId);
    if (!reactor) return;
    
    console.log(`🔄 Restarting actor: ${actorId}`);
    
    // Clear mailbox
    const mailbox = this.mailboxes.get(actorId);
    if (mailbox) {
      mailbox.queue = [];
      mailbox.processing = false;
    }
    
    // Reset reactor state
    reactor.running = true;
    reactor.restart_count++;
    reactor.message_count = 0;
    
    // Re-register packets
    this.registerActorPackets(reactor);
    
    // Send restart notification
    await this.send(actorId, {
      type: 'restart',
      restart_count: reactor.restart_count,
      sender: 'system'
    });
  }

  // ========================================================================
  // Pipeline Actors (stateful pipeline execution)
  // ========================================================================

  async createPipeline(ownerId, steps) {
    const pipelineId = this.generateActorId();
    
    // Create pipeline as specialized actor
    const pipelineActor = await this.createActor('pipeline', {
      steps: steps,
      current_step: 0,
      input_data: null,
      results: [],
      owner: ownerId
    });
    
    this.pipelines.set(pipelineId, pipelineActor);
    
    // Register pipeline-specific packets
    const reactor = this.reactors.get(pipelineActor);
    this.registerPipelinePackets(reactor);
    
    return pipelineActor;
  }

  async executePipeline(pipelineId, input) {
    return this.send(pipelineId, {
      type: 'execute',
      input: input
    });
  }

  // ========================================================================
  // Packet Registration (behavior definition)
  // ========================================================================

  registerActorPackets(reactor) {
    // Core actor lifecycle packets
    reactor.packets.set('ac:init', {
      handler: async (data, context) => {
        context.log(`Initializing with state: ${JSON.stringify(data.state)}`);
        context.setState(data.state);
        return { initialized: true };
      }
    });

    reactor.packets.set('ac:msg', {
      handler: async (data, context) => {
        // Default message handler - override in specific actor types
        context.log(`Received message: ${data.type}`);
        return { processed: true, type: data.type };
      }
    });

    reactor.packets.set('ac:stop', {
      handler: async (data, context) => {
        context.log(`Stopping: ${data.reason || 'no reason given'}`);
        reactor.running = false;
        return { stopped: true };
      }
    });

    reactor.packets.set('ac:restart', {
      handler: async (data, context) => {
        context.log(`Restarted (count: ${data.restart_count})`);
        // Reset state if needed
        return { restarted: true };
      }
    });

    // Supervision packets
    reactor.packets.set('ac:child_error', {
      handler: async (data, context) => {
        context.log(`Child ${data.child_id} failed: ${data.error}`);
        // Supervisor will handle via supervision strategy
        return { acknowledged: true };
      }
    });

    // Actor type-specific packets
    if (reactor.type === 'counter') {
      this.registerCounterPackets(reactor);
    } else if (reactor.type === 'worker') {
      this.registerWorkerPackets(reactor);
    } else if (reactor.type === 'supervisor') {
      this.registerSupervisorPackets(reactor);
    }
  }

  registerCounterPackets(reactor) {
    reactor.packets.set('ac:increment', {
      handler: async (data, context) => {
        const amount = data.payload.amount || 1;
        const newValue = (context.getState().value || 0) + amount;
        context.setState({ value: newValue });
        context.log(`Incremented by ${amount}, new value: ${newValue}`);
        return { value: newValue };
      }
    });

    reactor.packets.set('ac:decrement', {
      handler: async (data, context) => {
        const amount = data.payload.amount || 1;
        const newValue = (context.getState().value || 0) - amount;
        context.setState({ value: newValue });
        context.log(`Decremented by ${amount}, new value: ${newValue}`);
        return { value: newValue };
      }
    });

    reactor.packets.set('ac:get_value', {
      handler: async (data, context) => {
        const value = context.getState().value || 0;
        return { value };
      }
    });
  }

  registerWorkerPackets(reactor) {
    reactor.packets.set('ac:work', {
      handler: async (data, context) => {
        const task = data.payload.task;
        const workTime = data.payload.work_time || 100;
        
        context.log(`Starting work: ${task}`);
        
        // Simulate work
        await new Promise(resolve => setTimeout(resolve, workTime));
        
        const result = `Task '${task}' completed by ${context.self}`;
        context.log(`Work completed: ${task}`);
        
        // Send result back to sender if specified
        if (data.reply_to) {
          await context.send(data.reply_to, {
            type: 'work_result',
            task: task,
            result: result,
            worker: context.self
          });
        }
        
        return { result, task };
      }
    });

    reactor.packets.set('ac:status', {
      handler: async (data, context) => {
        const state = context.getState();
        return {
          status: 'running',
          tasks_completed: state.tasks_completed || 0,
          uptime: Date.now() - reactor.created_at
        };
      }
    });
  }

  registerSupervisorPackets(reactor) {
    reactor.packets.set('ac:supervise', {
      handler: async (data, context) => {
        const childType = data.payload.child_type;
        const childState = data.payload.child_state || {};
        
        // Create child actor
        const childId = await context.spawn(childType, childState, context.self);
        
        // Track in supervisor state
        const children = context.getState().children || [];
        children.push(childId);
        context.setState({ children });
        
        context.log(`Now supervising child: ${childId}`);
        return { child_id: childId };
      }
    });

    reactor.packets.set('ac:child_error', {
      handler: async (data, context) => {
        context.log(`Child ${data.child_id} reported error: ${data.error}`);
        
        // Apply supervision strategy (handled by system)
        return { error_acknowledged: true };
      }
    });
  }

  registerPipelinePackets(reactor) {
    reactor.packets.set('ac:execute', {
      handler: async (data, context) => {
        const state = context.getState();
        const steps = state.steps;
        let currentData = data.input;
        const results = [];
        
        context.log(`Executing pipeline with ${steps.length} steps`);
        
        for (let i = 0; i < steps.length; i++) {
          const step = steps[i];
          context.setState({ current_step: i });
          
          try {
            // Execute step by sending packet to appropriate reactor
            const stepResult = await this.executeStepPacket(step, currentData);
            results.push(stepResult);
            currentData = stepResult.data; // Chain results
            
            context.log(`Step ${i + 1}/${steps.length} completed`);
          } catch (error) {
            context.log(`Step ${i + 1} failed: ${error.message}`);
            throw error;
          }
        }
        
        context.setState({ results, current_step: steps.length });
        this.stats.pipeline_executions++;
        
        return {
          success: true,
          result: currentData,
          steps_completed: steps.length,
          execution_trace: results
        };
      }
    });
  }

  async executeStepPacket(step, input) {
    // Create atom for step execution
    const atom = {
      id: this.generateMessageId(),
      g: step.g || 'df',
      e: step.e || 'transform',
      d: { ...step.d, input: input },
      p: step.priority || 5,
      t: step.timeout || 30
    };

    // For demo, simulate step execution
    // In real implementation, would route to appropriate reactor
    const result = await this.simulateStepExecution(atom);
    return {
      step: `${atom.g}:${atom.e}`,
      data: result,
      duration: Math.random() * 100
    };
  }

  async simulateStepExecution(atom) {
    // Simulate various packet types
    const { g, e, d } = atom;
    
    if (g === 'df' && e === 'transform') {
      const operation = d.operation || 'uppercase';
      const input = d.input;
      
      switch (operation) {
        case 'uppercase':
          return typeof input === 'string' ? input.toUpperCase() : input;
        case 'lowercase':
          return typeof input === 'string' ? input.toLowerCase() : input;
        case 'double':
          return typeof input === 'number' ? input * 2 : input;
        default:
          return input;
      }
    }
    
    if (g === 'df' && e === 'validate') {
      return { valid: true, input: d.input };
    }
    
    if (g === 'mc' && e === 'analyze') {
      return {
        analysis: 'completed',
        input_type: typeof d.input,
        processed_at: Date.now()
      };
    }
    
    return d.input; // Default passthrough
  }

  registerSystemPackets() {
    // System-level packets for actor management
    // These would be registered with a system reactor
  }

  // ========================================================================
  // Routing and Discovery
  // ========================================================================

  async broadcast(message, actorType = null) {
    const targets = Array.from(this.reactors.values())
      .filter(reactor => !actorType || reactor.type === actorType)
      .map(reactor => reactor.id);
    
    const results = await Promise.allSettled(
      targets.map(actorId => this.send(actorId, message))
    );
    
    return {
      sent_to: targets.length,
      successful: results.filter(r => r.status === 'fulfilled').length,
      failed: results.filter(r => r.status === 'rejected').length
    };
  }

  async stopActor(actorId, reason = 'stopped') {
    await this.send(actorId, { type: 'stop', reason });
    
    // Clean up
    this.reactors.delete(actorId);
    this.mailboxes.delete(actorId);
    this.pipelines.delete(actorId);
    
    // Remove from supervision
    for (const [supervisorId, supervision] of this.supervisors) {
      supervision.children.delete(actorId);
    }
    
    console.log(`🛑 Actor stopped: ${actorId} (${reason})`);
  }

  async scheduleMessage(targetId, delay, message) {
    setTimeout(() => {
      this.send(targetId, message);
    }, delay);
  }

  // ========================================================================
  // System Introspection
  // ========================================================================

  getSystemStats() {
    return {
      ...this.stats,
      active_actors: this.reactors.size,
      mailbox_total_size: Array.from(this.mailboxes.values())
        .reduce((sum, mb) => sum + mb.queue.length, 0),
      supervision_hierarchies: this.supervisors.size
    };
  }

  listActors(type = null) {
    return Array.from(this.reactors.values())
      .filter(reactor => !type || reactor.type === type)
      .map(reactor => ({
        id: reactor.id,
        type: reactor.type,
        running: reactor.running,
        message_count: reactor.message_count,
        restart_count: reactor.restart_count,
        supervisor: reactor.supervisor,
        created_at: reactor.created_at
      }));
  }

  generateActorId() {
    return `actor_${crypto.randomBytes(8).toString('hex')}`;
  }

  generateMessageId() {
    return `msg_${crypto.randomBytes(6).toString('hex')}`;
  }
}

// ============================================================================
// Demo: Pure PacketFlow Actor System
// ============================================================================

async function demonstratePurePacketFlowActors() {
  console.log('🎭 Demonstrating Pure PacketFlow Actor Model\n');
  
  const system = new PacketFlowActorSystem();
  
  // ========================================================================
  // Demo 1: Basic Actor Communication
  // ========================================================================
  console.log('--- Demo 1: Basic Actor Communication ---');
  
  // Create counter actors
  const counter1 = await system.createActor('counter', { value: 0 });
  const counter2 = await system.createActor('counter', { value: 100 });
  
  // Send messages
  await system.send(counter1, { type: 'increment', amount: 5 });
  await system.send(counter1, { type: 'increment', amount: 3 });
  await system.send(counter2, { type: 'decrement', amount: 10 });
  
  // Get values
  const result1 = await system.send(counter1, { type: 'get_value' });
  const result2 = await system.send(counter2, { type: 'get_value' });
  
  console.log('✓ Counter operations completed');
  
  // ========================================================================
  // Demo 2: Supervision Hierarchy
  // ========================================================================
  console.log('\n--- Demo 2: Supervision Hierarchy ---');
  
  // Create supervisor
  const supervisor = await system.createActor('supervisor', {});
  
  // Create supervised workers
  await system.send(supervisor, {
    type: 'supervise',
    child_type: 'worker',
    child_state: { name: 'worker1' }
  });
  
  await system.send(supervisor, {
    type: 'supervise', 
    child_type: 'worker',
    child_state: { name: 'worker2' }
  });
  
  console.log('✓ Supervision hierarchy created');
  
  // ========================================================================
  // Demo 3: Pipeline Actor
  // ========================================================================
  console.log('\n--- Demo 3: Pipeline Actor ---');
  
  const pipeline = await system.createPipeline('demo', [
    { g: 'df', e: 'transform', d: { operation: 'uppercase' } },
    { g: 'df', e: 'validate', d: { schema: 'string' } },
    { g: 'mc', e: 'analyze', d: { analysis: 'text' } }
  ]);
  
  const pipelineResult = await system.executePipeline(pipeline, 'hello world');
  console.log('✓ Pipeline executed');
  
  // ========================================================================
  // Demo 4: Actor Discovery and Broadcasting
  // ========================================================================
  console.log('\n--- Demo 4: Broadcasting ---');
  
  // Create more workers
  await system.createActor('worker', { id: 'w1' });
  await system.createActor('worker', { id: 'w2' });
  await system.createActor('worker', { id: 'w3' });
  
  // Broadcast work to all workers
  const broadcastResult = await system.broadcast({
    type: 'work',
    task: 'process_data',
    work_time: 50
  }, 'worker');
  
  console.log(`✓ Broadcast sent to ${broadcastResult.sent_to} workers`);
  
  // ========================================================================
  // Demo 5: Error Handling and Supervision
  // ========================================================================
  console.log('\n--- Demo 5: Error Handling ---');
  
  // Create actor that will fail
  const faultyActor = await system.createActor('worker', {}, supervisor);
  
  // Simulate error by sending invalid message
  try {
    await system.send(faultyActor, { type: 'invalid_operation' });
  } catch (error) {
    console.log('✓ Error handling triggered');
  }
  
  // ========================================================================
  // System Statistics
  // ========================================================================
  console.log('\n--- System Statistics ---');
  
  const stats = system.getSystemStats();
  console.log('📊 System Stats:', {
    active_actors: stats.active_actors,
    messages_sent: stats.messages_sent,
    messages_processed: stats.messages_processed,
    supervision_restarts: stats.supervision_restarts,
    pipeline_executions: stats.pipeline_executions
  });
  
  const actors = system.listActors();
  console.log('\n👥 Active Actors:');
  actors.forEach(actor => {
    console.log(`  ${actor.id} (${actor.type}) - ${actor.message_count} messages`);
  });
  
  console.log('\n🎯 Pure PacketFlow Actor Model Features Demonstrated:');
  console.log('• ✅ Actors as specialized reactors with mailboxes');
  console.log('• ✅ Message passing via PacketFlow atoms');
  console.log('• ✅ Supervision hierarchies with restart strategies');
  console.log('• ✅ Pipeline actors for stateful processing');
  console.log('• ✅ Behavior definition via packet registration');
  console.log('• ✅ Actor discovery and broadcasting');
  console.log('• ✅ Error handling and fault tolerance');
  console.log('• ✅ System introspection and monitoring');
  console.log('• ✅ 100% PacketFlow primitives - no external frameworks');
  
  return system;
}

// ============================================================================
// Export and CLI
// ============================================================================

module.exports = {
  PacketFlowActorSystem,
  demonstratePurePacketFlowActors
};

// Run demo if executed directly
if (require.main === module) {
  demonstratePurePacketFlowActors()
    .then(() => console.log('\n🎭 Demo completed!'))
    .catch(console.error);
}
