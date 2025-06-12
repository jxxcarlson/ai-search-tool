# SQLite: Architecture and Data Capacity

## How SQLite is Set Up and How It Works

SQLite has a unique architecture that makes it incredibly practical for embedded use. It's a **serverless, file-based** database engine that runs entirely within your application process.

### File Structure

SQLite databases are single files containing everything - tables, indexes, metadata, and data. The file format uses fixed-size pages (typically 4KB) organized as a B-tree structure. The first page contains the database header with schema information and configuration.

### No Server Process

Unlike PostgreSQL or MySQL, there's no separate database daemon. SQLite is a C library that your application links against directly. When you open a database, you're literally opening and reading/writing a file using the SQLite library functions.

### ACID Compliance

Despite being file-based, SQLite maintains full ACID properties through careful use of file locking and journaling. It uses write-ahead logging (WAL mode) or rollback journals to ensure transactions are atomic and durable.

### Query Engine

SQLite includes a complete SQL parser, query planner, and virtual machine. SQL queries are compiled into bytecode and executed by SQLite's virtual database engine (VDBE). The query planner analyzes your SQL and chooses optimal execution strategies.

### Storage Engine

Data is stored in B-tree pages within the file. Each table and index is its own B-tree. SQLite handles page allocation, splitting, and merging automatically. Variable-length records are packed efficiently within pages.

### Concurrency

Multiple readers can access simultaneously, but only one writer at a time. WAL mode improves this by allowing readers during writes. File locking coordinates access between processes.

### Memory Management

SQLite can operate entirely in memory (":memory:" database) or use configurable page caches to minimize disk I/O.

The genius is its simplicity - you get full SQL capabilities with zero configuration or administration overhead.

## How Much Data Can SQLite Manage?

SQLite can handle surprisingly large datasets, though it's often underestimated:

### Theoretical Limits

- **Database size**: 281 TB (2^48 bytes)
- **Row count**: 2^64 rows per table
- **Table count**: 2^62 tables per database
- **Column count**: 32,767 columns per table (configurable up to 2,000 default)
- **String/BLOB size**: 2^31 bytes (~2GB per field)

### Practical Considerations

Most real-world limits come from your filesystem, available RAM, and performance requirements rather than SQLite's built-in constraints.

### Performance Characteristics

SQLite works well with databases in the **hundreds of GB range** on modern hardware. Many production systems successfully use SQLite with:
- Tens of millions of rows
- Databases of 50-100GB+
- Complex queries with proper indexing

### Where it excels

- Read-heavy workloads (websites, analytics)
- Single-writer scenarios
- Applications where you control the access patterns
- Embedded systems and mobile apps

### Where it struggles

- High-concurrency writes (only one writer at a time)
- Network access (file-based, not client-server)
- Very large result sets that don't fit in memory
- Applications requiring geographic distribution

### Real-world examples

Many major applications use SQLite for substantial datasets - fossil SCM manages large codebases, Firefox uses it for browsing history, and some web applications serve millions of users with SQLite backends.

The key is understanding that SQLite's limits are usually about concurrency patterns rather than raw data volume. For single-application use cases, it can handle much more data than people typically assume.
