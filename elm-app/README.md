# AI Search Tool - Elm Frontend

This is an Elm-based web application that provides a user interface for the AI Search Tool system.

## Features

- **Document Management**: View, add, delete, and search documents
- **Semantic Search**: Search documents using AI-powered semantic search
- **Document Viewer**: View documents with Markdown rendering support
- **Statistics**: View system statistics including document counts and categories
- **Responsive Design**: Works on desktop and mobile devices

## Prerequisites

- [Elm](https://elm-lang.org/) (version 0.19.1)
- The AI Search Tool backend server running on `http://localhost:8000`

## Installation

1. Install Elm if you haven't already:
   ```bash
   npm install -g elm
   ```

2. Navigate to the elm-app directory:
   ```bash
   cd elm-app
   ```

3. Build the application:
   ```bash
   ./build.sh
   ```

## Running the Application

1. First, make sure the AI Search Tool backend is running:
   ```bash
   python server.py
   ```

2. Then serve the Elm app:
   ```bash
   python -m http.server 8080
   ```

3. Open your browser and navigate to `http://localhost:8080`

## Development

To work on the application in development mode:

1. Use elm-live for auto-reloading:
   ```bash
   npm install -g elm-live
   elm-live src/Main.elm --open -- --output=main.js
   ```

## Project Structure

```
elm-app/
├── src/
│   ├── Main.elm      # Main application logic and views
│   ├── Models.elm    # Data models and JSON decoders/encoders
│   └── Api.elm       # HTTP API communication layer
├── elm.json          # Elm dependencies
├── index.html        # HTML entry point
├── style.css         # Application styles
├── build.sh          # Build script
└── README.md         # This file
```

## API Endpoints Used

The Elm app communicates with these backend endpoints:

- `GET /documents` - List all documents
- `POST /documents` - Add a new document
- `POST /search` - Search documents
- `GET /documents/by-index/{index}` - Get document by index
- `DELETE /documents/{id}` - Delete a document
- `PUT /documents/{id}/rename` - Rename a document
- `GET /stats` - Get system statistics
- `DELETE /documents/clear-all` - Clear all documents

## Additional Features Beyond Current App

This Elm version includes all the functionality of the current viewer plus:

- **Add Documents**: Create new documents directly from the web interface
- **Delete Documents**: Remove documents with a single click
- **Statistics View**: See overall system statistics
- **Semantic Search**: Search with similarity scores
- **Responsive Navigation**: Easy switching between different views