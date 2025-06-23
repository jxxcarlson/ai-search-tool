#!/usr/bin/env python3
"""
Migration script to add abstract fields to existing databases
"""

import os
import sqlite3
from pathlib import Path
from database_manager import get_database_manager

def migrate_database(db_path):
    """Add abstract fields to a single database"""
    print(f"Migrating database: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(documents)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'abstract' not in columns:
            print("  Adding 'abstract' column...")
            cursor.execute("ALTER TABLE documents ADD COLUMN abstract TEXT")
        else:
            print("  'abstract' column already exists")
            
        if 'abstract_source' not in columns:
            print("  Adding 'abstract_source' column...")
            cursor.execute("ALTER TABLE documents ADD COLUMN abstract_source TEXT")
        else:
            print("  'abstract_source' column already exists")
            
        conn.commit()
        print(f"  ✓ Migration completed for {db_path}")
        
    except Exception as e:
        print(f"  ✗ Error migrating {db_path}: {e}")
        conn.rollback()
    finally:
        conn.close()

def main():
    """Migrate all databases"""
    print("Starting database migration to add abstract fields...\n")
    
    # Get database manager
    db_manager = get_database_manager()
    
    # Migrate each database
    databases = db_manager.list_databases()
    
    if not databases:
        print("No databases found to migrate.")
        return
    
    print(f"Found {len(databases)} database(s) to migrate:\n")
    
    for db_info in databases:
        db_id = db_info['id']
        db_name = db_info['name']
        db_path = Path('storage') / db_id / 'documents.db'
        
        if db_path.exists():
            print(f"\nDatabase: {db_name} (ID: {db_id})")
            migrate_database(str(db_path))
        else:
            print(f"\nSkipping {db_name} - database file not found at {db_path}")
    
    print("\n✓ Migration complete!")
    print("\nNote: Restart the server to use the new fields.")

if __name__ == "__main__":
    main()