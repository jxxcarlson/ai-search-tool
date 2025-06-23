#!/usr/bin/env python3
"""Quick fix to add abstract columns to default database"""

import sqlite3
import os

db_path = "../server/storage/default/documents.db"

if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if columns exist
        cursor.execute("PRAGMA table_info(documents)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'abstract' not in columns:
            cursor.execute("ALTER TABLE documents ADD COLUMN abstract TEXT")
            print("Added abstract column")
        else:
            print("abstract column already exists")
            
        if 'abstract_source' not in columns:
            cursor.execute("ALTER TABLE documents ADD COLUMN abstract_source TEXT")
            print("Added abstract_source column")
        else:
            print("abstract_source column already exists")
            
        conn.commit()
        print("✓ Fixed default database")
        
    except Exception as e:
        print(f"Error: {e}")
        conn.rollback()
    finally:
        conn.close()
else:
    print(f"Database not found at {db_path}")