#!/usr/bin/env python3
import click
import httpx
import json
import sys


import os
API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8001")


def check_server():
    """Check if the server is running"""
    try:
        response = httpx.get(f"{API_BASE_URL}/")
        response.raise_for_status()
        return True
    except (httpx.ConnectError, httpx.HTTPStatusError):
        click.echo("Error: Server is not running. Start it with: python server.py", err=True)
        sys.exit(1)


@click.group()
def cli():
    """Fast Document Search CLI Client"""
    check_server()


@cli.command()
@click.option('--title', prompt='Document title', help='Title of the document')
@click.option('--path', prompt='Path to document file', help='Path to the document file to import')
def add(title, path):
    """Add a new document to the store from a file
    
    \b
    Examples:
      python cli_client.py add --title "My Research Paper" --path /path/to/paper.pdf
      python cli_client.py add --title "Meeting Notes" --path ./notes.md
      python cli_client.py add --title "What are FPGAs?" --path inbox/fpga.md
      python cli_client.py add  # Interactive mode - will prompt for title and path
    
    Note: Always quote titles containing special characters (?, *, &, etc.)
    """
    # Check if file exists
    if not os.path.exists(path):
        click.echo(f"Error: File not found: {path}", err=True)
        return
    
    # Read the document content
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        click.echo(f"Error reading file: {e}", err=True)
        return
    
    # Infer document type from file extension
    doc_type = os.path.splitext(path)[1].lstrip('.').lower() or 'txt'
    
    # Send to server
    response = httpx.post(
        f"{API_BASE_URL}/documents",
        json={"title": title, "content": content, "doc_type": doc_type}
    )
    if response.status_code == 200:
        doc = response.json()
        click.echo(f"Document added successfully with ID: {doc['id']}")
        click.echo(f"Source file: {path} (type: {doc_type})")
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.option('--file', type=click.File('r'), help='JSON file containing documents to import')
def import_docs(file):
    """Import multiple documents from a JSON file"""
    documents = json.load(file)
    
    response = httpx.post(
        f"{API_BASE_URL}/documents/import",
        json=documents,
        timeout=30.0  # Longer timeout for bulk import
    )
    
    if response.status_code == 200:
        result = response.json()
        click.echo(f"\nImported {result['imported']} documents successfully")
        for doc in result['documents']:
            click.echo(f"Added: {doc['title']} (ID: {doc['id']})")
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.argument('query')
@click.option('--limit', '-k', default=5, help='Number of results to return')
@click.option('--verbose', '-v', is_flag=True, help='Show detailed information for each result')
def search(query, limit, verbose):
    """Search for documents using semantic similarity"""
    response = httpx.post(
        f"{API_BASE_URL}/search",
        json={"query": query, "limit": limit}
    )
    
    if response.status_code == 200:
        results = response.json()
        
        if not results:
            click.echo()
            click.echo("No documents found.")
            click.echo()
            return
        
        if verbose:
            # Verbose format (original format)
            click.echo()  # Blank line before
            click.echo(f"Top {len(results)} results for '{query}':\n")
            for i, doc in enumerate(results, 1):
                doc_type = doc.get('doc_type', 'unknown')
                doc_index = doc.get('index', '?')
                click.echo(f"{doc_index}. {doc['title']} [{doc_type}] (Score: {doc['similarity_score']:.3f})")
                click.echo(f"   ID: {doc['id']}")
                click.echo(f"   Content: {doc['content'][:100]}...")
                click.echo()
        else:
            # Compact format
            click.echo()  # Blank line before
            click.echo(f"Results for '{query}':")
            for i, doc in enumerate(results, 1):
                doc_type = doc.get('doc_type', 'unknown')
                doc_index = doc.get('index', '?')
                click.echo(f"{doc_index}. {doc['title']} [{doc_type}] ({doc['similarity_score']:.3f})")
            click.echo()  # Blank line after
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.option('--verbose', '-v', is_flag=True, help='Show detailed information for each document')
def list(verbose):
    """List all documents in the store"""
    response = httpx.get(f"{API_BASE_URL}/documents")
    
    if response.status_code == 200:
        documents = response.json()
        
        if not documents:
            click.echo("No documents in the store.")
            return
        
        # Sort by creation date for consistent ordering
        documents.sort(key=lambda d: d.get('created_at', ''))
        
        if verbose:
            # Verbose format (original format)
            click.echo(f"\nTotal documents: {len(documents)}\n")
            for doc in documents:
                doc_type = doc.get('doc_type', 'unknown')
                click.echo(f"- {doc['title']} [{doc_type}] (ID: {doc['id']})")
                click.echo(f"  Created: {doc['created_at']}")
                click.echo(f"  Content: {doc['content'][:80]}...")
                click.echo()
        else:
            # Compact format
            for i, doc in enumerate(documents, 1):
                doc_type = doc.get('doc_type', 'unknown')
                click.echo(f"{i}. {doc['title']} [{doc_type}]")
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.argument('doc_id')
def delete(doc_id):
    """Delete a document by ID"""
    response = httpx.delete(f"{API_BASE_URL}/documents/{doc_id}")
    
    if response.status_code == 200:
        result = response.json()
        click.echo(result['message'])
    elif response.status_code == 404:
        click.echo(f"Document {doc_id} not found")
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
def stats():
    """Show statistics about the document store"""
    response = httpx.get(f"{API_BASE_URL}/stats")
    
    if response.status_code == 200:
        stats = response.json()
        click.echo(f"\nDocument Store Statistics:")
        click.echo(f"- Total documents: {stats['total_documents']}")
        click.echo(f"- ChromaDB collection size: {stats['chroma_collection_count']}")
        click.echo(f"- Embedding dimension: {stats['embedding_dimension']}")
        click.echo(f"- Model: {stats['model']}")
        click.echo(f"- Storage location: {stats['storage_location']}")
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.option('--confirm', is_flag=True, help='Skip confirmation prompt')
def clear(confirm):
    """Clear all documents and embeddings from the store"""
    if not confirm:
        click.confirm('Are you sure you want to delete ALL documents and embeddings?', abort=True)
    
    response = httpx.delete(f"{API_BASE_URL}/documents/clear-all")
    
    if response.status_code == 200:
        result = response.json()
        click.echo(result['message'])
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.argument('doc_id')
@click.option('--title', prompt='New title', help='New title for the document')
def rename(doc_id, title):
    """Rename a document by ID"""
    response = httpx.put(
        f"{API_BASE_URL}/documents/{doc_id}/rename",
        json={"new_title": title}
    )
    
    if response.status_code == 200:
        result = response.json()
        click.echo(result['message'])
    elif response.status_code == 404:
        click.echo(f"Document {doc_id} not found", err=True)
    else:
        click.echo(f"Error: {response.text}", err=True)


@cli.command()
@click.argument('index', type=int)
def info(index):
    """Show detailed information about the Nth document"""
    # Get document by index
    response = httpx.get(f"{API_BASE_URL}/documents/by-index/{index}")
    
    if response.status_code == 404:
        click.echo(f"Error: No document found at index {index}", err=True)
        return
    elif response.status_code != 200:
        click.echo(f"Error: {response.text}", err=True)
        return
    
    document = response.json()
    
    # Format creation date
    created_at = document.get('created_at', 'N/A')
    if created_at != 'N/A':
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            created_at = dt.strftime('%b %d, %Y at %I:%M %p')
        except:
            pass
    
    # Display info
    click.echo(f"\nDocument {index}:")
    click.echo(f"  Title: {document['title']}")
    click.echo(f"  Type: [{document.get('doc_type', 'unknown')}]")
    click.echo(f"  Created: {created_at}")
    click.echo(f"  ID: {document['id']}")


@cli.command()
def size():
    """Show the number of documents in the store"""
    response = httpx.get(f"{API_BASE_URL}/documents")
    
    if response.status_code == 200:
        documents = response.json()
        count = len(documents)
        
        click.echo()
        click.echo(f"{count}")
        click.echo()
    else:
        click.echo()
        click.echo(f"Error: {response.text}", err=True)
        click.echo()


@cli.command()
@click.argument('n', type=int, required=False)
def tail(n):
    """List the last N documents (default: 10)"""
    if n is None:
        n = 10
    response = httpx.get(f"{API_BASE_URL}/documents")
    
    if response.status_code == 200:
        documents = response.json()
        
        if not documents:
            click.echo()
            click.echo("No documents in the store.")
            click.echo()
            return
        
        # Sort by creation date to ensure consistent ordering
        documents.sort(key=lambda d: d.get('created_at', ''))
        
        # Get the last n documents
        last_n = documents[-n:] if n < len(documents) else documents
        
        # Display in reverse order (most recent first)
        click.echo()
        click.echo(f"Last {len(last_n)} documents (most recent first):")
        for i, doc in enumerate(reversed(last_n), 1):
            doc_type = doc.get('doc_type', 'unknown')
            # Calculate the actual document index
            actual_index = len(documents) - len(last_n) + len(last_n) - i + 1
            click.echo(f"{actual_index}. {doc['title']} [{doc_type}]")
        click.echo()
    else:
        click.echo()
        click.echo(f"Error: {response.text}", err=True)
        click.echo()


@cli.command()
@click.argument('n', type=int, required=False)
def random(n):
    """Show N random documents (default: 10)"""
    import random as rand_module
    
    if n is None:
        n = 10
    
    response = httpx.get(f"{API_BASE_URL}/documents")
    
    if response.status_code == 200:
        documents = response.json()
        
        if not documents:
            click.echo()
            click.echo("No documents in the store.")
            click.echo()
            return
        
        # Sort by creation date to maintain consistent indexing
        documents.sort(key=lambda d: d.get('created_at', ''))
        
        # Sample random documents
        sample_size = min(n, len(documents))
        random_indices = rand_module.sample(range(len(documents)), sample_size)
        random_docs = [(i + 1, documents[i]) for i in sorted(random_indices)]
        
        click.echo()
        click.echo(f"{sample_size} random documents:")
        for idx, doc in random_docs:
            doc_type = doc.get('doc_type', 'unknown')
            click.echo(f"{idx}. {doc['title']} [{doc_type}]")
        click.echo()
    else:
        click.echo()
        click.echo(f"Error: {response.text}", err=True)
        click.echo()


@cli.command()
@click.argument('index', type=int)
def show(index):
    """Display the Nth document in a viewer window"""
    import webbrowser
    from pathlib import Path
    
    # First check if document exists
    response = httpx.get(f"{API_BASE_URL}/documents/by-index/{index}")
    
    if response.status_code == 404:
        click.echo(f"Error: No document found at index {index}", err=True)
        return
    elif response.status_code != 200:
        click.echo(f"Error: {response.text}", err=True)
        return
    
    document = response.json()
    
    # Get the viewer directory
    viewer_dir = Path(__file__).parent / 'viewer'
    viewer_file = viewer_dir / 'index.html'
    
    if not viewer_file.exists():
        click.echo("Error: Viewer application not found", err=True)
        return
    
    # Extract port from API_BASE_URL
    import re
    port_match = re.search(r':(\d+)', API_BASE_URL)
    port = port_match.group(1) if port_match else '8001'
    
    # Build URL with document index and port
    viewer_url = f"file://{viewer_file.absolute()}?index={index}&port={port}"
    
    click.echo(f"Opening document {index}: {document['title']}")
    
    # Open in default browser
    try:
        webbrowser.open(viewer_url)
    except Exception as e:
        click.echo(f"Error opening viewer: {e}", err=True)


def main():
    # Check if no arguments provided (will show help)
    if len(sys.argv) == 1:
        click.echo()  # Blank line before
        sys.argv.append('--help')  # Add --help flag
    
    try:
        cli()
    finally:
        if '--help' in sys.argv:
            click.echo()  # Blank line after help

if __name__ == '__main__':
    main()