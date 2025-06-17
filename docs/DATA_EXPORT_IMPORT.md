# Data Export/Import Guide

This guide explains how to export and import all data from the AI Search Tool, allowing you to backup, migrate, or share your document collection.

## Overview

The export/import functionality allows you to:
- Create complete backups of your document database
- Migrate data between systems
- Share document collections
- Archive data for long-term storage

## Exporting Data

### Basic Export

To create a complete export of all your data:

```bash
python export_data.py
```

This will:
1. Create a timestamped directory in `exports/` (e.g., `exports/ai_search_tool_export_20240117_143022/`)
2. Copy all databases, documents, PDFs, and configuration files
3. Generate a manifest with checksums and statistics
4. Create a compressed `.tar.gz` archive

### Export Options

```bash
# Export to a specific directory
python export_data.py --output-dir /path/to/backup/location

# Export without compression (directory only)
python export_data.py --no-compress
```

### What Gets Exported

The export includes:
- **SQLite Database** (`storage/documents.db`) - Document metadata
- **ChromaDB** (`storage/chroma_db/`) - Vector embeddings for search
- **Document JSON files** (`storage/documents/`) - Full document content
- **PDF files** (`storage/pdfs/`) - Original uploaded PDFs
- **PDF thumbnails** (`storage/pdf_thumbnails/`) - Generated previews
- **Configuration files** - Sample documents, requirements.txt, etc.

### Export Manifest

Each export includes a `manifest.json` with:
- Export timestamp and date
- File checksums for verification
- Statistics (document count, file sizes)
- Status of each exported component

## Importing Data

### Basic Import

To import from an export archive:

```bash
python import_data.py exports/ai_search_tool_export_20240117_143022.tar.gz
```

Or from an export directory:

```bash
python import_data.py exports/ai_search_tool_export_20240117_143022/
```

### Import Options

```bash
# Import without creating a backup of existing data
python import_data.py export.tar.gz --no-backup

# Import without verifying checksums
python import_data.py export.tar.gz --no-verify
```

### Import Process

The import script will:
1. Verify the export manifest
2. Check file checksums (optional)
3. Backup existing data (optional)
4. Replace current data with imported data
5. Verify the import was successful

### Safety Features

- **Automatic Backup**: By default, existing data is backed up to `backups/` before import
- **Checksum Verification**: Files are verified against manifest checksums
- **Confirmation Prompt**: If verification fails, you'll be asked to confirm

## Common Use Cases

### Regular Backups

Create a backup script:

```bash
#!/bin/bash
# backup.sh
python export_data.py --output-dir /backup/location
# Keep only last 7 backups
find /backup/location -name "ai_search_tool_export_*.tar.gz" -mtime +7 -delete
```

### Migration to New System

On the old system:
```bash
python export_data.py
# Copy the .tar.gz file to the new system
```

On the new system:
```bash
# Install dependencies first
pip install -r requirements.txt

# Import the data
python import_data.py /path/to/export.tar.gz
```

### Sharing Document Collections

```bash
# Export specific for sharing (you might want to exclude certain files)
python export_data.py --output-dir shared_exports/

# The recipient can import with:
python import_data.py shared_exports/ai_search_tool_export_*.tar.gz
```

## Troubleshooting

### Import Fails

If import fails:
1. Check the error message for specific issues
2. Verify the export file isn't corrupted
3. Ensure you have sufficient disk space
4. Check file permissions

### Missing Dependencies

After import, ensure all Python dependencies are installed:
```bash
pip install -r requirements.txt
```

### Model Download

The sentence transformer model will be downloaded on first use. For offline systems:
```bash
# Download model on internet-connected system first
python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# Then set for offline use
export HF_HUB_OFFLINE=1
```

### Verification

After import, verify everything is working:
```bash
# Check document count
python cli.py stats

# Test search functionality
python cli.py search "test query"

# Start the server and check web interface
./start.sh
```

## Best Practices

1. **Regular Exports**: Schedule regular exports for backup
2. **Test Imports**: Periodically test importing exports to ensure they work
3. **Archive Storage**: Store important exports in multiple locations
4. **Documentation**: Include notes about the export contents and purpose
5. **Version Compatibility**: Note the AI Search Tool version used for exports

## Security Considerations

- Exports contain all your documents in plain text
- Ensure exports are stored securely
- Use encryption for sensitive data
- Be cautious when sharing exports
- Consider excluding sensitive files from exports

## Advanced Usage

### Selective Import

You can manually import specific components by modifying the import script or copying files directly:

```bash
# Import only the database
cp export/storage/documents.db storage/documents.db

# Import only PDFs
cp -r export/storage/pdfs/* storage/pdfs/
```

### Merge Imports

To merge data from multiple sources (requires custom scripting):
1. Import the first export normally
2. Extract subsequent exports
3. Use the CLI to import documents individually
4. Rebuild the vector database

## Support

If you encounter issues:
1. Check the error messages and logs
2. Verify file permissions and disk space
3. Ensure all dependencies are installed
4. Report issues at: https://github.com/anthropics/claude-code/issues