# AI Search Tool

A semantic document search system with a web interface built in Elm and a Python backend using sentence transformers and ChromaDB.

## Installation

### Prerequisites

- Python 3.8 or higher
- Node.js and npm (for Elm)
- Git

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd search-tool
```

### Step 2: Set Up Python Environment

```bash
# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# Install Python dependencies
pip install -r requirements.txt
```

### Step 3: Install Elm

```bash
# Install Elm globally
npm install -g elm

# Navigate to the Elm app directory
cd elm-app

# Build the Elm application
elm make src/Main.elm --output=main.js

# Return to the main directory
cd ..
```

### Step 4: Start the Services

You'll need two terminal windows:

**Terminal 1 - Start the API Server:**
```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Start the server on port 8010 (or any available port)
python server.py 8010
```

**Terminal 2 - Start the Web Server:**
```bash
# Navigate to the Elm app directory
cd elm-app

# Start a simple HTTP server on port 8080
python3 -m http.server 8080
```

### Step 5: Access the Application

Open your web browser and navigate to:
```
http://localhost:8080
```

## Using the Application

### Web Interface

The Elm web application provides:
- **Documents** - View all documents in the system
- **Add Document** - Create new documents with title, content, and type
- **Random** - Display 10 random documents from your collection
- **Stats** - View system statistics
- **Search** - Semantic search across all documents
- **Edit/Delete** - Full document management capabilities

### Command Line Interface

The CLI tool `cli_v2.py` is aliased to 'look'. After activating the virtual environment:

```bash
# Using the aliased command
look COMMAND [ARGS]

# Or directly
python cli_v2.py COMMAND [ARGS]
```

Available commands:
- `add` - Add a new document to the store from a file
- `clear` - Clear all documents and embeddings from the store
- `delete` - Delete a document by ID
- `import-docs` - Import multiple documents from a JSON file
- `list` - List all documents in the store
- `search` - Search for documents using semantic similarity
- `show` - Display the Nth document in a viewer window
- `stats` - Show statistics about the document store

### Example Usage

```bash
# Add a document
look add document.txt --title "My Document" --type "note"

# Search for documents
look search "machine learning"

# List all documents
look list

# Show the 5th document
look show 5
```

## Troubleshooting

### Common Issues

1. **Port already in use**: If ports 8010 or 8080 are taken, use different ports:
   ```bash
   # API server on different port
   python server.py 8011
   
   # Update elm-app/index.html to match:
   # Change apiUrl: "http://localhost:8010" to your new port
   ```

2. **Module not found errors**: Make sure your virtual environment is activated:
   ```bash
   source venv/bin/activate
   ```

3. **Elm compilation errors**: Make sure you're in the elm-app directory:
   ```bash
   cd elm-app
   elm make src/Main.elm --output=main.js
   ```

4. **First time model download**: The first time you run the system, it will download the sentence transformer model (all-MiniLM-L6-v2), which may take a few minutes.

## Features

- **Semantic Search**: Uses sentence transformers to find documents by meaning, not just keywords
- **Vector Storage**: ChromaDB for efficient similarity search
- **Full-Text Storage**: SQLite database for document metadata and content
- **Web Interface**: Modern Elm-based UI with real-time updates
- **CLI Tool**: Command-line interface for automation and scripting
- **Document Management**: Create, read, update, and delete documents
- **Markdown Support**: Full Markdown rendering in the viewer

## Technology Stack

- **Backend**: Python, FastAPI, SQLAlchemy, ChromaDB
- **Frontend**: Elm, HTML5, CSS3
- **ML Model**: sentence-transformers (all-MiniLM-L6-v2)
- **Storage**: SQLite (metadata) + ChromaDB (vectors)