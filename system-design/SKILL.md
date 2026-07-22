---
name: system-design
description: Reference and workflow for designing large-scale systems — apply when a task involves architecting a service, choosing storage/caching/queueing, reasoning about latency vs throughput, scalability, availability/consistency trade-offs, or estimating capacity. Triggers on "system design", "scale this", "architecture review", "how should we structure", "latency", "throughput", "CAP", "sharding", "caching strategy", "load balancing", "back-of-the-envelope". Points to the donnemartin/system-design-primer as the authoritative reference.
---

# System Design

A workflow and reference index for designing large-scale systems. The
authoritative source is the **[System Design Primer](https://github.com/donnemartin/system-design-primer)**
(donnemartin) — this skill tells you *when* to reach for which part of it and how
to structure the work, so you don't design from vibes.

## When to use

- Architecting a new service or reworking an existing one.
- Choosing between storage engines, caches, queues, or communication styles.
- Reasoning explicitly about latency, throughput, availability, and consistency.
- Capacity planning / back-of-the-envelope estimation.
- Reviewing someone else's design for missing failure modes.

For adjacent, more specialized work, hand off to the sibling skills:
`database-designer` (schema/index/SQL-vs-NoSQL), `observability-designer` and
`slo-architect` (reliability targets), `performance-profiler` (measuring real
latency), `chaos-engineering` (resilience testing), `migration-architect`
(zero-downtime cutovers).

## Workflow

Design in this order — each step constrains the next. Don't jump to components
before the requirements and numbers are on the table.

1. **Scope the problem.** Clarify functional requirements, then non-functional
   ones (traffic, data volume, read/write ratio, latency budget, consistency
   needs). State assumptions explicitly.
2. **Back-of-the-envelope estimation.** QPS (average and peak), storage growth,
   bandwidth, and how much fits in memory. These numbers decide whether you need
   sharding, caching, a CDN, etc. See the primer's *Appendix* (powers of two,
   latency numbers every programmer should know, estimation).
3. **High-level design.** Sketch the core components and data flow end to end
   before optimizing anything.
4. **Deep-dive the bottlenecks.** For each hotspot, apply the relevant pattern
   below and name the trade-off you're accepting.
5. **Identify and address failure modes.** Single points of failure, thundering
   herds, cache stampedes, backpressure, retries/idempotency.

## Reference index (map to the primer)

**Core trade-offs**
- *Performance vs scalability* — a system is scalable if adding resources yields
  a proportional performance gain.
- *Latency vs throughput* — aim for maximal throughput with acceptable latency;
  they are not the same knob.
- *Availability vs consistency (CAP)* — in a partition, choose CP or AP. Most web
  systems favor AP with eventual consistency.

**Consistency & availability patterns**
- Consistency: weak, eventual, strong.
- Availability: fail-over (active-passive / active-active), replication;
  quantify with nines (99.9% vs 99.99%); availability in sequence vs parallel.

**Networking / edge**
- DNS, CDN (push vs pull), load balancer (L4 vs L7, active-passive/active-active),
  reverse proxy. Load balancer vs reverse proxy distinction.

**Application layer**
- Split into microservices where it buys independent scaling; use a service
  discovery mechanism. Watch for the distributed-monolith anti-pattern.

**Data layer**
- RDBMS scaling: master-slave / master-master replication, federation,
  sharding, denormalization, SQL tuning.
- SQL vs NoSQL: key-value, document, wide-column, graph. Choose by access
  pattern, not familiarity. (Deep-dive with `database-designer`.)

**Caching**
- Layers: client, CDN, web server, database, application.
- Patterns: cache-aside, write-through, write-behind, refresh-ahead.
- Always address invalidation and stampede protection.

**Asynchronism**
- Message queues, task queues, back pressure. Move slow work off the request
  path.

**Communication**
- TCP vs UDP; RPC vs REST. Pick per call-site latency and coupling needs.

**Security**
- Encrypt in transit and at rest, sanitize input, principle of least privilege.

## Output expectations

When you produce a design, make the trade-offs explicit: for every major choice,
state what you optimized for and what you gave up (e.g. "sharded by user_id for
write throughput; cross-user queries now require scatter-gather"). Include the
estimation numbers that justified the choice, and list the failure modes you
considered.
