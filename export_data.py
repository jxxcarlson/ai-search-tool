#!/usr/bin/env python3
"""
Export all data from the AI Search Tool to a portable archive.
This includes databases, documents, PDFs, and all necessary files.
"""

import os
import shutil
import json
import hashlib
import tarfile
from datetime import datetime
from pathlib import Path
import sqlite3
import argparse


def calculate_checksum(file_path):
    """Calculate SHA256 checksum of a file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def get_database_stats(db_path):
    """Get statistics from the SQLite database."""
    stats = {}
    if os.path.exists(db_path):
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Count documents
        cursor.execute("SELECT COUNT(*) FROM documents")
        stats['document_count'] = cursor.fetchone()[0]
        
        # Get database size
        stats['database_size'] = os.path.getsize(db_path)
        
        conn.close()
    else:
        stats['document_count'] = 0
        stats['database_size'] = 0
        
    return stats


def count_files_in_directory(directory):
    """Count files in a directory recursively."""
    if not os.path.exists(directory):
        return 0
    
    count = 0
    for root, dirs, files in os.walk(directory):
        count += len(files)
    return count


def export_data(output_dir=None, compress=True):
    """Export all data to a timestamped directory."""
    
    # Create timestamped export directory
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    export_name = f"ai_search_tool_export_{timestamp}"
    
    if output_dir:
        export_path = Path(output_dir) / export_name
    else:
        export_path = Path("exports") / export_name
    
    export_path.mkdir(parents=True, exist_ok=True)
    
    print(f"Creating export in: {export_path}")
    
    # Define what to export
    export_items = {
        "database": {
            "source": "server/storage/documents.db",
            "destination": "server/storage/documents.db",
            "type": "file"
        },
        "chroma_db": {
            "source": "server/storage/chroma_db",
            "destination": "server/storage/chroma_db",
            "type": "directory"
        },
        "documents": {
            "source": "server/storage/documents",
            "destination": "server/storage/documents",
            "type": "directory"
        },
        "pdfs": {
            "source": "server/storage/pdfs",
            "destination": "server/storage/pdfs",
            "type": "directory"
        },
        "pdf_thumbnails": {
            "source": "server/storage/pdf_thumbnails",
            "destination": "server/storage/pdf_thumbnails",
            "type": "directory"
        },
        "document_ids": {
            "source": "server/storage/document_ids.json",
            "destination": "server/storage/document_ids.json",
            "type": "file"
        },
        "sample_documents": {
            "source": "sample_documents.json",
            "destination": "sample_documents.json",
            "type": "file"
        },
        "inbox": {
            "source": "inbox",
            "destination": "inbox",
            "type": "directory"
        },
        "requirements": {
            "source": "requirements.txt",
            "destination": "requirements.txt",
            "type": "file"
        }
    }
    
    # Create manifest
    manifest = {
        "export_timestamp": timestamp,
        "export_date": datetime.now().isoformat(),
        "items": {},
        "statistics": {},
        "checksums": {}
    }
    
    # Export each item
    for item_name, item_config in export_items.items():
        source = item_config["source"]
        destination = export_path / item_config["destination"]
        
        print(f"Exporting {item_name}...")
        
        if not os.path.exists(source):
            print(f"  ⚠️  {source} not found, skipping...")
            manifest["items"][item_name] = {
                "status": "not_found",
                "source": source
            }
            continue
        
        try:
            # Create parent directory if needed
            destination.parent.mkdir(parents=True, exist_ok=True)
            
            if item_config["type"] == "file":
                shutil.copy2(source, destination)
                manifest["checksums"][item_config["destination"]] = calculate_checksum(destination)
                manifest["items"][item_name] = {
                    "status": "exported",
                    "type": "file",
                    "size": os.path.getsize(destination)
                }
            else:  # directory
                shutil.copytree(source, destination, dirs_exist_ok=True)
                file_count = count_files_in_directory(destination)
                manifest["items"][item_name] = {
                    "status": "exported",
                    "type": "directory",
                    "file_count": file_count
                }
            
            print(f"  ✓ Exported successfully")
            
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            manifest["items"][item_name] = {
                "status": "error",
                "error": str(e)
            }
    
    # Gather statistics
    db_stats = get_database_stats(export_path / "server/storage/documents.db")
    manifest["statistics"] = {
        "document_count": db_stats["document_count"],
        "database_size": db_stats["database_size"],
        "pdf_count": count_files_in_directory(export_path / "server/storage/pdfs"),
        "thumbnail_count": count_files_in_directory(export_path / "server/storage/pdf_thumbnails"),
        "total_export_size": sum(
            os.path.getsize(os.path.join(dirpath, filename))
            for dirpath, dirnames, filenames in os.walk(export_path)
            for filename in filenames
        )
    }
    
    # Write manifest
    manifest_path = export_path / "manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"✓ Created manifest.json")
    
    # Create README
    readme_content = f"""# AI Search Tool Data Export

Export Date: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
Export ID: {export_name}

## Contents

This export contains all data necessary to restore the AI Search Tool application:

- **Database**: SQLite database with document metadata
- **Vector Database**: ChromaDB files for semantic search
- **Documents**: JSON files with full document content
- **PDFs**: Original PDF files
- **Thumbnails**: PDF page thumbnails
- **Configuration**: Required files and initial data

## Statistics

- Documents: {manifest["statistics"]["document_count"]}
- PDFs: {manifest["statistics"]["pdf_count"]}
- Total Size: {manifest["statistics"]["total_export_size"] / (1024*1024):.2f} MB

## How to Import

1. Place this export directory in your AI Search Tool installation
2. Run: `python import_data.py {export_name}`
3. Verify the import with: `python cli.py stats`

## Required Environment

- Python 3.8+
- All packages from requirements.txt
- Environment variable: ANTHROPIC_API_KEY (optional)
- Sentence transformer model: all-MiniLM-L6-v2

For offline usage, set: HF_HUB_OFFLINE=1
"""
    
    readme_path = export_path / "README.md"
    with open(readme_path, "w") as f:
        f.write(readme_content)
    print("✓ Created README.md")
    
    # Compress if requested
    archive_path = None
    if compress:
        print(f"\nCompressing to {export_name}.tar.gz...")
        archive_path = export_path.parent / f"{export_name}.tar.gz"
        
        with tarfile.open(archive_path, "w:gz") as tar:
            tar.add(export_path, arcname=export_name)
        
        print(f"✓ Created archive: {archive_path}")
        print(f"  Size: {os.path.getsize(archive_path) / (1024*1024):.2f} MB")
    
    # Summary
    print("\n" + "="*50)
    print("EXPORT COMPLETE")
    print("="*50)
    print(f"Export directory: {export_path}")
    if archive_path:
        print(f"Archive: {archive_path}")
    print(f"Documents exported: {manifest['statistics']['document_count']}")
    print(f"Total size: {manifest['statistics']['total_export_size'] / (1024*1024):.2f} MB")
    
    return export_path, manifest


def main():
    parser = argparse.ArgumentParser(description="Export AI Search Tool data")
    parser.add_argument("--output-dir", "-o", help="Output directory (default: ./exports)")
    parser.add_argument("--no-compress", action="store_true", help="Skip compression")
    
    args = parser.parse_args()
    
    try:
        export_data(
            output_dir=args.output_dir,
            compress=not args.no_compress
        )
    except Exception as e:
        print(f"\n❌ Export failed: {str(e)}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())