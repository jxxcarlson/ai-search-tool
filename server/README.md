# AI Search Tool Server

This directory contains the API server components for the AI Search Tool.

## Structure

```
server/
├── server.py                    # Main FastAPI application
├── models.py                    # SQLAlchemy database models
├── document_store_v2_optimized.py  # Document store implementation
├── config.py                    # Configuration settings
├── storage/                     # Data storage directory
│   ├── documents.db            # SQLite database
│   ├── chroma_db/              # ChromaDB vector storage
│   ├── documents/              # JSON document files
│   ├── pdfs/                   # Uploaded PDF files
│   └── pdf_thumbnails/         # PDF preview images
└── api_server.log              # Server logs
```

## Configuration

The server configuration is centralized in `config.py`. Key settings include:

- Storage paths
- Port configuration
- Model settings
- API keys

Environment variables:
- `API_PORT`: API server port (default: 8010)
- `WEB_PORT`: Web server port (default: 8080) 
- `ANTHROPIC_API_KEY`: Claude API key (optional)
- `HF_HUB_OFFLINE`: Set to "1" for offline mode

## Running the Server

The server is typically started using the `start.sh` script from the project root:

```bash
./start.sh
```

To run directly:

```bash
cd server
python server.py [port]
```

## API Endpoints

- `GET /documents` - List all documents
- `POST /documents` - Create a new document
- `GET /documents/{id}` - Get a specific document
- `PUT /documents/{id}` - Update a document
- `DELETE /documents/{id}` - Delete a document
- `POST /search` - Semantic search
- `POST /clusters` - Get document clusters
- `POST /claude` - Send prompt to Claude AI
- `POST /upload-pdf` - Upload a PDF file
- `GET /pdf/{filename}` - Serve PDF file
- `GET /pdf/thumbnail/{filename}` - Serve PDF thumbnail
- `GET /stats` - Get system statistics

## Dependencies

The server requires all packages listed in the main `requirements.txt` file.

Key dependencies:
- FastAPI & Uvicorn - Web framework
- SQLAlchemy - Database ORM
- ChromaDB - Vector database
- Sentence Transformers - Embedding generation
- Anthropic - Claude AI integration
- PyPDF2 & pdf2image - PDF processing