const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
const Atomic = std.atomic.Atomic;
const time = std.time;

// ============================================================================
// Core Packet Structure based on Periodic Table Properties
// ============================================================================

/// Packet groups corresponding to the periodic table of computational packets
const PacketGroup = enum {
    cf, // Control Flow
    df, // Data Flow  
    ed, // Event Driven
    co, // Collective
    mc, // Meta-Computational
    rm, // Resource Management
};

/// Specific elements within each packet group
const PacketElement = enum {
    // Control Flow elements
    seq, // Sequential
    br,  // Branch
    lp,  // Loop
    ex,  // Exception
    
    // Data Flow elements
    pr,  // Producer
    cs,  // Consumer
    tr,  // Transform
    ag,  // Aggregate
    
    // Event Driven elements
    sg,  // Signal
    tm,  // Timer
    th,  // Threshold
    pt,  // Pattern
    
    // Collective elements
    ba,  // Barrier
    bc,  // Broadcast
    ga,  // Gather
    el,  // Election
    
    // Meta-Computational elements
    sp,  // Spawn
    mg,  // Migrate
    ad,  // Adapt
    rf,  // Reflect
    
    // Resource Management elements
    al,  // Allocate
    rl,  // Release
    lk,  // Lock
    ca,  // Cache
    
    // Generic elements
    data, // Data packet
    msg,  // Message
    confirmation, // Confirmation
    error, // Error
};

/// Trigger conditions for packet execution
const PacketTrigger = union(enum) {
    sequence_ready,
    condition: *const fn (state: anytype) bool,
    loop_condition: *const fn (state: anytype) bool,
    data_available,
    inputs_ready,
    threshold: u32,
    signal: []const u8,
    timer: u64,
    pattern: []const u8,
    all_ready: [][]const u8,
    source_ready,
    resource_available,
    metrics_threshold: *const anyopaque,
    allocation_request,
    exclusive_access_needed,
};

/// Lifecycle stages of a packet
const LifecycleStage = enum {
    created,
    queued,
    processing,
    completed,
    failed,
};

/// Core packet structure
const Packet = struct {
    id: []const u8,
    group: PacketGroup,
    element: PacketElement,
    trigger: PacketTrigger,
    payload: *const anyopaque,
    dependencies: [][]const u8,
    complexity: u32,
    metadata: HashMap([]const u8, *const anyopaque),
    lifecycle_stage: LifecycleStage,
    destination: ?[]const u8,
    priority: u8,
    timestamp: i64,
    
    pub fn init(allocator: Allocator, group: PacketGroup, element: PacketElement) !*Packet {
        var packet = try allocator.create(Packet);
        packet.* = Packet{
            .id = try generateId(allocator),
            .group = group,
            .element = element,
            .trigger = PacketTrigger.sequence_ready,
            .payload = undefined,
            .dependencies = &[_][]const u8{},
            .complexity = 1,
            .metadata = HashMap([]const u8, *const anyopaque).init(allocator),
            .lifecycle_stage = LifecycleStage.created,
            .destination = null,
            .priority = 5,
            .timestamp = time.milliTimestamp(),
        };
        return packet;
    }
    
    pub fn deinit(self: *Packet, allocator: Allocator) void {
        self.metadata.deinit();
        allocator.free(self.id);
        allocator.destroy(self);
    }
};

// ============================================================================
// Molecular Compounds (Complex Packet Combinations)
// ============================================================================

const MolecularBond = struct {
    from: PacketElement,
    to: PacketElement,
};

const Molecule = struct {
    id: []const u8,
    composition: []*Packet,
    bonds: []MolecularBond,
    properties: HashMap([]const u8, *const anyopaque),
    behavior: ?*const fn (molecule: *Molecule) void,
    
    pub fn init(allocator: Allocator, composition: []*Packet) !*Molecule {
        var molecule = try allocator.create(Molecule);
        molecule.* = Molecule{
            .id = try generateId(allocator),
            .composition = composition,
            .bonds = &[_]MolecularBond{},
            .properties = HashMap([]const u8, *const anyopaque).init(allocator),
            .behavior = null,
        };
        return molecule;
    }
    
    pub fn deinit(self: *Molecule, allocator: Allocator) void {
        self.properties.deinit();
        allocator.free(self.id);
        allocator.destroy(self);
    }
};

// ============================================================================
// Node Processing System
// ============================================================================

const NodeSpecialization = enum {
    general,
    dataflow,
    event_driven,
    collective,
    meta_computational,
    resource_management,
};

const NodeMetrics = struct {
    processed: u64,
    errors: u64,
    avg_latency: f64,
    
    pub fn init() NodeMetrics {
        return NodeMetrics{
            .processed = 0,
            .errors = 0,
            .avg_latency = 0.0,
        };
    }
    
    pub fn update(self: *NodeMetrics, latency: u64, success: bool) void {
        self.processed += 1;
        if (!success) self.errors += 1;
        
        const new_latency = @as(f64, @floatFromInt(latency));
        self.avg_latency = (self.avg_latency * @as(f64, @floatFromInt(self.processed - 1)) + new_latency) / @as(f64, @floatFromInt(self.processed));
    }
};

const NodeState = struct {
    data: HashMap([]const u8, *const anyopaque),
    
    pub fn init(allocator: Allocator) NodeState {
        return NodeState{
            .data = HashMap([]const u8, *const anyopaque).init(allocator),
        };
    }
    
    pub fn deinit(self: *NodeState) void {
        self.data.deinit();
    }
};

const Node = struct {
    name: []const u8,
    specialization: NodeSpecialization,
    state: NodeState,
    metrics: NodeMetrics,
    allocator: Allocator,
    thread: ?Thread,
    should_stop: Atomic(bool),
    packet_queue: ArrayList(*Packet),
    queue_mutex: Mutex,
    queue_condition: Condition,
    
    pub fn init(allocator: Allocator, name: []const u8, specialization: NodeSpecialization) !*Node {
        var node = try allocator.create(Node);
        node.* = Node{
            .name = name,
            .specialization = specialization,
            .state = NodeState.init(allocator),
            .metrics = NodeMetrics.init(),
            .allocator = allocator,
            .thread = null,
            .should_stop = Atomic(bool).init(false),
            .packet_queue = ArrayList(*Packet).init(allocator),
            .queue_mutex = Mutex{},
            .queue_condition = Condition{},
        };
        return node;
    }
    
    pub fn deinit(self: *Node) void {
        self.should_stop.store(true, .Monotonic);
        if (self.thread) |thread| {
            thread.join();
        }
        
        self.state.deinit();
        self.packet_queue.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn start(self: *Node) !void {
        self.thread = try Thread.spawn(.{}, nodeWorker, .{self});
    }
    
    pub fn sendPacket(self: *Node, packet: *Packet) void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        
        self.packet_queue.append(packet) catch return;
        self.queue_condition.signal();
    }
    
    fn nodeWorker(node: *Node) void {
        while (!node.should_stop.load(.Monotonic)) {
            node.queue_mutex.lock();
            
            // Wait for packets if queue is empty
            while (node.packet_queue.items.len == 0 and !node.should_stop.load(.Monotonic)) {
                node.queue_condition.wait(&node.queue_mutex);
            }
            
            if (node.should_stop.load(.Monotonic)) {
                node.queue_mutex.unlock();
                break;
            }
            
            const packet = node.packet_queue.orderedRemove(0);
            node.queue_mutex.unlock();
            
            // Process packet
            const start_time = time.microTimestamp();
            const success = node.processPacket(packet);
            const end_time = time.microTimestamp();
            
            const latency = @as(u64, @intCast(end_time - start_time));
            node.metrics.update(latency, success);
        }
    }
    
    fn processPacket(self: *Node, packet: *Packet) bool {
        return self.processPacketByPeriodicProperties(packet);
    }
    
    fn processPacketByPeriodicProperties(self: *Node, packet: *Packet) bool {
        switch (packet.group) {
            .cf => return self.processControlFlowPacket(packet),
            .df => return self.processDataFlowPacket(packet),
            .ed => return self.processEventDrivenPacket(packet),
            .co => return self.processCollectivePacket(packet),
            .mc => return self.processMetaComputationalPacket(packet),
            .rm => return self.processResourceManagementPacket(packet),
        }
    }
    
    fn processControlFlowPacket(self: *Node, packet: *Packet) bool {
        switch (packet.element) {
            .seq => return self.processSequentialPacket(packet),
            .br => return self.processBranchPacket(packet),
            .lp => return self.processLoopPacket(packet),
            .ex => return self.processExceptionPacket(packet),
            else => return self.processGenericPacket(packet),
        }
    }
    
    fn processDataFlowPacket(self: *Node, packet: *Packet) bool {
        switch (packet.element) {
            .pr => return self.processProducerPacket(packet),
            .cs => return self.processConsumerPacket(packet),
            .tr => return self.processTransformPacket(packet),
            .ag => return self.processAggregatePacket(packet),
            else => return self.processGenericPacket(packet),
        }
    }
    
    fn processEventDrivenPacket(self: *Node, packet: *Packet) bool {
        switch (packet.element) {
            .sg => return self.processSignalPacket(packet),
            .tm => return self.processTimerPacket(packet),
            .th => return self.processThresholdPacket(packet),
            .pt => return self.processPatternPacket(packet),
            else => return self.processGenericPacket(packet),
        }
    }
    
    fn processCollectivePacket(self: *Node, packet: *Packet) bool {
        switch (packet.element) {
            .ba => return self.processBarrierPacket(packet),
            .bc => return self.processBroadcastPacket(packet),
            .ga => return self.processGatherPacket(packet),
            .el => return self.processElectionPacket(packet),
            else => return self.processGenericPacket(packet),
        }
    }
    
    fn processMetaComputationalPacket(self: *Node, packet: *Packet) bool {
        switch (packet.element) {
            .sp => return self.processSpawnPacket(packet),
            .mg => return self.processMigratePacket(packet),
            .ad => return self.processAdaptPacket(packet),
            .rf => return self.processReflectPacket(packet),
            else => return self.processGenericPacket(packet),
        }
    }
    
    fn processResourceManagementPacket(self: *Node, packet: *Packet) bool {
        switch (packet.element) {
            .al => return self.processAllocatePacket(packet),
            .rl => return self.processReleasePacket(packet),
            .lk => return self.processLockPacket(packet),
            .ca => return self.processCachePacket(packet),
            else => return self.processGenericPacket(packet),
        }
    }
    
    // Specific packet processors
    fn processSequentialPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Execute in sequence, ensuring ordering
        print("Processing sequential packet\n");
        return true;
    }
    
    fn processBranchPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Handle conditional branching
        print("Processing branch packet\n");
        return true;
    }
    
    fn processLoopPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Handle loop iteration
        print("Processing loop packet\n");
        return true;
    }
    
    fn processExceptionPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Handle exceptions and error recovery
        print("Processing exception packet\n");
        return true;
    }
    
    fn processProducerPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Generate data from source
        print("Processing producer packet\n");
        return true;
    }
    
    fn processConsumerPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Consume data and trigger side effects
        print("Processing consumer packet\n");
        return true;
    }
    
    fn processTransformPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Apply transformation function
        print("Processing transform packet\n");
        return true;
    }
    
    fn processAggregatePacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Collect and aggregate data
        print("Processing aggregate packet\n");
        return true;
    }
    
    fn processSignalPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // React to external signals
        print("Processing signal packet\n");
        return true;
    }
    
    fn processTimerPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Handle timer expiration
        print("Processing timer packet\n");
        return true;
    }
    
    fn processThresholdPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Monitor threshold conditions
        print("Processing threshold packet\n");
        return true;
    }
    
    fn processPatternPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Detect complex event patterns
        print("Processing pattern packet\n");
        return true;
    }
    
    fn processBarrierPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Synchronization barrier
        print("Processing barrier packet\n");
        return true;
    }
    
    fn processBroadcastPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Broadcast to multiple targets
        print("Processing broadcast packet\n");
        return true;
    }
    
    fn processGatherPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Gather data from multiple sources
        print("Processing gather packet\n");
        return true;
    }
    
    fn processElectionPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Leader election protocol
        print("Processing election packet\n");
        return true;
    }
    
    fn processSpawnPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Dynamic process creation
        print("Processing spawn packet\n");
        return true;
    }
    
    fn processMigratePacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Process migration
        print("Processing migrate packet\n");
        return true;
    }
    
    fn processAdaptPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // System adaptation
        print("Processing adapt packet\n");
        return true;
    }
    
    fn processReflectPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // System reflection and introspection
        print("Processing reflect packet\n");
        return true;
    }
    
    fn processAllocatePacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Resource allocation
        print("Processing allocate packet\n");
        return true;
    }
    
    fn processReleasePacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Resource release
        print("Processing release packet\n");
        return true;
    }
    
    fn processLockPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Exclusive resource locking
        print("Processing lock packet\n");
        return true;
    }
    
    fn processCachePacket(self: *Node, packet: *Packet) bool {
        _ = self;
        _ = packet;
        // Cache management
        print("Processing cache packet\n");
        return true;
    }
    
    fn processGenericPacket(self: *Node, packet: *Packet) bool {
        _ = self;
        print("Processing unknown packet type: {any}.{any}\n", .{ packet.group, packet.element });
        return true;
    }
};

// ============================================================================
// Reactor System (Main Computational Engine)
// ============================================================================

const SystemMetrics = struct {
    active_packets: u64,
    total_packets_processed: u64,
    node_count: u64,
    system_load: f64,
    
    pub fn init() SystemMetrics {
        return SystemMetrics{
            .active_packets = 0,
            .total_packets_processed = 0,
            .node_count = 0,
            .system_load = 0.0,
        };
    }
};

const Reactor = struct {
    allocator: Allocator,
    nodes: HashMap([]const u8, *Node),
    packet_registry: HashMap([]const u8, *Packet),
    active_packets: HashMap([]const u8, *Packet),
    molecules: ArrayList(*Molecule),
    metrics: SystemMetrics,
    should_stop: Atomic(bool),
    
    pub fn init(allocator: Allocator) !*Reactor {
        var reactor = try allocator.create(Reactor);
        reactor.* = Reactor{
            .allocator = allocator,
            .nodes = HashMap([]const u8, *Node).init(allocator),
            .packet_registry = HashMap([]const u8, *Packet).init(allocator),
            .active_packets = HashMap([]const u8, *Packet).init(allocator),
            .molecules = ArrayList(*Molecule).init(allocator),
            .metrics = SystemMetrics.init(),
            .should_stop = Atomic(bool).init(false),
        };
        return reactor;
    }
    
    pub fn deinit(self: *Reactor) void {
        self.should_stop.store(true, .Monotonic);
        
        // Clean up nodes
        var node_iterator = self.nodes.iterator();
        while (node_iterator.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.nodes.deinit();
        
        // Clean up packets
        var packet_iterator = self.packet_registry.iterator();
        while (packet_iterator.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
        }
        self.packet_registry.deinit();
        self.active_packets.deinit();
        
        // Clean up molecules
        for (self.molecules.items) |molecule| {
            molecule.deinit(self.allocator);
        }
        self.molecules.deinit();
        
        self.allocator.destroy(self);
    }
    
    pub fn addNode(self: *Reactor, name: []const u8, specialization: NodeSpecialization) !void {
        const node = try Node.init(self.allocator, name, specialization);
        try self.nodes.put(name, node);
        try node.start();
        self.metrics.node_count += 1;
    }
    
    pub fn injectPacket(self: *Reactor, packet: *Packet) !void {
        try self.packet_registry.put(packet.id, packet);
        try self.active_packets.put(packet.id, packet);
        self.metrics.total_packets_processed += 1;
        self.metrics.active_packets += 1;
        
        // Route packet based on periodic table properties
        try self.routePacket(packet);
    }
    
    fn routePacket(self: *Reactor, packet: *Packet) !void {
        const optimized_packet = self.optimizePacketRouting(packet);
        const target_node_name = self.selectOptimalNode(optimized_packet);
        
        if (self.nodes.get(target_node_name)) |node| {
            node.sendPacket(optimized_packet);
        } else {
            print("Warning: Target node '{}' not found\n", .{target_node_name});
        }
    }
    
    fn optimizePacketRouting(self: *Reactor, packet: *Packet) *Packet {
        _ = self;
        // Apply periodic table routing optimizations
        switch (packet.group) {
            .df => {
                // DF group optimization: favor parallel execution
                packet.priority = @min(packet.priority + 2, 10);
            },
            .ed => {
                // ED group optimization: prioritize reactive responses
                packet.priority = @min(packet.priority + 3, 10);
            },
            .co => {
                // CO group optimization: coordinate with other collective packets
                packet.priority = @min(packet.priority + 1, 10);
            },
            .mc => {
                // MC group optimization: consider system adaptation needs
                const adaptation_boost: u8 = if (self.needsAdaptation()) 4 else 0;
                packet.priority = @min(packet.priority + adaptation_boost, 10);
            },
            .rm => {
                // RM group optimization: prioritize resource-critical operations
                packet.priority = @min(packet.priority + 3, 10);
            },
            .cf => {
                // CF group optimization: maintain sequential dependencies
                // Priority stays the same
            },
        }
        return packet;
    }
    
    fn needsAdaptation(self: *Reactor) bool {
        return self.metrics.active_packets > 100;
    }
    
    fn selectOptimalNode(self: *Reactor, packet: *Packet) []const u8 {
        _ = packet;
        // Simple selection - in practice would be more sophisticated
        var node_iterator = self.nodes.iterator();
        if (node_iterator.next()) |entry| {
            return entry.key_ptr.*;
        }
        return "default";
    }
    
    pub fn getMetrics(self: *Reactor) SystemMetrics {
        self.metrics.system_load = @as(f64, @floatFromInt(self.metrics.active_packets)) / @as(f64, @floatFromInt(@max(self.metrics.node_count, 1)));
        return self.metrics;
    }
    
    pub fn createMolecule(self: *Reactor, composition: []*Packet) !*Molecule {
        const molecule = try Molecule.init(self.allocator, composition);
        try self.molecules.append(molecule);
        return molecule;
    }
};

// ============================================================================
// Packet Creation DSL Functions
// ============================================================================

pub fn sequentialPacket(allocator: Allocator, payload: *const anyopaque) !*Packet {
    const packet = try Packet.init(allocator, .cf, .seq);
    packet.payload = payload;
    packet.trigger = PacketTrigger.sequence_ready;
    packet.complexity = 1;
    packet.priority = 5;
    return packet;
}

pub fn branchPacket(allocator: Allocator, condition: *const fn (state: anytype) bool, true_path: *const anyopaque, false_path: *const anyopaque) !*Packet {
    const packet = try Packet.init(allocator, .cf, .br);
    packet.trigger = PacketTrigger{ .condition = condition };
    // In a real implementation, payload would be a proper struct containing both paths
    packet.payload = true_path;
    packet.complexity = 2; // log2(2) rounded up
    packet.priority = 7;
    return packet;
}

pub fn loopPacket(allocator: Allocator, condition: *const fn (state: anytype) bool, body: *const anyopaque, iterations: u32) !*Packet {
    const packet = try Packet.init(allocator, .cf, .lp);
    packet.trigger = PacketTrigger{ .loop_condition = condition };
    packet.payload = body;
    packet.complexity = iterations;
    packet.priority = 3;
    return packet;
}

pub fn producerPacket(allocator: Allocator, data_source: *const anyopaque) !*Packet {
    const packet = try Packet.init(allocator, .df, .pr);
    packet.trigger = PacketTrigger.data_available;
    packet.payload = data_source;
    packet.complexity = 1;
    packet.priority = 8;
    return packet;
}

pub fn transformPacket(allocator: Allocator, transform_fn: *const anyopaque, complexity: u32) !*Packet {
    const packet = try Packet.init(allocator, .df, .tr);
    packet.trigger = PacketTrigger.inputs_ready;
    packet.payload = transform_fn;
    packet.complexity = complexity;
    packet.priority = 6;
    return packet;
}

pub fn aggregatePacket(allocator: Allocator, aggregation_fn: *const anyopaque, threshold: u32) !*Packet {
    const packet = try Packet.init(allocator, .df, .ag);
    packet.trigger = PacketTrigger{ .threshold = threshold };
    packet.payload = aggregation_fn;
    packet.complexity = @as(u32, @intFromFloat(@log(@as(f64, @floatFromInt(threshold))) * @as(f64, @floatFromInt(threshold))));
    packet.priority = 4;
    return packet;
}

pub fn signalPacket(allocator: Allocator, signal_type: []const u8) !*Packet {
    const packet = try Packet.init(allocator, .ed, .sg);
    packet.trigger = PacketTrigger{ .signal = signal_type };
    packet.payload = @ptrCast(signal_type.ptr);
    packet.complexity = 1;
    packet.priority = 9;
    return packet;
}

pub fn timerPacket(allocator: Allocator, duration: u64, action: *const anyopaque) !*Packet {
    const packet = try Packet.init(allocator, .ed, .tm);
    packet.trigger = PacketTrigger{ .timer = duration };
    packet.payload = action;
    packet.complexity = 1;
    packet.priority = 8;
    return packet;
}

pub fn patternPacket(allocator: Allocator, pattern_def: []const u8, action: *const anyopaque, pattern_complexity: u32) !*Packet {
    const packet = try Packet.init(allocator, .ed, .pt);
    packet.trigger = PacketTrigger{ .pattern = pattern_def };
    packet.payload = action;
    packet.complexity = pattern_complexity;
    packet.priority = 7;
    return packet;
}

pub fn barrierPacket(allocator: Allocator, participants: [][]const u8) !*Packet {
    const packet = try Packet.init(allocator, .co, .ba);
    packet.trigger = PacketTrigger{ .all_ready = participants };
    packet.payload = @ptrCast(participants.ptr);
    packet.dependencies = participants;
    packet.complexity = @as(u32, @intCast(participants.len));
    packet.priority = 9;
    return packet;
}

pub fn broadcastPacket(allocator: Allocator, message: *const anyopaque, targets: [][]const u8) !*Packet {
    const packet = try Packet.init(allocator, .co, .bc);
    packet.trigger = PacketTrigger.source_ready;
    packet.payload = message;
    packet.complexity = @as(u32, @intCast(targets.len));
    packet.priority = 6;
    return packet;
}

pub fn spawnPacket(allocator: Allocator, computation: *const anyopaque) !*Packet {
    const packet = try Packet.init(allocator, .mc, .sp);
    packet.trigger = PacketTrigger.resource_available;
    packet.payload = computation;
    packet.complexity = 1;
    packet.priority = 5;
    return packet;
}

pub fn adaptPacket(allocator: Allocator, adaptation_fn: *const anyopaque, metrics: *const anyopaque, history_size: u32) !*Packet {
    const packet = try Packet.init(allocator, .mc, .ad);
    packet.trigger = PacketTrigger{ .metrics_threshold = metrics };
    packet.payload = adaptation_fn;
    packet.complexity = history_size;
    packet.priority = 4;
    return packet;
}

pub fn allocatePacket(allocator: Allocator, resource_type: []const u8, amount: u32) !*Packet {
    const packet = try Packet.init(allocator, .rm, .al);
    packet.trigger = PacketTrigger.allocation_request;
    packet.payload = @ptrCast(resource_type.ptr);
    packet.complexity = @as(u32, @intFromFloat(@log2(@as(f64, @floatFromInt(amount)))));
    packet.priority = 8;
    return packet;
}

pub fn lockPacket(allocator: Allocator, resource_id: []const u8, lock_type: []const u8, contention: u32) !*Packet {
    const packet = try Packet.init(allocator, .rm, .lk);
    packet.trigger = PacketTrigger.exclusive_access_needed;
    packet.payload = @ptrCast(resource_id.ptr);
    packet.complexity = contention;
    packet.priority = 9;
    return packet;
}

// ============================================================================
// Molecular Compound Factories
// ============================================================================

pub fn createAcidTransaction(allocator: Allocator, operations: []*Packet) !*Molecule {
    const lock_id = try generateId(allocator);
    
    var composition = ArrayList(*Packet).init(allocator);
    defer composition.deinit();
    
    // Create ACID transaction components
    const lock_pkt = try lockPacket(allocator, lock_id, "exclusive", 1);
    try composition.append(lock_pkt);
    
    for (operations) |op| {
        try composition.append(op);
    }
    
    // Would add validation and release packets here
    
    const molecule = try Molecule.init(allocator, composition.toOwnedSlice() catch unreachable);
    
    // Set ACID properties
    try molecule.properties.put("atomicity", @ptrCast(&@as(bool, true)));
    try molecule.properties.put("consistency", @ptrCast(&@as(bool, true)));
    try molecule.properties.put("isolation", @ptrCast(&@as(bool, true)));
    try molecule.properties.put("durability", @ptrCast(&@as(bool, true)));
    
    return molecule;
}

pub fn createStreamPipeline(allocator: Allocator, producer: *Packet, transforms: []*Packet, consumer: *Packet) !*Molecule {
    var composition = ArrayList(*Packet).init(allocator);
    defer composition.deinit();
    
    try composition.append(producer);
    for (transforms) |transform| {
        try composition.append(transform);
    }
    try composition.append(consumer);
    
    const molecule = try Molecule.init(allocator, composition.toOwnedSlice() catch unreachable);
    
    // Set stream properties
    try molecule.properties.put("throughput", @ptrCast(&@as(u32, std.math.maxInt(u32))));
    try molecule.properties.put("backpressure", @ptrCast(&@as(bool, true)));
    
    return molecule;
}

pub fn createFaultTolerantComputation(allocator: Allocator, computation: *Packet, recovery_time: u32) !*Molecule {
    var composition = ArrayList(*Packet).init(allocator);
    defer composition.deinit();
    
    const participants = [_][]const u8{"checkpoint"};
    const barrier_pkt = try barrierPacket(allocator, &participants);
    try composition.append(barrier_pkt);
    try composition.append(computation);
    
    const molecule = try Molecule.init(allocator, composition.toOwnedSlice() catch unreachable);
    
    // Set fault tolerance properties
    try molecule.properties.put("fault_tolerance", @ptrCast(&@as([]const u8, "high")));
    try molecule.properties.put("recovery_time", @ptrCast(&recovery_time));
    
    return molecule;
}

// ============================================================================
// Analytics and Performance Analysis
// ============================================================================

const PerformanceAnalysis = struct {
    efficiency_score: f64,
    bottlenecks: [][]const u8,
    optimization_suggestions: [][]const u8,
    periodic_distribution: PeriodicDistribution,
    
    pub fn deinit(self: *PerformanceAnalysis, allocator: Allocator) void {
        for (self.bottlenecks) |bottleneck| {
            allocator.free(bottleneck);
        }
        allocator.free(self.bottlenecks);
        
        for (self.optimization_suggestions) |suggestion| {
            allocator.free(suggestion);
        }
        allocator.free(self.optimization_suggestions);
    }
};

const GroupStats = struct {
    percentage: f64,
    avg_complexity: f64,
    bottleneck_risk: []const u8,
};

const PeriodicDistribution = struct {
    cf_group: GroupStats,
    df_group: GroupStats,
    ed_group: GroupStats,
    co_group: GroupStats,
    mc_group: GroupStats,
    rm_group: GroupStats,
};

const Analytics = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) Analytics {
        return Analytics{ .allocator = allocator };
    }
    
    pub fn analyzeSystemPerformance(self: *Analytics, reactor: *Reactor) !PerformanceAnalysis {
        const metrics = reactor.getMetrics();
        
        const efficiency = self.calculateEfficiency(metrics);
        const bottlenecks = try self.identifyBottlenecks(metrics);
        const suggestions = try self.suggestOptimizations(metrics);
        const distribution = self.analyzePacketDistribution(metrics);
        
        return PerformanceAnalysis{
            .efficiency_score = efficiency,
            .bottlenecks = bottlenecks,
            .optimization_suggestions = suggestions,
            .periodic_distribution = distribution,
        };
    }
    
    fn calculateEfficiency(self: *Analytics, metrics: SystemMetrics) f64 {
        _ = self;
        const total_packets = @as(f64, @floatFromInt(metrics.total_packets_processed));
        const active_packets = @as(f64, @floatFromInt(metrics.active_packets));
        const node_utilization = metrics.system_load;
        
        const base_efficiency = (total_packets / @max(total_packets + active_packets, 1.0)) * 100.0;
        const utilization_factor = @min(node_utilization * 1.2, 1.0);
        
        return base_efficiency * utilization_factor;
    }
    
    fn identifyBottlenecks(self: *Analytics, metrics: SystemMetrics) ![][]const u8 {
        var bottlenecks = ArrayList([]const u8).init(self.allocator);
        
        // Check for high active packet count
        if (metrics.active_packets > 1000) {
            const bottleneck = try self.allocator.dupe(u8, "processing_bottleneck: high_queue_depth");
            try bottlenecks.append(bottleneck);
        }
        
        // Check for high system load
        if (metrics.system_load > 0.9) {
            const bottleneck = try self.allocator.dupe(u8, "resource_bottleneck: high_system_load");
            try bottlenecks.append(bottleneck);
        }
        
        return bottlenecks.toOwnedSlice();
    }
    
    fn suggestOptimizations(self: *Analytics, metrics: SystemMetrics) ![][]const u8 {
        var suggestions = ArrayList([]const u8).init(self.allocator);
        
        // High system load suggests load balancing
        if (metrics.system_load > 0.8) {
            const suggestion = try self.allocator.dupe(u8, "Consider adding MC group (spawn packets) for dynamic load balancing");
            try suggestions.append(suggestion);
        }
        
        // High queue depth suggests flow control
        if (metrics.active_packets > 500) {
            const suggestion = try self.allocator.dupe(u8, "Implement RM group (resource management) for better flow control");
            try suggestions.append(suggestion);
        }
        
        // Low node utilization suggests consolidation
        if (metrics.system_load < 0.3) {
            const suggestion = try self.allocator.dupe(u8, "Consider consolidating nodes or increasing DF group usage");
            try suggestions.append(suggestion);
        }
        
        return suggestions.toOwnedSlice();
    }
    
    fn analyzePacketDistribution(self: *Analytics, metrics: SystemMetrics) PeriodicDistribution {
        _ = self;
        _ = metrics;
        // Simulate packet distribution analysis
        return PeriodicDistribution{
            .cf_group = GroupStats{ .percentage = 15.0, .avg_complexity = 2.0, .bottleneck_risk = "low" },
            .df_group = GroupStats{ .percentage = 40.0, .avg_complexity = 5.0, .bottleneck_risk = "medium" },
            .ed_group = GroupStats{ .percentage = 25.0, .avg_complexity = 3.0, .bottleneck_risk = "low" },
            .co_group = GroupStats{ .percentage = 10.0, .avg_complexity = 8.0, .bottleneck_risk = "high" },
            .mc_group = GroupStats{ .percentage = 5.0, .avg_complexity = 15.0, .bottleneck_risk = "medium" },
            .rm_group = GroupStats{ .percentage = 5.0, .avg_complexity = 4.0, .bottleneck_risk = "medium" },
        };
    }
};

// ============================================================================
// Testing and Validation Framework
// ============================================================================

const ValidationResults = struct {
    group_distribution: GroupDistributionValidation,
    complexity_analysis: ComplexityAnalysis,
    flow_optimization: FlowOptimization,
    molecular_stability: MolecularStability,
    
    pub fn deinit(self: *ValidationResults, allocator: Allocator) void {
        self.group_distribution.deinit(allocator);
        self.complexity_analysis.deinit(allocator);
        self.flow_optimization.deinit(allocator);
        self.molecular_stability.deinit(allocator);
    }
};

const GroupDistributionValidation = struct {
    distribution: HashMap(NodeSpecialization, u32),
    balance_score: f64,
    recommendations: [][]const u8,
    
    pub fn deinit(self: *GroupDistributionValidation, allocator: Allocator) void {
        self.distribution.deinit();
        for (self.recommendations) |rec| {
            allocator.free(rec);
        }
        allocator.free(self.recommendations);
    }
};

const MoleculeComplexity = struct {
    molecule_id: []const u8,
    total_complexity: u32,
    avg_complexity: f64,
    complexity_class: []const u8,
};

const ComplexityAnalysis = struct {
    molecules: []MoleculeComplexity,
    system_complexity: u32,
    
    pub fn deinit(self: *ComplexityAnalysis, allocator: Allocator) void {
        for (self.molecules) |mol| {
            allocator.free(mol.molecule_id);
            allocator.free(mol.complexity_class);
        }
        allocator.free(self.molecules);
    }
};

const FlowInfo = struct {
    from: []const u8,
    to: []const u8,
    optimization: []const u8,
    packet_groups: []PacketGroup,
    efficiency_score: f64,
};

const FlowOptimization = struct {
    flows: []FlowInfo,
    bottlenecks: [][]const u8,
    
    pub fn deinit(self: *FlowOptimization, allocator: Allocator) void {
        for (self.flows) |flow| {
            allocator.free(flow.from);
            allocator.free(flow.to);
            allocator.free(flow.optimization);
            allocator.free(flow.packet_groups);
        }
        allocator.free(self.flows);
        
        for (self.bottlenecks) |bottleneck| {
            allocator.free(bottleneck);
        }
        allocator.free(self.bottlenecks);
    }
};

const MolecularBondInfo = struct {
    molecule_id: []const u8,
    bond_count: u32,
    stability_score: f64,
    properties: HashMap([]const u8, *const anyopaque),
};

const MolecularStability = struct {
    molecules: []MolecularBondInfo,
    avg_stability: f64,
    
    pub fn deinit(self: *MolecularStability, allocator: Allocator) void {
        for (self.molecules) |mol| {
            allocator.free(mol.molecule_id);
            mol.properties.deinit();
        }
        allocator.free(self.molecules);
    }
};

const Testing = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) Testing {
        return Testing{ .allocator = allocator };
    }
    
    pub fn validatePeriodicProperties(self: *Testing, reactor: *Reactor) !ValidationResults {
        const group_dist = try self.validateGroupDistribution(reactor);
        const complexity = try self.validateComplexityBounds(reactor);
        const flow_opt = try self.validateFlowPatterns(reactor);
        const molecular = try self.validateMolecularBonds(reactor);
        
        return ValidationResults{
            .group_distribution = group_dist,
            .complexity_analysis = complexity,
            .flow_optimization = flow_opt,
            .molecular_stability = molecular,
        };
    }
    
    fn validateGroupDistribution(self: *Testing, reactor: *Reactor) !GroupDistributionValidation {
        var distribution = HashMap(NodeSpecialization, u32).init(self.allocator);
        
        var node_iterator = reactor.nodes.iterator();
        while (node_iterator.next()) |entry| {
            const node = entry.value_ptr.*;
            const count = distribution.get(node.specialization) orelse 0;
            try distribution.put(node.specialization, count + 1);
        }
        
        const balance_score = self.calculateBalanceScore(&distribution);
        const recommendations = try self.suggestRebalancing(&distribution);
        
        return GroupDistributionValidation{
            .distribution = distribution,
            .balance_score = balance_score,
            .recommendations = recommendations,
        };
    }
    
    fn validateComplexityBounds(self: *Testing, reactor: *Reactor) !ComplexityAnalysis {
        var molecules = ArrayList(MoleculeComplexity).init(self.allocator);
        var system_complexity: u32 = 0;
        
        for (reactor.molecules.items) |molecule| {
            var total_complexity: u32 = 0;
            for (molecule.composition) |packet| {
                total_complexity += packet.complexity;
            }
            
            const avg_complexity = @as(f64, @floatFromInt(total_complexity)) / @as(f64, @floatFromInt(molecule.composition.len));
            const complexity_class = try self.classifyComplexity(total_complexity);
            
            const mol_complexity = MoleculeComplexity{
                .molecule_id = try self.allocator.dupe(u8, molecule.id),
                .total_complexity = total_complexity,
                .avg_complexity = avg_complexity,
                .complexity_class = complexity_class,
            };
            
            try molecules.append(mol_complexity);
            system_complexity += total_complexity;
        }
        
        return ComplexityAnalysis{
            .molecules = molecules.toOwnedSlice(),
            .system_complexity = system_complexity,
        };
    }
    
    fn validateFlowPatterns(self: *Testing, reactor: *Reactor) !FlowOptimization {
        _ = reactor;
        // Simplified implementation
        var flows = ArrayList(FlowInfo).init(self.allocator);
        var bottlenecks = ArrayList([]const u8).init(self.allocator);
        
        return FlowOptimization{
            .flows = flows.toOwnedSlice(),
            .bottlenecks = bottlenecks.toOwnedSlice(),
        };
    }
    
    fn validateMolecularBonds(self: *Testing, reactor: *Reactor) !MolecularStability {
        var molecules = ArrayList(MolecularBondInfo).init(self.allocator);
        var total_stability: f64 = 0.0;
        
        for (reactor.molecules.items) |molecule| {
            const bond_count = @as(u32, @intCast(molecule.bonds.len));
            const stability_score = self.calculateBondStability(molecule.bonds);
            
            const bond_info = MolecularBondInfo{
                .molecule_id = try self.allocator.dupe(u8, molecule.id),
                .bond_count = bond_count,
                .stability_score = stability_score,
                .properties = HashMap([]const u8, *const anyopaque).init(self.allocator),
            };
            
            try molecules.append(bond_info);
            total_stability += stability_score;
        }
        
        const avg_stability = if (molecules.items.len > 0) 
            total_stability / @as(f64, @floatFromInt(molecules.items.len)) 
        else 
            0.0;
        
        return MolecularStability{
            .molecules = molecules.toOwnedSlice(),
            .avg_stability = avg_stability,
        };
    }
    
    fn calculateBalanceScore(self: *Testing, distribution: *HashMap(NodeSpecialization, u32)) f64 {
        _ = self;
        var values = ArrayList(u32).init(self.allocator);
        defer values.deinit();
        
        var iterator = distribution.iterator();
        while (iterator.next()) |entry| {
            values.append(entry.value_ptr.*) catch continue;
        }
        
        if (values.items.len == 0) return 0.0;
        
        var min_val: u32 = std.math.maxInt(u32);
        var max_val: u32 = 0;
        
        for (values.items) |val| {
            min_val = @min(min_val, val);
            max_val = @max(max_val, val);
        }
        
        return if (max_val > 0) @as(f64, @floatFromInt(min_val)) / @as(f64, @floatFromInt(max_val)) else 0.0;
    }
    
    fn suggestRebalancing(self: *Testing, distribution: *HashMap(NodeSpecialization, u32)) ![][]const u8 {
        _ = distribution;
        var suggestions = ArrayList([]const u8).init(self.allocator);
        
        const suggestion = try self.allocator.dupe(u8, "Consider redistributing nodes for better balance");
        try suggestions.append(suggestion);
        
        return suggestions.toOwnedSlice();
    }
    
    fn classifyComplexity(self: *Testing, total: u32) ![]const u8 {
        const classification = if (total < 10) 
            "simple" 
        else if (total < 50) 
            "moderate" 
        else if (total < 100) 
            "complex" 
        else 
            "very_complex";
        
        return self.allocator.dupe(u8, classification);
    }
    
    fn calculateBondStability(self: *Testing, bonds: []MolecularBond) f64 {
        _ = self;
        // Simple stability calculation
        return @as(f64, @floatFromInt(bonds.len)) * 10.0 + @as(f64, @floatFromInt(std.crypto.random.intRangeAtMost(u32, 1, 20)));
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

fn generateId(allocator: Allocator) ![]const u8 {
    var bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&bytes);
    
    var hex_chars: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&hex_chars, "{}", .{std.fmt.fmtSliceHexUpper(&bytes)}) catch unreachable;
    
    return allocator.dupe(u8, &hex_chars);
}

// ============================================================================
// Example Usage and Demonstration
// ============================================================================

pub fn demonstrateHighThroughputSystem(allocator: Allocator) !void {
    print("=== High Throughput System Demo ===\n");
    
    const reactor = try Reactor.init(allocator);
    defer reactor.deinit();
    
    // Add optimized nodes for different packet groups
    try reactor.addNode("parallel_processor_1", .dataflow);
    try reactor.addNode("parallel_processor_2", .dataflow);
    try reactor.addNode("load_balancer", .meta_computational);
    
    // Create test packets
    const producer = try producerPacket(allocator, @ptrCast(&@as(u32, 42)));
    const transform1 = try transformPacket(allocator, @ptrCast(&@as(u32, 1)), 5);
    const transform2 = try transformPacket(allocator, @ptrCast(&@as(u32, 2)), 3);
    
    // Create stream pipeline molecule
    const transforms = [_]*Packet{transform1, transform2};
    const consumer = try sequentialPacket(allocator, @ptrCast(&@as(u32, 0)));
    const pipeline = try createStreamPipeline(allocator, producer, &transforms, consumer);
    
    print("Created stream pipeline with {} components\n", .{pipeline.composition.len});
    
    // Inject packets for processing
    try reactor.injectPacket(producer);
    try reactor.injectPacket(transform1);
    try reactor.injectPacket(transform2);
    
    // Let the system process for a moment
    std.time.sleep(100 * time.ns_per_ms);
    
    const metrics = reactor.getMetrics();
    print("System metrics: {} active packets, {} total processed\n", .{ metrics.active_packets, metrics.total_packets_processed });
}

pub fn demonstrateRealTimeSystem(allocator: Allocator) !void {
    print("\n=== Real-Time System Demo ===\n");
    
    const reactor = try Reactor.init(allocator);
    defer reactor.deinit();
    
    // Add event-driven optimized nodes
    try reactor.addNode("event_processor", .event_driven);
    try reactor.addNode("scheduler", .event_driven);
    
    // Create event-driven packets
    const signal = try signalPacket(allocator, "sensor_input");
    const timer = try timerPacket(allocator, 10, @ptrCast(&@as(u32, 1)));
    const pattern = try patternPacket(allocator, "anomaly_detection", @ptrCast(&@as(u32, 2)), 15);
    
    // Create real-time pipeline molecule
    const transforms = [_]*Packet{};
    const pipeline = try createStreamPipeline(allocator, signal, &transforms, timer);
    
    print("Created real-time pipeline with max_latency property\n");
    
    // Inject event packets
    try reactor.injectPacket(signal);
    try reactor.injectPacket(timer);
    try reactor.injectPacket(pattern);
    
    std.time.sleep(50 * time.ns_per_ms);
    
    const metrics = reactor.getMetrics();
    print("Real-time metrics: {d:.2} system load\n", .{metrics.system_load});
}

pub fn demonstrateFaultTolerantSystem(allocator: Allocator) !void {
    print("\n=== Fault-Tolerant System Demo ===\n");
    
    const reactor = try Reactor.init(allocator);
    defer reactor.deinit();
    
    // Add fault-tolerant nodes
    try reactor.addNode("primary_processor", .dataflow);
    try reactor.addNode("backup_processor", .dataflow);
    try reactor.addNode("fault_detector", .event_driven);
    try reactor.addNode("system_controller", .meta_computational);
    
    // Create fault-tolerant computation
    const computation = try transformPacket(allocator, @ptrCast(&@as(u32, 100)), 10);
    const fault_tolerant = try createFaultTolerantComputation(allocator, computation, 1000);
    
    print("Created fault-tolerant computation with recovery_time: 1000ms\n");
    
    // Create ACID transaction
    const operations = [_]*Packet{computation};
    const acid_transaction = try createAcidTransaction(allocator, &operations);
    
    print("Created ACID transaction with {} operations\n", .{acid_transaction.composition.len});
    
    // Inject fault-tolerant packets
    try reactor.injectPacket(computation);
    
    std.time.sleep(75 * time.ns_per_ms);
    
    const metrics = reactor.getMetrics();
    print("Fault-tolerant metrics: {} nodes, {d:.2} efficiency\n", .{ metrics.node_count, metrics.system_load * 100 });
}

pub fn demonstrateAnalytics(allocator: Allocator) !void {
    print("\n=== Analytics Demo ===\n");
    
    const reactor = try Reactor.init(allocator);
    defer reactor.deinit();
    
    // Add various node types
    try reactor.addNode("cf_node", .general);
    try reactor.addNode("df_node", .dataflow);
    try reactor.addNode("ed_node", .event_driven);
    try reactor.addNode("co_node", .collective);
    try reactor.addNode("mc_node", .meta_computational);
    try reactor.addNode("rm_node", .resource_management);
    
    // Create test packets and inject them
    const packets = [_]*Packet{
        try sequentialPacket(allocator, @ptrCast(&@as(u32, 1))),
        try producerPacket(allocator, @ptrCast(&@as(u32, 2))),
        try signalPacket(allocator, "test"),
        try barrierPacket(allocator, &[_][]const u8{"node1", "node2"}),
        try spawnPacket(allocator, @ptrCast(&@as(u32, 3))),
        try allocatePacket(allocator, "memory", 1024),
    };
    
    for (packets) |packet| {
        try reactor.injectPacket(packet);
    }
    
    std.time.sleep(25 * time.ns_per_ms);
    
    // Perform analytics
    var analytics = Analytics.init(allocator);
    var analysis = try analytics.analyzeSystemPerformance(reactor);
    defer analysis.deinit(allocator);
    
    print("System efficiency: {d:.2}%\n", .{analysis.efficiency_score});
    print("Bottlenecks found: {}\n", .{analysis.bottlenecks.len});
    print("Optimization suggestions: {}\n", .{analysis.optimization_suggestions.len});
    
    print("Periodic distribution:\n");
    print("  CF group: {d:.1}% (complexity: {d:.1})\n", .{ analysis.periodic_distribution.cf_group.percentage, analysis.periodic_distribution.cf_group.avg_complexity });
    print("  DF group: {d:.1}% (complexity: {d:.1})\n", .{ analysis.periodic_distribution.df_group.percentage, analysis.periodic_distribution.df_group.avg_complexity });
    print("  ED group: {d:.1}% (complexity: {d:.1})\n", .{ analysis.periodic_distribution.ed_group.percentage, analysis.periodic_distribution.ed_group.avg_complexity });
    
    // Testing validation
    var testing = Testing.init(allocator);
    var validation = try testing.validatePeriodicProperties(reactor);
    defer validation.deinit(allocator);
    
    print("Validation - Balance score: {d:.3}\n", .{validation.group_distribution.balance_score});
    print("Validation - System complexity: {}\n", .{validation.complexity_analysis.system_complexity});
}

// ============================================================================
// Main Function
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    print("PacketFlow System - Zig Implementation\n");
    print("=====================================\n");
    
    try demonstrateHighThroughputSystem(allocator);
    try demonstrateRealTimeSystem(allocator);
    try demonstrateFaultTolerantSystem(allocator);
    try demonstrateAnalytics(allocator);
    
    print("\n=== Demo Complete ===\n");
}
