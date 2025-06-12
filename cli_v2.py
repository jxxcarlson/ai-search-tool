#!/usr/bin/env python3
import click
import json
import os
import subprocess
import webbrowser
import html
from pathlib import Path
from document_store_v2_optimized import DocumentStoreV2Optimized as DocumentStoreV2


@click.group()
def cli():
    """Document Store with ChromaDB and SQLite - Search Tool"""
    pass


@cli.command()
@click.option('--title', prompt='Document title', help='Title of the document')
@click.option('--path', prompt='Path to document file', help='Path to the document file to import')
def add(title, path):
    """Add a new document to the store from a file
    
    \b
    Examples:
      python cli_v2.py add --title "My Research Paper" --path /path/to/paper.pdf
      python cli_v2.py add --title "Meeting Notes" --path ./notes.md
      python cli_v2.py add --title "What are FPGAs?" --path inbox/fpga.md
      python cli_v2.py add  # Interactive mode - will prompt for title and path
    
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
    
    # Add to store
    store = DocumentStoreV2(load_model=True)  # Need model for embeddings
    doc_id = store.add_document(title, content, doc_type=doc_type)
    click.echo(f"Document added successfully with ID: {doc_id}")
    click.echo(f"Source file: {path} (type: {doc_type})")


@cli.command()
@click.option('--file', type=click.File('r'), help='JSON file containing documents to import')
def import_docs(file):
    """Import multiple documents from a JSON file"""
    store = DocumentStoreV2(load_model=True)  # Need model for embeddings
    documents = json.load(file)
    
    for doc in documents:
        doc_id = store.add_document(doc['title'], doc['content'])
        click.echo(f"Added: {doc['title']} (ID: {doc_id})")
    
    click.echo(f"\nImported {len(documents)} documents successfully")


@cli.command()
@click.argument('query')
@click.option('--limit', '-k', default=5, help='Number of results to return')
@click.option('--verbose', '-v', is_flag=True, help='Show detailed information for each result')
def search(query, limit, verbose):
    """Search for documents using semantic similarity"""
    store = DocumentStoreV2(load_model=True)  # Need model for search
    results = store.search(query, k=limit)
    
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


@cli.command()
@click.option('--verbose', '-v', is_flag=True, help='Show detailed information for each document')
def list(verbose):
    """List all documents in the store"""
    store = DocumentStoreV2(load_model=False)  # No model needed
    documents = store.get_all_documents()
    
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


@cli.command()
@click.argument('doc_id')
def delete(doc_id):
    """Delete a document by ID"""
    store = DocumentStoreV2(load_model=False)  # No model needed
    if store.delete_document(doc_id):
        click.echo(f"Document {doc_id} deleted successfully")
    else:
        click.echo(f"Document {doc_id} not found")


@cli.command()
def stats():
    """Show statistics about the document store"""
    store = DocumentStoreV2(load_model=False)  # No model needed
    stats = store.get_stats()
    
    click.echo(f"\nDocument Store Statistics:")
    click.echo(f"- Total documents: {stats['total_documents']}")
    click.echo(f"- ChromaDB collection size: {stats['chroma_collection_count']}")
    click.echo(f"- Embedding dimension: {stats['embedding_dimension']}")
    click.echo(f"- Model: {stats['model']}")
    click.echo(f"- Storage location: {stats['storage_location']}")


@cli.command()
@click.option('--confirm', is_flag=True, help='Skip confirmation prompt')
def clear(confirm):
    """Clear all documents and embeddings from the store"""
    if not confirm:
        click.confirm('Are you sure you want to delete ALL documents and embeddings?', abort=True)
    
    store = DocumentStoreV2(load_model=False)  # No model needed
    try:
        count = store.clear_all()
        click.echo(f"Successfully cleared {count} documents from the store.")
    except Exception as e:
        click.echo(f"Error clearing store: {e}", err=True)


@cli.command()
@click.argument('index', type=int)
def show(index):
    """Display the Nth document in a viewer window"""
    store = DocumentStoreV2(load_model=False)  # No model needed
    
    # Get the document
    document = store.get_document_by_index(index)
    if not document:
        click.echo(f"Error: No document found at index {index}", err=True)
        return
    
    # Get the viewer directory
    viewer_dir = Path(__file__).parent / 'viewer'
    viewer_file = viewer_dir / 'index.html'
    
    if not viewer_file.exists():
        click.echo("Error: Viewer application not found", err=True)
        return
    
    # For standalone mode, create a simple HTML with inline viewer
    import tempfile
    
    # Create a self-contained HTML file
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{document['title']} - Document Viewer</title>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background: #f5f5f5; }}
        .container {{ max-width: 900px; margin: 0 auto; background: white; min-height: 100vh; box-shadow: 0 0 20px rgba(0,0,0,0.1); }}
        header {{ background: #2c3e50; color: white; padding: 2rem; border-bottom: 4px solid #3498db; }}
        h1 {{ margin: 0 0 1rem 0; }}
        .metadata {{ display: flex; gap: 2rem; font-size: 0.9rem; opacity: 0.9; }}
        main {{ padding: 2rem; }}
        .text-content {{ white-space: pre-wrap; font-family: monospace; background: #f8f8f8; padding: 1.5rem; border-radius: 4px; }}
        .markdown-content {{ line-height: 1.6; }}
        .markdown-content h1, .markdown-content h2 {{ border-bottom: 1px solid #eee; padding-bottom: 0.3em; }}
        .markdown-content pre {{ background: #f6f8fa; padding: 1em; border-radius: 6px; overflow-x: auto; }}
        .markdown-content code {{ background: #f6f8fa; padding: 0.2em 0.4em; border-radius: 3px; }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>{html.escape(document['title'])}</h1>
            <div class="metadata">
                <span><strong>Created:</strong> <span id="created-date">{document.get('created_at', 'N/A')}</span></span>
                <span><strong>Modified:</strong> <span id="modified-date">{document.get('updated_at', 'N/A')}</span></span>
                <span><strong>Type:</strong> {document.get('doc_type', 'unknown')}</span>
            </div>
        </header>
        <main>
            <div id="content"></div>
        </main>
    </div>
    <script>
        const content = {json.dumps(document.get('content', ''))};
        const docType = {json.dumps(document.get('doc_type', 'txt'))};
        
        // Format dates
        function formatDate(dateString) {{
            if (!dateString || dateString === 'N/A') return 'N/A';
            const date = new Date(dateString);
            const options = {{
                month: 'short',
                day: 'numeric', 
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
            }};
            return date.toLocaleString('en-US', options);
        }}
        
        // Update date displays
        const createdSpan = document.getElementById('created-date');
        const modifiedSpan = document.getElementById('modified-date');
        if (createdSpan) createdSpan.textContent = formatDate(createdSpan.textContent);
        if (modifiedSpan) modifiedSpan.textContent = formatDate(modifiedSpan.textContent);
        
        // Render content
        const contentDiv = document.getElementById('content');
        if (docType === 'md' || docType === 'markdown') {{
            contentDiv.className = 'markdown-content';
            contentDiv.innerHTML = marked.parse(content);
        }} else {{
            contentDiv.className = 'text-content';
            contentDiv.textContent = content;
        }}
    </script>
</body>
</html>"""
    
    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
        f.write(html_content)
        temp_file = f.name
    
    click.echo(f"Opening document {index}: {document['title']}")
    
    # Open in default browser
    try:
        webbrowser.open(f'file://{temp_file}')
    except Exception as e:
        click.echo(f"Error opening viewer: {e}", err=True)


if __name__ == '__main__':
    cli()