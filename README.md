# Runing the AI Search Tool

Do this: source venv/bin/activate

The you can do the following, except note that cli_v2.py is aliased to 'look'

Usage: cli_v2.py [OPTIONS] COMMAND [ARGS]...

  Document Store with ChromaDB and SQLite - Search Tool

Options:
  --help  Show this message and exit.

Commands:
  add          Add a new document to the store from a file  Examples:...
  clear        Clear all documents and embeddings from the store
  delete       Delete a document by ID
  import-docs  Import multiple documents from a JSON file
  list         List all documents in the store
  search       Search for documents using semantic similarity
  show         Display the Nth document in a viewer window
  stats        Show statistics about the document store
