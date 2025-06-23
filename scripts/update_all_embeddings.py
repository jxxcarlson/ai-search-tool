#!/usr/bin/env python3
"""
Update all document embeddings to exclude tags from semantic vectors
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'server'))

from document_store_v2_optimized import DocumentStoreV2Optimized
from models import get_session, Document
from tqdm import tqdm

def update_all_embeddings():
    """Re-generate embeddings for all documents using only content (no tags)"""
    
    print("Initializing document store with all-MiniLM-L12-v2 model...")
    # Initialize with model loading enabled
    store = DocumentStoreV2Optimized(load_model=True)
    
    print("Getting all documents...")
    session = get_session(store.engine)
    
    try:
        # Get all documents
        documents = session.query(Document).all()
        total_docs = len(documents)
        
        if total_docs == 0:
            print("No documents found to update.")
            return
        
        print(f"Found {total_docs} documents to update")
        
        # Update each document's embedding
        updated = 0
        failed = 0
        
        for doc in tqdm(documents, desc="Updating embeddings"):
            try:
                # Generate new embedding using only content
                embedding = store.model.encode(doc.content).tolist()
                
                # Update in ChromaDB
                store.collection.update(
                    ids=[doc.id],
                    embeddings=[embedding],
                    metadatas=[{
                        "title": doc.title,
                        "created_at": doc.created_at.isoformat()
                    }]
                )
                
                updated += 1
                
            except Exception as e:
                print(f"\nError updating document {doc.id} ({doc.title}): {e}")
                failed += 1
        
        print(f"\nUpdate complete!")
        print(f"Successfully updated: {updated} documents")
        if failed > 0:
            print(f"Failed to update: {failed} documents")
        
    finally:
        session.close()

if __name__ == "__main__":
    update_all_embeddings()