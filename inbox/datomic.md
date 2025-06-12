# What is Datomic?

**Datomic** is a distributed database designed by Rich Hickey (creator of Clojure) that fundamentally rethinks how databases work. It's built around **immutability** and **time-aware** data modeling.

## Core Philosophy

Unlike traditional databases that update records in-place, Datomic treats the database as an **immutable value that grows over time**. Every transaction creates a new database value without destroying previous ones, giving you a complete history.

## Architecture

Datomic separates **reads from writes** through a unique architecture:
- **Transactor**: Single writer that processes all transactions
- **Storage**: Pluggable backend (DynamoDB, Cassandra, SQL databases)
- **Peers**: Application processes that contain query engines and local caching
- **Query runs in your application**, not on a separate database server

## Data Model

Everything is stored as **datoms** - atomic facts in the form [entity, attribute, value, transaction]. For example: `[person-123, :person/name, "Alice", tx-456]`. This creates a universal, flexible schema.

## Time Travel

You can query the database **as of any point in time** since you have the complete history. Want to see what the data looked like last Tuesday? Just query that database value.

## Datalog Queries

Uses **Datalog** (a subset of Prolog) instead of SQL. Queries are data structures themselves, making them composable and easier to generate programmatically.

## Benefits

- Complete audit trail automatically
- No complex caching strategies needed
- Consistent reads without blocking writes
- Easy to reason about since data never changes

## Drawbacks

- Storage grows indefinitely (though you can prune)
- Different mental model from traditional SQL
- Primarily designed for Clojure ecosystem

It's particularly powerful for applications where you need comprehensive history tracking or complex analytical queries.