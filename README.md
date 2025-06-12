# Document Search Tool with Word Embeddings

A prototype application that stores documents, generates word embeddings, and enables semantic search using natural language queries.

## Features

- Store documents with titles and content
- Automatic word embedding generation using Sentence Transformers
- Vector storage using FAISS for efficient similarity search
- CLI interface for easy interaction
- Semantic search capabilities

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Add a single document
```bash
python cli.py add
```

### Import multiple documents
```bash
python cli.py import-docs --file sample_documents.json
```

### Search documents
```bash
python cli.py search "machine learning algorithms"
python cli.py search "how to build web applications" --limit 3
```

### List all documents
```bash
python cli.py list
```

### Show statistics
```bash
python cli.py stats
```

### Delete a document
```bash
python cli.py delete <doc_id>
```

## How it works

1. **Document Storage**: Documents are stored as JSON files with metadata
2. **Embeddings**: Uses Sentence Transformers (all-MiniLM-L6-v2) to convert text to 384-dimensional vectors
3. **Vector Storage**: FAISS index for fast similarity search
4. **Search**: Converts query to embedding and finds nearest neighbors

## Example

```bash
# Import sample documents
python cli.py import-docs --file sample_documents.json

# Search for Python-related content
python cli.py search "python programming tutorials"

# Search for security topics
python cli.py search "cybersecurity and data protection"
```