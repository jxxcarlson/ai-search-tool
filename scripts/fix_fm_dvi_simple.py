#!/usr/bin/env python3
"""
Simple script to fix fm.dvi titles directly in the database
"""

import sqlite3
from pathlib import Path

# Database paths
storage_dir = Path(__file__).parent / "server" / "storage"

def fix_database(db_path):
    """Fix fm.dvi titles in a database"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Find documents with fm.dvi title
    cursor.execute("SELECT id, source, content FROM documents WHERE title = 'fm.dvi'")
    documents = cursor.fetchall()
    
    fixed_count = 0
    
    for doc_id, source, content in documents:
        new_title = None
        
        # If source contains "Relativity", use that as a hint
        if source and 'Relativity' in source:
            new_title = "An Introduction to Relativity"
        # Check content for clues
        elif content:
            content_lower = content[:1000].lower()
            if 'introduction' in content_lower and 'relativity' in content_lower:
                new_title = "An Introduction to Relativity"
            elif 'jayant' in content_lower and 'narlikar' in content_lower:
                new_title = "An Introduction to Relativity"
        
        if new_title:
            print(f"Updating document {doc_id}: fm.dvi -> {new_title}")
            cursor.execute("UPDATE documents SET title = ? WHERE id = ?", (new_title, doc_id))
            fixed_count += 1
    
    conn.commit()
    conn.close()
    
    return fixed_count

def main():
    """Fix all databases"""
    print("Fixing fm.dvi titles in all databases...")
    
    total_fixed = 0
    
    # Check all database directories
    for db_dir in storage_dir.iterdir():
        if db_dir.is_dir():
            db_path = db_dir / "documents.db"
            if db_path.exists():
                print(f"\nChecking database: {db_dir.name}")
                fixed = fix_database(db_path)
                total_fixed += fixed
                if fixed > 0:
                    print(f"  Fixed {fixed} documents")
                else:
                    print(f"  No fm.dvi titles found")
    
    print(f"\nTotal documents fixed: {total_fixed}")

if __name__ == "__main__":
    main()