#!/usr/bin/env python3
"""
Reset the AI Search Tool database to a clean state.
This will delete all documents and start fresh.
"""

import os
import shutil
import argparse
from datetime import datetime
from pathlib import Path


def backup_data(backup_dir):
    """Create a backup of existing data before reset."""
    print(f"Creating backup in: {backup_dir}")
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    # Define what to backup
    items_to_backup = [
        ("../server/storage/documents.db", "documents.db"),
        ("../server/storage/chroma_db", "chroma_db"),
        ("../server/storage/documents", "documents"),
        ("../server/storage/pdfs", "pdfs"),
        ("../server/storage/pdf_thumbnails", "pdf_thumbnails"),
        ("../server/storage/document_ids.json", "document_ids.json")
    ]
    
    backed_up = False
    for source, dest_name in items_to_backup:
        source_path = Path(source)
        if source_path.exists():
            dest_path = backup_dir / dest_name
            try:
                if source_path.is_file():
                    shutil.copy2(source_path, dest_path)
                else:
                    shutil.copytree(source_path, dest_path, dirs_exist_ok=True)
                print(f"  ✓ Backed up {source}")
                backed_up = True
            except Exception as e:
                print(f"  ⚠️  Failed to backup {source}: {e}")
    
    return backed_up


def reset_database(no_backup=False):
    """Reset the database to a clean state."""
    
    # Create backup unless explicitly disabled
    if not no_backup:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = Path("backups") / f"pre_reset_{timestamp}"
        
        if backup_data(backup_dir):
            print(f"\n✓ Backup created at: {backup_dir}")
        else:
            print("\n⚠️  No data to backup")
    
    print("\nResetting database...")
    
    # Remove existing storage
    storage_items = [
        "../server/storage/documents.db",
        "../server/storage/chroma_db",
        "../server/storage/documents",
        "../server/storage/pdfs", 
        "../server/storage/pdf_thumbnails",
        "../server/storage/document_ids.json"
    ]
    
    for item in storage_items:
        item_path = Path(item)
        if item_path.exists():
            try:
                if item_path.is_file():
                    os.remove(item_path)
                    print(f"  ✓ Removed {item}")
                else:
                    shutil.rmtree(item_path)
                    print(f"  ✓ Removed {item}/")
            except Exception as e:
                print(f"  ✗ Failed to remove {item}: {e}")
    
    # Recreate directory structure
    directories = [
        "../server/storage",
        "../server/storage/documents",
        "../server/storage/pdfs",
        "../server/storage/pdf_thumbnails"
    ]
    
    print("\nCreating fresh directories...")
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
        print(f"  ✓ Created {directory}")
    
    # Initialize document_ids.json
    doc_ids_path = Path("../server/storage/document_ids.json")
    with open(doc_ids_path, "w") as f:
        f.write("[]")
    print(f"  ✓ Created {doc_ids_path}")
    
    print("\n✓ Database reset complete!")
    print("\nThe system is now ready to start with a clean database.")
    print("Run ./start.sh to start the server.")


def main():
    parser = argparse.ArgumentParser(description="Reset AI Search Tool database")
    parser.add_argument("--no-backup", action="store_true", 
                       help="Skip creating a backup before reset")
    parser.add_argument("--confirm", action="store_true",
                       help="Skip confirmation prompt")
    
    args = parser.parse_args()
    
    if not args.confirm:
        print("⚠️  WARNING: This will delete all documents and data!")
        print("A backup will be created unless --no-backup is specified.")
        response = input("\nAre you sure you want to reset the database? (yes/N): ")
        
        if response.lower() != "yes":
            print("Reset cancelled.")
            return 1
    
    try:
        reset_database(no_backup=args.no_backup)
        return 0
    except Exception as e:
        print(f"\n❌ Reset failed: {e}")
        return 1


if __name__ == "__main__":
    exit(main())