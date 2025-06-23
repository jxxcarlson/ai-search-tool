#!/usr/bin/env python3
"""
Update existing documents with extracted authors
"""

import sys
import os
sys.path.append('server')

from sqlalchemy.orm import Session
from database_manager import get_database_manager
from models import Document, get_engine, get_session
from author_extractor import AuthorExtractor
import config

def update_database_authors(database_id: str):
    """Update authors for all documents in a specific database"""
    
    # Get database manager
    db_manager = get_database_manager()
    
    # Switch to the specified database
    db_manager.switch_database(database_id)
    
    # Get current database info
    current_db = db_manager.get_current_database()
    print(f"\nProcessing database: {current_db.name} (ID: {current_db.id})")
    
    # Set config paths for current database
    config.set_database_paths(current_db.id)
    
    # Initialize author extractor
    author_extractor = AuthorExtractor()
    
    # Get database session
    engine = get_engine(str(config.DATABASE_PATH))
    session = get_session(engine)
    
    try:
        # Get all documents
        documents = session.query(Document).all()
        print(f"Found {len(documents)} documents")
        
        updated_count = 0
        skipped_count = 0
        
        for doc in documents:
            # Skip if document already has authors
            if doc.authors and doc.authors.strip():
                print(f"  - Skipping '{doc.title}' (already has authors: {doc.authors})")
                skipped_count += 1
                continue
            
            print(f"  - Processing '{doc.title}'...")
            
            # Extract authors
            extracted_authors = author_extractor.extract_authors(doc.content, doc.doc_type)
            
            if extracted_authors:
                print(f"    Found authors: {extracted_authors}")
                doc.authors = extracted_authors
                updated_count += 1
            else:
                print(f"    No authors found")
        
        # Commit changes
        session.commit()
        print(f"\nSummary for {current_db.name}:")
        print(f"  - Updated: {updated_count} documents")
        print(f"  - Skipped: {skipped_count} documents (already had authors)")
        print(f"  - No authors found: {len(documents) - updated_count - skipped_count} documents")
        
    except Exception as e:
        session.rollback()
        print(f"Error updating database {database_id}: {e}")
        raise
    finally:
        session.close()

def main():
    """Update authors for all databases"""
    print("Updating document authors for all databases")
    print("=" * 50)
    
    # Get database manager
    db_manager = get_database_manager()
    
    # Get all databases
    databases = db_manager.list_databases()
    
    if not databases:
        print("No databases found")
        return
    
    print(f"Found {len(databases)} databases:")
    for db in databases:
        print(f"  - {db.name} (ID: {db.id}, {db.document_count} documents)")
    
    # Process each database
    for db in databases:
        if db.document_count > 0:
            try:
                update_database_authors(db.id)
            except Exception as e:
                print(f"Failed to update database {db.name}: {e}")
                continue
    
    print("\n" + "=" * 50)
    print("Author update complete!")

if __name__ == "__main__":
    main()