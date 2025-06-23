#!/usr/bin/env python3
"""Fix all databases by adding abstract columns"""

import sqlite3
import os
import glob

# Find all database files
db_files = glob.glob("../server/storage/*/documents.db")

print(f"Found {len(db_files)} databases to fix\n")

for db_path in db_files:
    db_name = os.path.basename(os.path.dirname(db_path))
    print(f"Fixing database: {db_name}")
    
    if os.path.exists(db_path):
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        try:
            # Check if columns exist
            cursor.execute("PRAGMA table_info(documents)")
            columns = [col[1] for col in cursor.fetchall()]
            
            if 'abstract' not in columns:
                cursor.execute("ALTER TABLE documents ADD COLUMN abstract TEXT")
                print("  ✓ Added abstract column")
            else:
                print("  - abstract column already exists")
                
            if 'abstract_source' not in columns:
                cursor.execute("ALTER TABLE documents ADD COLUMN abstract_source TEXT")
                print("  ✓ Added abstract_source column")
            else:
                print("  - abstract_source column already exists")
                
            conn.commit()
            
        except Exception as e:
            print(f"  ✗ Error: {e}")
            conn.rollback()
        finally:
            conn.close()
    else:
        print(f"  ✗ Database not found at {db_path}")
    
    print()

print("✓ All databases fixed!")
print("\nPlease restart the server for changes to take effect.")