#!/usr/bin/env python3
"""
Migration script to add doc_type column to existing database
"""
import sqlite3
import os
import sys

def migrate_database(db_path='storage/documents.db'):
    """Add doc_type column to existing documents table"""
    
    if not os.path.exists(db_path):
        print(f"Database not found at {db_path}")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if doc_type column already exists
        cursor.execute("PRAGMA table_info(documents)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'doc_type' in columns:
            print("Column 'doc_type' already exists in documents table")
            return True
        
        # Add the doc_type column
        print("Adding doc_type column to documents table...")
        cursor.execute("ALTER TABLE documents ADD COLUMN doc_type VARCHAR")
        
        # Set default doc_type for existing documents
        cursor.execute("UPDATE documents SET doc_type = 'unknown' WHERE doc_type IS NULL")
        
        conn.commit()
        print("Migration completed successfully!")
        
        # Show current document count
        cursor.execute("SELECT COUNT(*) FROM documents")
        count = cursor.fetchone()[0]
        print(f"Total documents in database: {count}")
        
        return True
        
    except Exception as e:
        print(f"Migration failed: {e}")
        return False
    finally:
        conn.close()

if __name__ == "__main__":
    db_path = sys.argv[1] if len(sys.argv) > 1 else 'storage/documents.db'
    success = migrate_database(db_path)
    sys.exit(0 if success else 1)