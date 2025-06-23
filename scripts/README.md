# Scripts Directory

This directory contains utility scripts for managing the AI Search Tool.

## Categories

### Database Management
- `fix_*.py` - Database repair and maintenance scripts
- `reset_database.py` - Reset database to clean state
- `init_database.py` - Initialize new database
- `migrate_*.py` - Database migration scripts

### Data Import/Export
- `import_*.py` - Import data from various sources
- `export_data.py` - Export data for backup
- `import_pdf_url.py` - Import PDFs from URLs

### Document Management
- `generate_abstracts*.py` - Generate abstracts for documents
- `update_*.py` - Update document metadata
- `move_document.py` - Move documents between databases
- `list_documents.py` - List all documents

### Testing
- `test_*.py` - Various test scripts

### Analysis
- `analyze_embeddings.py` - Analyze embedding distribution
- `list_chromadb_collections.py` - List ChromaDB collections

### CLI Tools
- `cli*.py` - Command-line interfaces (might need special handling)

### Server Management
- `start.py` - Start the server
- `stop.py` - Stop the server

## Usage

All scripts should be run from the project root directory:

```bash
# From the project root (search-tool/)
python scripts/script_name.py
```

### Examples

```bash
# Fix embedding mismatches
python scripts/fix_embedding_mismatch.py

# Generate abstracts for all documents
python scripts/generate_abstracts.py

# Analyze embeddings and clustering
python scripts/analyze_embeddings.py

# List all documents
python scripts/list_documents.py
```

## Important Notes

- Always run scripts from the project root directory
- The scripts automatically adjust paths to find server modules and data files
- Virtual environment should be activated before running scripts: `source venv/bin/activate`