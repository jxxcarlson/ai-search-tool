#!/usr/bin/env python3
"""
Diagnose and fix mismatch between documents and embeddings in ChromaDB.
This script identifies orphaned embeddings and missing embeddings.
"""

import sqlite3
import os
import sys

# Add server directory to path to import chromadb
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'server'))

import chromadb
from chromadb.config import Settings

def diagnose_mismatch(db_path="../server/storage/default/documents.db", 
                     collection_name="documents"):
    """Diagnose the mismatch between SQLite documents and ChromaDB embeddings"""
    
    # Connect to SQLite
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get all document IDs from SQLite
    cursor.execute("SELECT id FROM documents")
    sqlite_ids = {str(row[0]) for row in cursor.fetchall()}
    print(f"Found {len(sqlite_ids)} documents in SQLite database")
    
    # Connect to ChromaDB
    chroma_client = chromadb.PersistentClient(
        path="../server/storage/default/chroma_db",
        settings=Settings(anonymized_telemetry=False)
    )
    
    try:
        collection = chroma_client.get_collection(name=collection_name)
    except Exception as e:
        print(f"Error getting collection '{collection_name}': {e}")
        conn.close()
        return
    
    # Get all document IDs from ChromaDB
    all_data = collection.get(include=['metadatas'])
    chroma_ids = set(all_data['ids'])
    print(f"Found {len(chroma_ids)} embeddings in ChromaDB")
    
    # Find mismatches
    missing_embeddings = sqlite_ids - chroma_ids
    orphaned_embeddings = chroma_ids - sqlite_ids
    
    print(f"\nMismatch Analysis:")
    print(f"- Documents without embeddings: {len(missing_embeddings)}")
    print(f"- Orphaned embeddings (no document): {len(orphaned_embeddings)}")
    
    if missing_embeddings:
        print("\nDocuments missing embeddings:")
        for doc_id in sorted(missing_embeddings):
            cursor.execute("SELECT title FROM documents WHERE id = ?", (doc_id,))
            result = cursor.fetchone()
            title = result[0] if result else "Unknown"
            print(f"  - ID {doc_id}: {title}")
    
    if orphaned_embeddings:
        print("\nOrphaned embeddings to remove:")
        for embed_id in sorted(orphaned_embeddings):
            metadata = next((m for i, m in zip(all_data['ids'], all_data['metadatas']) 
                           if i == embed_id), {})
            title = metadata.get('title', 'Unknown')
            print(f"  - ID {embed_id}: {title}")
    
    conn.close()
    return orphaned_embeddings, missing_embeddings


def fix_mismatch(collection_name="documents", dry_run=True):
    """Remove orphaned embeddings from ChromaDB"""
    
    orphaned_embeddings, missing_embeddings = diagnose_mismatch(collection_name=collection_name)
    
    if not orphaned_embeddings:
        print("\nNo orphaned embeddings to remove.")
        return
    
    if dry_run:
        print(f"\nDRY RUN: Would remove {len(orphaned_embeddings)} orphaned embeddings")
        print("Run with --fix flag to actually remove them")
        return
    
    # Connect to ChromaDB
    chroma_client = chromadb.PersistentClient(
        path="../server/storage/default/chroma_db",
        settings=Settings(anonymized_telemetry=False)
    )
    
    collection = chroma_client.get_collection(name=collection_name)
    
    # Remove orphaned embeddings
    print(f"\nRemoving {len(orphaned_embeddings)} orphaned embeddings...")
    try:
        collection.delete(ids=list(orphaned_embeddings))
        print("✓ Successfully removed orphaned embeddings")
    except Exception as e:
        print(f"✗ Error removing embeddings: {e}")
        return
    
    # Verify the fix
    print("\nVerifying fix...")
    diagnose_mismatch(collection_name=collection_name)


if __name__ == "__main__":
    import sys
    
    if "--fix" in sys.argv:
        print("Running in FIX mode...")
        fix_mismatch(dry_run=False)
    else:
        print("Running in diagnostic mode...")
        diagnose_mismatch()
        print("\nTo fix the issues, run: python fix_embedding_mismatch.py --fix")