#!/usr/bin/env python3
"""
Migration script to add 'source' column to documents table in all databases.
"""

import os
import sys
from pathlib import Path
import sqlite3

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import config


def migrate_database(db_path):
    """Add source column to a database if it doesn't exist."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if column already exists
        cursor.execute("PRAGMA table_info(documents)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'source' not in columns:
            print(f"Adding 'source' column to {db_path}...")
            cursor.execute("ALTER TABLE documents ADD COLUMN source TEXT")
            conn.commit()
            print(f"  ✓ Successfully added 'source' column")
        else:
            print(f"  ✓ 'source' column already exists in {db_path}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"  ✗ Error migrating {db_path}: {e}")
        return False


def main():
    """Migrate all databases to add source column."""
    print("Starting migration to add 'source' column to all databases...")
    print()
    
    # Get all database directories
    db_dirs = []
    
    # Add default database
    default_db = config.STORAGE_DIR / "default" / "documents.db"
    if default_db.exists():
        db_dirs.append(("default", default_db))
    
    # Add databases from subdirectories
    for subdir in config.STORAGE_DIR.iterdir():
        if subdir.is_dir() and (subdir.name.startswith('db_') or subdir.name == 'default'):
            db_path = subdir / "documents.db"
            if db_path.exists() and subdir.name != 'default':  # Skip default as we already added it
                db_dirs.append((subdir.name, db_path))
    
    if not db_dirs:
        print("No databases found to migrate.")
        return
    
    # Migrate each database
    success_count = 0
    for db_name, db_path in db_dirs:
        print(f"Migrating database: {db_name}")
        if migrate_database(db_path):
            success_count += 1
        print()
    
    # Summary
    print(f"Migration complete: {success_count}/{len(db_dirs)} databases migrated successfully.")


if __name__ == "__main__":
    main()