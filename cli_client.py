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
            click.echo("No documents found.")
            return
        
        if verbose:
            # Verbose format (original format)
            click.echo(f"\nTop {len(results)} results for '{query}':\n")
            for i, doc in enumerate(results, 1):
                doc_type = doc.get('doc_type', 'unknown')
                click.echo(f"{i}. {doc['title']} [{doc_type}] (Score: {doc['similarity_score']:.3f})")
                click.echo(f"   ID: {doc['id']}")
                click.echo(f"   Content: {doc['content'][:100]}...")
                click.echo()
        else:
            # Compact format
            click.echo(f"\nResults for '{query}':")
            for i, doc in enumerate(results, 1):
                doc_type = doc.get('doc_type', 'unknown')
                click.echo(f"{i}. {doc['title']} [{doc_type}] ({doc['similarity_score']:.3f})")
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


if __name__ == '__main__':
    cli()