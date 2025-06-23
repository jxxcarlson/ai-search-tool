# PDF Source Field Implementation

## Overview
When a PDF file is imported from a URL, the source field is automatically set to that URL.

## Implementation Details

### Backend (`server/server.py`)
The `import_pdf_from_url` endpoint (lines 683-780) handles PDF imports from URLs:

1. Downloads the PDF from the provided URL
2. Processes it using the standard `upload_pdf` function
3. **Automatically sets the source field** to the URL after successful import (lines 765-772):
   ```python
   # Update the document to add the source URL
   if result and result.id:
       document_store.update_document(result.id, source=request.url)
       # Get updated document
       documents = [d for d in document_store.get_all_documents() if d['id'] == result.id]
       if documents:
           return DocumentResponse(**documents[0])
   ```

### Frontend
The Elm frontend already supports:
- Importing PDFs from URLs via a modal dialog
- Displaying the source field for all documents
- Showing URLs as clickable links in the document view

### Testing
To test this functionality:
1. Start the server
2. In the UI, click "Import PDF from URL"
3. Enter a PDF URL
4. After import, view the document - the source field should show the URL

### Note
PDFs uploaded directly (not from URL) will not have a source field set automatically, which is the expected behavior since there's no URL to reference.