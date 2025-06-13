# AI Search Tool

A semantic document search system with a web interface built in Elm and a Python backend using sentence transformers and ChromaDB. Now includes Claude AI integration for intelligent conversations that are automatically saved as searchable documents.

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

### Step 4: Set Up Claude Integration (Optional)

To enable the Claude AI integration:

```bash
# Set your Anthropic API key as an environment variable
export ANTHROPIC_API_KEY=your-api-key-here
```

Note: The Claude integration is optional. The application will work without it, but the "Ask Claude" feature will not be available.

### Step 5: Start the Services

**Option 1: Single Command Startup (Recommended)**

```bash
# On macOS/Linux:
./start.sh

# On Windows or if you prefer Python:
python start.py

# With custom ports:
./start.sh --api-port 8011 --web-port 8081
# or
python start.py --api-port 8011 --web-port 8081
```

This will:
- Check all prerequisites
- Build the Elm app if needed
- Start both servers
- Update configuration automatically
- Handle shutdown gracefully with Ctrl+C

To stop the services later:
```bash
# On macOS/Linux:
./stop.sh

# On Windows or if you prefer Python:
python stop.py

# With custom ports:
./stop.sh --api-port 8011 --web-port 8081
```

**Option 2: Manual Startup (Two Terminals)**

Terminal 1 - Start the API Server:
```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Start the server on port 8010 (or any available port)
python server.py 8010
```

Terminal 2 - Start the Web Server:
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
- **Ask Claude** - Send prompts to Claude AI and save responses as documents

#### Using Claude Integration

1. Click the "Ask Claude" button in the navigation bar
2. Enter your prompt in the text area
3. Click "Send to Claude" to submit your question
4. Claude's response will be automatically saved as a new document
5. The response appears in Markdown format and is fully searchable

Example prompts:
- "Explain how vector databases work"
- "Write a Python function to calculate fibonacci numbers"
- "What are the benefits of functional programming?"

### Command Line Interface

Alias the CLI tool `cli_v2.py` to something 'lu'. For convenience. 
After activating the virtual environment:

```bash
# Using the aliased command
lu COMMAND [ARGS]

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
lu add document.txt --title "My Document" --type "note"

# Search for documents
lu search "machine learning"

# List all documents
lu list

# Show the 5th document
lu show 5
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

5. **Claude API errors**: If you see a 503 error when using the Ask Claude feature:
   - Make sure you've set the ANTHROPIC_API_KEY environment variable
   - Ensure the API key is set in the same terminal session where you start the server
   - Verify your API key is valid and has appropriate permissions

## Features

- **Semantic Search**: Uses sentence transformers to find documents by meaning, not just keywords
- **Vector Storage**: ChromaDB for efficient similarity search
- **Full-Text Storage**: SQLite database for document metadata and content
- **Web Interface**: Modern Elm-based UI with real-time updates
- **CLI Tool**: Command-line interface for automation and scripting
- **Document Management**: Create, read, update, and delete documents
- **Markdown Support**: Full Markdown rendering in the viewer
- **Claude AI Integration**: Ask questions to Claude and save responses as searchable documents

## Technology Stack

- **Backend**: Python, FastAPI, SQLAlchemy, ChromaDB, Anthropic Claude API
- **Frontend**: Elm, HTML5, CSS3
- **ML Model**: sentence-transformers (all-MiniLM-L6-v2)
- **Storage**: SQLite (metadata) + ChromaDB (vectors)

