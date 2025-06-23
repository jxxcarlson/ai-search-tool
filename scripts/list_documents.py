#!/usr/bin/env python3
"""
List all documents with their IDs

Usage:
    python list_documents.py
    python list_documents.py --search "keyword"
"""

import sys
import requests

API_URL = "http://localhost:8010"

def list_documents(search_term=None):
    """List all documents with IDs"""
    try:
        if search_term:
            # Search for specific documents
            response = requests.post(
                f"{API_URL}/search",
                json={"query": search_term, "limit": 20}
            )
            response.raise_for_status()
            documents = response.json()
            print(f"\nSearch results for '{search_term}':")
        else:
            # Get all documents
            response = requests.get(f"{API_URL}/documents")
            response.raise_for_status()
            documents = response.json()
            print("\nAll Documents:")
        
        if not documents:
            print("No documents found.")
            return
        
        print("-" * 80)
        for i, doc in enumerate(documents, 1):
            print(f"{i}. Title: {doc['title']}")
            print(f"   ID: {doc['id']}")
            print(f"   Type: {doc.get('doc_type', 'unknown')}")
            if doc.get('tags'):
                print(f"   Tags: {doc['tags']}")
            if search_term and 'similarity_score' in doc:
                print(f"   Similarity: {doc['similarity_score']:.2f}")
            print("-" * 80)
            
        print(f"\nTotal: {len(documents)} documents")
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching documents: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "--search" and len(sys.argv) > 2:
            search_term = " ".join(sys.argv[2:])
            list_documents(search_term)
        else:
            print(__doc__)
            sys.exit(1)
    else:
        list_documents()

if __name__ == "__main__":
    main()