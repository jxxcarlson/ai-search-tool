#!/usr/bin/env python3
import click
import json
from document_store import DocumentStore


@click.group()
def cli():
    """Document Store with Word Embeddings - Search Tool"""
    pass


@cli.command()
@click.option('--title', prompt='Document title', help='Title of the document')
@click.option('--content', prompt='Document content', help='Content of the document')
def add(title, content):
    """Add a new document to the store"""
    store = DocumentStore()
    doc_id = store.add_document(title, content)
    click.echo(f"Document added successfully with ID: {doc_id}")


@cli.command()
@click.option('--file', type=click.File('r'), help='JSON file containing documents to import')
def import_docs(file):
    """Import multiple documents from a JSON file"""
    store = DocumentStore()
    documents = json.load(file)
    
    for doc in documents:
        doc_id = store.add_document(doc['title'], doc['content'])
        click.echo(f"Added: {doc['title']} (ID: {doc_id})")
    
    click.echo(f"\nImported {len(documents)} documents successfully")


@cli.command()
@click.argument('query')
@click.option('--limit', '-k', default=5, help='Number of results to return')
def search(query, limit):
    """Search for documents using semantic similarity"""
    store = DocumentStore()
    results = store.search(query, k=limit)
    
    if not results:
        click.echo("No documents found.")
        return
    
    click.echo(f"\nTop {len(results)} results for '{query}':\n")
    for i, doc in enumerate(results, 1):
        click.echo(f"{i}. {doc['title']} (Score: {doc['similarity_score']:.3f})")
        click.echo(f"   ID: {doc['id']}")
        click.echo(f"   Content: {doc['content'][:100]}...")
        click.echo()


@cli.command()
def list():
    """List all documents in the store"""
    store = DocumentStore()
    documents = store.get_all_documents()
    
    if not documents:
        click.echo("No documents in the store.")
        return
    
    click.echo(f"\nTotal documents: {len(documents)}\n")
    for doc in documents:
        click.echo(f"- {doc['title']} (ID: {doc['id']})")
        click.echo(f"  Created: {doc['created_at']}")
        click.echo(f"  Content: {doc['content'][:80]}...")
        click.echo()


@cli.command()
@click.argument('doc_id')
def delete(doc_id):
    """Delete a document by ID"""
    store = DocumentStore()
    if store.delete_document(doc_id):
        click.echo(f"Document {doc_id} deleted successfully")
    else:
        click.echo(f"Document {doc_id} not found")


@cli.command()
def stats():
    """Show statistics about the document store"""
    store = DocumentStore()
    documents = store.get_all_documents()
    
    click.echo(f"\nDocument Store Statistics:")
    click.echo(f"- Total documents: {len(documents)}")
    click.echo(f"- Embedding dimension: {store.embedding_dim}")
    click.echo(f"- Model: all-MiniLM-L6-v2")
    click.echo(f"- Storage location: {store.storage_dir}")


if __name__ == '__main__':
    cli()