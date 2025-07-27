# PacketFlow Actor Model Protocol v1.0

**Document Version:** 1.0  
**Protocol Version:** 1.0  
**Base Protocol:** PacketFlow Affinity Protocol v1.0  
**Date:** July 2025  
**Status:** Standard Extension  

## Abstract

The PacketFlow Actor Model Protocol (PFAMP) v1.0 defines a standard extension to the PacketFlow Affinity Protocol that enables distributed actor systems using pure PacketFlow primitives. This protocol allows heterogeneous reactor implementations to participate in unified actor networks through atoms as messages, reactors as actor runtimes, and packets as behavior definitions.

## Table of Contents

1. [Introduction](#1-introduction)
2. [Actor Model Mapping](#2-actor-model-mapping)
3. [Actor Packet Types (AC)](#3-actor-packet-types-ac)
4. [Actor Lifecycle Management](#4-actor-lifecycle-management)
5. [Message Passing Protocol](#5-message-passing-protocol)
6. [Supervision Protocol](#6-supervision-protocol)
7. [Mailbox Management](#7-mailbox-management)
8. [Actor Discovery](#8-actor-discovery)
9. [Performance Specifications](#9-performance-specifications)
10. [Implementation Requirements](#10-implementation-requirements)

---

## 1. Introduction

### 1.1 Purpose

The PacketFlow Actor Model Protocol provides:
- **Pure PacketFlow actor systems** without external frameworks
- **Heterogeneous actor networks** across different reactor implementations
- **Standard actor semantics** (creation, messaging, supervision, termination)
- **Performance optimization** through PacketFlow's hash-based routing
- **Protocol compatibility** with existing PacketFlow infrastructure

### 1.2 Design Principles

**PacketFlow Native:** All actor operations expressed as standard atoms  
**Zero Dependencies:** No external actor frameworks or libraries required  
**Standard Semantics:** Compatible with established actor model principles  
**High Performance:** Leverage PacketFlow's optimized routing and messaging  
**Distributed Ready:** Natural distribution through PacketFlow clusters  

### 1.3 Actor Model Foundations

**Actors** are specialized reactors with mailboxes and behavior definitions  
**Messages** are PacketFlow atoms with actor-specific metadata  
**Mailboxes** are ordered atom queues with overflow strategies  
**Supervisors** are actors that manage other actors using packet protocols  
**Behaviors** are defined through registered packet handlers  

---

## 2. Actor Model Mapping

### 2.1 Core Mappings

| Actor Concept | PacketFlow Implementation |
|---------------|--------------------------|
| **Actor** | Specialized reactor with mailbox |
| **Message** | Atom with group="ac" |
| **Mailbox** | Ordered atom queue |
| **Behavior** | Registered packet handlers |
| **Actor ID** | Reactor ID in PacketFlow registry |
| **Message Delivery** | Hash-based atom routing |
| **Supervision Tree** | Reactor hierarchy with error packets |
| **Actor System** | PacketFlow cluster |

### 2.2 Protocol Hierarchy

```
PacketFlow Actor Model Protocol (PFAMP)
├── Based on: PacketFlow Affinity Protocol v1.0
├── Uses: PacketFlow Standard Library v1.0
├── Extends: Actor group (AC) packets
└── Compatible: All existing PacketFlow infrastructure
```

### 2.3 Namespace Allocation

**Group Code:** `ac` (Actor)  
**Priority Range:** Standard PacketFlow priorities (1-10)  
**Timeout Defaults:** Configurable per actor type  
**Error Codes:** Standard PacketFlow error codes (E400-E699)  

---

## 3. Actor Packet Types (AC)

### 3.1 Core Actor Operations (Level 1)

#### 3.1.1 Actor Creation
```
ac:spawn - Create new actor
ac:init - Initialize actor state
ac:ready - Signal actor ready for messages
```

#### 3.1.2 Message Passing
```
ac:msg - Send message to actor
ac:reply - Reply to sender
ac:forward - Forward message to another actor
```

#### 3.1.3 Actor Lifecycle
```
ac:stop - Gracefully stop actor
ac:kill - Immediately terminate actor
ac:restart - Restart failed actor
```

### 3.2 Advanced Actor Operations (Level 2)

#### 3.2.1 Supervision
```
ac:supervise - Add actor to supervision
ac:unlink - Remove from supervision
ac:monitor - Monitor actor without supervision
```

#### 3.2.2 Behavior Management
```
ac:become - Change actor behavior
ac:unbecome - Revert to previous behavior
ac:suspend - Temporarily suspend message processing
ac:resume - Resume message processing
```

#### 3.2.3 System Operations
```
ac:which - Find actor by name or pattern
ac:list - List actors by criteria
ac:info - Get actor information
ac:stats - Get actor statistics
```

### 3.3 Specialized Actor Types (Level 3)

#### 3.3.1 Supervisor Operations
```
ac:strategy - Set supervision strategy
ac:child_spec - Define child specifications
ac:restart_child - Restart specific child
```

#### 3.3.2 Registry Operations
```
ac:register - Register actor with name
ac:unregister - Remove from registry
ac:whereis - Lookup actor by name
```

---

## 4. Actor Lifecycle Management

### 4.1 Actor Creation Protocol

**Step 1: Spawn Request**
```
Atom: {
  g: "ac",
  e: "spawn",
  d: {
    actor_type: string,     // Actor behavior type
    initial_state: object,  // Initial actor state
    supervisor?: string,    // Supervisor actor ID
    name?: string,         // Optional actor name
    options?: object       // Actor-specific options
  }
}
```

**Step 2: Reactor Allocation**
- Hash-based routing selects appropriate reactor
- Reactor creates specialized actor instance
- Mailbox initialized with overflow strategy
- Actor ID assigned and registered

**Step 3: Initialization**
```
Atom: {
  g: "ac", 
  e: "init",
  d: {
    actor_id: string,
    initial_state: object,
    supervisor?: string
  }
}
```

**Step 4: Ready Signal**
```
Response: {
  success: true,
  data: {
    actor_id: string,
    status: "ready",
    mailbox_size: 0
  }
}
```

### 4.2 Actor Termination Protocol

**Normal Termination**
1. Send `ac:stop` with reason
2. Process remaining mailbox messages
3. Send termination notification to supervisor
4. Clean up actor resources
5. Remove from registry

**Abnormal Termination**
1. Detect actor failure (exception, timeout, resource exhaustion)
2. Send `ac:child_error` to supervisor
3. Apply supervision strategy
4. Clean up or restart based on strategy

**Forced Termination**
1. Send `ac:kill` message
2. Immediately stop message processing
3. Clean up resources without mailbox processing
4. Notify supervisor of termination

### 4.3 Actor State Model

```
States: created → initializing → ready → running → stopping → terminated

Transitions:
created ──spawn──> initializing ──init──> ready ──msg──> running
running ──stop──> stopping ──cleanup──> terminated
running ──error──> terminated ──restart──> initializing
any_state ──kill──> terminated
```

---

## 5. Message Passing Protocol

### 5.1 Message Structure

**Standard Actor Message**
```
Atom: {
  g: "ac",
  e: "msg", 
  d: {
    message_type: string,   // Application message type
    payload: any,           // Message content
    sender: string,         // Sender actor ID
    reply_to?: string,      // Reply destination
    correlation_id?: string // Message correlation
  },
  m: {
    actor_id: string,       // Target actor ID
    delivery_mode: "async" | "sync",
    timeout?: number
  }
}
```

### 5.2 Delivery Guarantees

**At-Most-Once Delivery**
- Messages may be lost due to network failures
- No automatic retries for failed deliveries
- Suitable for high-throughput, non-critical messages

**At-Least-Once Delivery** (Optional)
- Messages guaranteed to be delivered at least once
- May result in duplicate delivery
- Sender tracks acknowledgments and retries

**Exactly-Once Delivery** (Optional)
- Messages delivered exactly once through deduplication
- Higher overhead but stronger guarantees
- Suitable for critical operations

### 5.3 Message Ordering

**Per-Sender Ordering**
- Messages from single sender delivered in order
- Implemented through sequence numbers
- Different senders may interleave

**Causal Ordering** (Optional)
- Messages delivered respecting causal relationships
- Requires vector clocks or logical timestamps
- Higher overhead but stronger consistency

### 5.4 Flow Control

**Mailbox Backpressure**
- Mailbox size limits prevent memory exhaustion
- Overflow strategies: drop oldest, drop newest, block sender
- Configurable per actor type

**Credit-Based Flow Control** (Optional)
- Sender tracks available receiver capacity
- Prevents overwhelming slow receivers
- Dynamic adjustment based on processing rates

---

## 6. Supervision Protocol

### 6.1 Supervision Strategies

**One-For-One**
- Restart only the failed child actor
- Other children continue running normally
- Suitable for independent actors

**One-For-All**
- Restart all children when any child fails
- Ensures consistent state across children
- Suitable for tightly coupled actor groups

**Rest-For-One**
- Restart failed child and all children started after it
- Maintains startup order dependencies
- Suitable for pipeline or chain architectures

**Simple-One-For-One**
- Specialized for dynamic child creation
- All children have same behavior
- Efficient for worker pools

### 6.2 Supervision Tree Structure

```
Supervision Hierarchy:
Root Supervisor
├── Application Supervisor A
│   ├── Worker Pool Supervisor
│   │   ├── Worker Actor 1
│   │   ├── Worker Actor 2
│   │   └── Worker Actor N
│   └── Service Actor
└── Application Supervisor B
    ├── Database Actor
    └── Cache Actor
```

### 6.3 Error Propagation

**Child Error Notification**
```
Atom: {
  g: "ac",
  e: "child_error",
  d: {
    child_id: string,
    error_type: string,
    error_message: string,
    restart_count: number,
    failure_time: number
  }
}
```

**Supervisor Response**
- Analyze error and restart history
- Apply supervision strategy
- Update restart intensity counters
- Escalate to parent if limits exceeded

### 6.4 Restart Policies

**Restart Intensity**
- Maximum restarts within time period
- Prevents infinite restart loops
- Configurable per supervisor

**Restart Delay**
- Delay between restart attempts
- Exponential backoff for repeated failures
- Prevents resource thrashing

---

## 7. Mailbox Management

### 7.1 Mailbox Types

**Unbounded Mailbox**
- No size limits on message queue
- Risk of memory exhaustion under load
- Suitable for low-volume actors

**Bounded Mailbox**
- Fixed maximum queue size
- Configurable overflow strategies
- Prevents memory exhaustion

**Priority Mailbox**
- Messages ordered by priority
- High-priority messages processed first
- Configurable priority levels

**Stash Mailbox**
- Temporary message storage
- Messages can be stashed and unstashed
- Useful for state-dependent processing

### 7.2 Overflow Strategies

**Drop Oldest**
- Remove oldest messages when full
- Maintains recent message processing
- May lose important early messages

**Drop Newest**
- Reject new messages when full
- Preserves message processing order
- Provides backpressure to senders

**Fail Fast**
- Immediately fail when mailbox full
- Explicit error handling required
- Prevents hidden message loss

### 7.3 Message Processing Order

**FIFO (First In, First Out)**
- Standard message ordering
- Simple and predictable
- Default for most actor types

**LIFO (Last In, First Out)**
- Process newest messages first
- Useful for cache-like actors
- Can lead to message starvation

**Priority-Based**
- Process by message priority
- High-priority messages first
- Requires priority assignment

---

## 8. Actor Discovery

### 8.1 Actor Registration

**Name Registration**
```
Atom: {
  g: "ac",
  e: "register",
  d: {
    actor_id: string,
    name: string,
    scope: "local" | "cluster",
    metadata?: object
  }
}
```

**Registration Scopes**
- **Local:** Visible within single reactor
- **Cluster:** Visible across entire PacketFlow cluster
- **Global:** Visible across multiple clusters (optional)

### 8.2 Actor Lookup

**By Name**
```
Atom: {
  g: "ac",
  e: "whereis",
  d: {
    name: string,
    scope?: "local" | "cluster"
  }
}
```

**By Pattern**
```
Atom: {
  g: "ac", 
  e: "which",
  d: {
    pattern: string,     // Glob or regex pattern
    actor_type?: string, // Filter by actor type
    limit?: number       // Max results
  }
}
```

### 8.3 Service Discovery Integration

**Registry Backends**
- Static configuration files
- Distributed key-value stores (etcd, Consul)
- Service mesh integration (Istio, Linkerd)
- Custom registry implementations

**Health Integration**
- Automatic registration of healthy actors
- Deregistration on actor termination
- Health check integration with PacketFlow monitoring

---

## 9. Performance Specifications

### 9.1 Latency Targets

| Operation | P50 Latency | P99 Latency | Max Latency |
|-----------|-------------|-------------|-------------|
| Actor Creation | 5ms | 20ms | 100ms |
| Message Delivery | 0.5ms | 2ms | 10ms |
| Actor Termination | 10ms | 50ms | 200ms |
| Registry Lookup | 1ms | 5ms | 20ms |
| Supervision Action | 5ms | 20ms | 100ms |

### 9.2 Throughput Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Messages per Actor | 10,000/sec | Sustained rate |
| Actor Creation Rate | 1,000/sec | Per reactor |
| Actors per Reactor | 100,000 | Memory dependent |
| Cluster Actors | 10,000,000 | Distributed |
| Cross-Actor Messages | 1,000,000/sec | Cluster-wide |

### 9.3 Resource Limits

**Memory Usage**
- Actor overhead: 200-500 bytes
- Mailbox memory: Configurable limit
- Total actor memory: <50% of reactor memory

**CPU Usage**
- Message processing: <1ms per message
- Actor creation: <10ms per actor
- Supervision overhead: <5% of total CPU

**Network Bandwidth**
- Message overhead: <50 bytes per message
- Registration traffic: <1% of total bandwidth
- Supervision traffic: <0.1% of total bandwidth

---

## 10. Implementation Requirements

### 10.1 Compliance Levels

#### Level 1 (Core Actor Support)
**Required Features:**
- Actor creation and termination
- Basic message passing (ac:msg)
- Simple supervision (one-for-one)
- Local actor registration
- Unbounded mailboxes

**Required Packets:**
- ac:spawn, ac:init, ac:msg, ac:stop
- ac:child_error, ac:register, ac:whereis

#### Level 2 (Standard Actor Features)
**Additional Features:**
- Multiple supervision strategies
- Bounded mailboxes with overflow handling
- Priority message processing
- Cluster-wide actor discovery
- Behavior changing (ac:become)

**Additional Packets:**
- ac:become, ac:supervise, ac:list
- ac:restart, ac:monitor

#### Level 3 (Advanced Actor Features)
**Additional Features:**
- Stash mailboxes
- Causal message ordering
- At-least-once delivery
- Custom supervision strategies
- Actor migration

**Additional Packets:**
- ac:stash, ac:unstash, ac:migrate
- ac:strategy, ac:child_spec

### 10.2 Interoperability Requirements

**PacketFlow Compatibility**
- Full compatibility with PacketFlow Affinity Protocol v1.0
- Use standard PacketFlow routing and error handling
- Leverage existing PacketFlow infrastructure

**Multi-Language Support**
- Consistent actor semantics across languages
- Standard message formats and protocols
- Language-agnostic supervision trees

**Cluster Integration**
- Seamless actor distribution across reactors
- Cross-reactor message delivery
- Unified actor namespace

### 10.3 Testing and Validation

**Functional Tests**
- Actor lifecycle operations
- Message delivery guarantees
- Supervision behavior
- Error handling and recovery

**Performance Tests**
- Message throughput benchmarks
- Actor creation/termination rates
- Memory usage under load
- Latency distribution analysis

**Integration Tests**
- Multi-reactor actor systems
- Cross-language message passing
- Fault tolerance scenarios
- Cluster partition handling

---

## Appendices

### Appendix A: Packet Reference

| Packet | Level | Purpose | Timeout | Priority |
|--------|-------|---------|---------|----------|
| ac:spawn | 1 | Create actor | 30s | 7 |
| ac:init | 1 | Initialize actor | 10s | 8 |
| ac:msg | 1 | Send message | varies | 5 |
| ac:stop | 1 | Stop actor | 30s | 6 |
| ac:child_error | 1 | Report child error | 5s | 9 |
| ac:register | 1 | Register name | 5s | 7 |
| ac:whereis | 1 | Lookup actor | 5s | 5 |
| ac:become | 2 | Change behavior | 10s | 6 |
| ac:supervise | 2 | Add supervision | 10s | 7 |
| ac:list | 2 | List actors | 30s | 4 |

### Appendix B: Error Codes

| Code | Description | Category | Retry |
|------|-------------|----------|-------|
| E404 | Actor not found | Client | No |
| E408 | Message timeout | Client | Yes |
| E413 | Mailbox full | Server | Yes |
| E500 | Actor crashed | Server | Yes |
| E503 | Supervisor unavailable | Server | Yes |
| E507 | Resource exhausted | Server | Yes |
| E600 | Invalid actor message | Protocol | No |
| E601 | Unsupported actor operation | Protocol | No |

### Appendix C: Configuration Examples

**Basic Actor System**
```json
{
  "actor_system": {
    "name": "app_actors",
    "mailbox_default_size": 1000,
    "supervision_strategy": "one_for_one",
    "restart_intensity": 5,
    "restart_period": 60
  }
}
```

**Supervision Configuration**
```json
{
  "supervision": {
    "strategy": "one_for_all",
    "max_restarts": 10,
    "restart_period": 60,
    "restart_delay": 1,
    "escalation_policy": "shutdown"
  }
}
```

**Mailbox Configuration**
```json
{
  "mailbox": {
    "type": "bounded",
    "size": 10000,
    "overflow_strategy": "drop_oldest",
    "priority_levels": 10
  }
}
```

---

## Document Information

**Authors:** PacketFlow Actor Model Working Group  
**Contributors:** Protocol Team, Runtime Teams, Research Committee  
**Status:** Approved Standard Extension  
**Base Protocol:** PacketFlow Affinity Protocol v1.0  
**Depends On:** PacketFlow Standard Library v1.0  
**Implementation Deadline:** Q1 2026  
**Next Review:** Q3 2026  

## Contact

**Protocol Questions:** actors@packetflow.org  
**Implementation Support:** dev@packetflow.org  
**Performance Issues:** perf@packetflow.org  
**Compliance Certification:** compliance@packetflow.org

---

**End of PacketFlow Actor Model Protocol v1.0 Specification**

This protocol extension enables distributed actor systems using pure PacketFlow primitives while maintaining full compatibility with existing PacketFlow infrastructure and implementations.
