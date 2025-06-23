#!/usr/bin/env python3
"""
Import data from an AI Search Tool export archive.
Restores databases, documents, PDFs, and all necessary files.
"""

import os
import shutil
import json
import tarfile
import hashlib
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


def verify_checksums(import_path, manifest):
    """Verify checksums from manifest."""
    print("\nVerifying checksums...")
    checksums = manifest.get("checksums", {})
    
    if not checksums:
        print("  ⚠️  No checksums in manifest to verify")
        return True
    
    all_valid = True
    for file_path, expected_checksum in checksums.items():
        full_path = import_path / file_path
        if os.path.exists(full_path):
            actual_checksum = calculate_checksum(full_path)
            if actual_checksum == expected_checksum:
                print(f"  ✓ {file_path}")
            else:
                print(f"  ✗ {file_path} - checksum mismatch!")
                all_valid = False
        else:
            print(f"  ✗ {file_path} - file not found!")
            all_valid = False
    
    return all_valid


def backup_existing_data(backup_dir):
    """Create a backup of existing data before import."""
    print(f"\nBacking up existing data to: {backup_dir}")
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    # Define what to backup
    backup_items = [
        "../server/storage/documents.db",
        "../server/storage/chroma_db",
        "../server/storage/documents",
        "../server/storage/pdfs",
        "../server/storage/pdf_thumbnails",
        "../server/storage/document_ids.json"
    ]
    
    for item in backup_items:
        if os.path.exists(item):
            dest = backup_dir / item
            dest.parent.mkdir(parents=True, exist_ok=True)
            
            if os.path.isfile(item):
                shutil.copy2(item, dest)
                print(f"  ✓ Backed up {item}")
            else:
                shutil.copytree(item, dest, dirs_exist_ok=True)
                print(f"  ✓ Backed up {item}/")


def import_data(import_source, backup=True, verify=True):
    """Import data from export directory or archive."""
    
    # Check if source is archive or directory
    import_path = Path(import_source)
    temp_extract = None
    
    if import_path.suffix == ".gz" and import_path.name.endswith(".tar.gz"):
        # Extract archive
        print(f"Extracting archive: {import_path}")
        temp_extract = Path("temp_import") / import_path.stem.replace(".tar", "")
        temp_extract.parent.mkdir(exist_ok=True)
        
        with tarfile.open(import_path, "r:gz") as tar:
            tar.extractall(temp_extract.parent)
        
        # Find the actual export directory
        extracted_dirs = list(temp_extract.parent.glob("ai_search_tool_export_*"))
        if extracted_dirs:
            import_path = extracted_dirs[0]
        else:
            raise ValueError("Could not find export directory in archive")
    
    elif not import_path.is_dir():
        raise ValueError(f"Import source must be a directory or .tar.gz archive: {import_source}")
    
    # Load manifest
    manifest_path = import_path / "manifest.json"
    if not manifest_path.exists():
        raise ValueError(f"No manifest.json found in {import_path}")
    
    with open(manifest_path, "r") as f:
        manifest = json.load(f)
    
    print(f"\nImporting from export: {manifest['export_date']}")
    print(f"Documents to import: {manifest['statistics']['document_count']}")
    
    # Verify checksums if requested
    if verify:
        if not verify_checksums(import_path, manifest):
            response = input("\n⚠️  Checksum verification failed. Continue anyway? (y/N): ")
            if response.lower() != 'y':
                print("Import cancelled.")
                return False
    
    # Backup existing data if requested
    if backup:
        backup_dir = Path("backups") / f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        backup_existing_data(backup_dir)
    
    # Import each item
    print("\nImporting data...")
    
    import_map = {
        "database": ("../server/storage/documents.db", "../server/storage/documents.db", "file"),
        "chroma_db": ("../server/storage/chroma_db", "../server/storage/chroma_db", "directory"),
        "documents": ("../server/storage/documents", "../server/storage/documents", "directory"),
        "pdfs": ("../server/storage/pdfs", "../server/storage/pdfs", "directory"),
        "pdf_thumbnails": ("../server/storage/pdf_thumbnails", "../server/storage/pdf_thumbnails", "directory"),
        "document_ids": ("../server/storage/document_ids.json", "../server/storage/document_ids.json", "file"),
    }
    
    for item_name, (source_rel, dest_rel, item_type) in import_map.items():
        source = import_path / source_rel
        dest = Path(dest_rel)
        
        if not source.exists():
            print(f"  ⚠️  {item_name} not found in export, skipping...")
            continue
        
        print(f"  Importing {item_name}...")
        
        try:
            # Create parent directory
            dest.parent.mkdir(parents=True, exist_ok=True)
            
            # Remove existing if present
            if dest.exists():
                if item_type == "file":
                    os.remove(dest)
                else:
                    shutil.rmtree(dest)
            
            # Copy from import
            if item_type == "file":
                shutil.copy2(source, dest)
            else:
                shutil.copytree(source, dest)
            
            print(f"    ✓ Imported successfully")
            
        except Exception as e:
            print(f"    ✗ Error: {str(e)}")
    
    # Clean up temporary extraction if used
    if temp_extract and temp_extract.parent.exists():
        shutil.rmtree(temp_extract.parent)
    
    # Verify import
    print("\nVerifying import...")
    
    # Check database
    if os.path.exists("../server/storage/documents.db"):
        conn = sqlite3.connect("../server/storage/documents.db")
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM documents")
        doc_count = cursor.fetchone()[0]
        conn.close()
        print(f"  ✓ Database: {doc_count} documents")
    else:
        print("  ✗ Database not found")
    
    # Check ChromaDB
    if os.path.exists("../server/storage/chroma_db"):
        print("  ✓ ChromaDB directory present")
    else:
        print("  ✗ ChromaDB directory not found")
    
    # Summary
    print("\n" + "="*50)
    print("IMPORT COMPLETE")
    print("="*50)
    print(f"Imported from: {import_source}")
    if backup:
        print(f"Backup saved to: {backup_dir}")
    print("\nNext steps:")
    print("1. Start the server: ./start.sh")
    print("2. Verify data: python cli.py stats")
    print("3. Test search functionality")
    
    return True


def main():
    parser = argparse.ArgumentParser(description="Import AI Search Tool data")
    parser.add_argument("source", help="Path to export directory or .tar.gz archive")
    parser.add_argument("--no-backup", action="store_true", help="Skip backing up existing data")
    parser.add_argument("--no-verify", action="store_true", help="Skip checksum verification")
    
    args = parser.parse_args()
    
    try:
        success = import_data(
            import_source=args.source,
            backup=not args.no_backup,
            verify=not args.no_verify
        )
        return 0 if success else 1
    except Exception as e:
        print(f"\n❌ Import failed: {str(e)}")
        return 1


if __name__ == "__main__":
    exit(main())