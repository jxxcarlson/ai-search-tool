from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import os
from anthropic import Anthropic
from datetime import datetime

from document_store_v2_optimized import DocumentStoreV2Optimized as DocumentStoreV2


class DocumentRequest(BaseModel):
    title: str
    content: str
    doc_type: Optional[str] = None


class RenameRequest(BaseModel):
    new_title: str


class UpdateRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    doc_type: Optional[str] = None


class ClaudeRequest(BaseModel):
    prompt: str
    max_tokens: Optional[int] = 1000
    temperature: Optional[float] = 0.7


class SearchRequest(BaseModel):
    query: str
    limit: int = 5


class DocumentResponse(BaseModel):
    id: str
    title: str
    content: str
    doc_type: Optional[str] = None
    created_at: Optional[str]
    updated_at: Optional[str]
    similarity_score: Optional[float] = None
    index: Optional[int] = None


app = FastAPI(title="Document Search API")

# Add CORS middleware to allow the viewer to access the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local file access
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize document store once when server starts
print("Loading document store and model...")
document_store = DocumentStoreV2(load_model=True)
print("Model loaded and ready!")

# Initialize Anthropic client
anthropic_client = None
api_key = os.getenv("ANTHROPIC_API_KEY")
if api_key:
    anthropic_client = Anthropic(api_key=api_key)
    print("Claude API initialized!")
else:
    print("Warning: ANTHROPIC_API_KEY not found. Claude features will be disabled.")


@app.get("/")
def read_root():
    return {"message": "Document Search API is running"}


@app.post("/documents", response_model=DocumentResponse)
def add_document(doc: DocumentRequest):
    """Add a new document to the store"""
    doc_id = document_store.add_document(doc.title, doc.content, doc_type=doc.doc_type)
    # Fetch the created document
    documents = [d for d in document_store.get_all_documents() if d['id'] == doc_id]
    if documents:
        return DocumentResponse(**documents[0])
    raise HTTPException(status_code=500, detail="Failed to create document")


@app.post("/documents/import")
def import_documents(documents: List[DocumentRequest]):
    """Import multiple documents"""
    results = []
    for doc in documents:
        doc_id = document_store.add_document(doc.title, doc.content, doc_type=doc.doc_type)
        results.append({"id": doc_id, "title": doc.title})
    return {"imported": len(results), "documents": results}


@app.post("/search", response_model=List[DocumentResponse])
def search_documents(search: SearchRequest):
    """Search for documents using semantic similarity"""
    results = document_store.search(search.query, k=search.limit)
    return [DocumentResponse(**doc) for doc in results]


@app.get("/documents", response_model=List[DocumentResponse])
def list_documents():
    """List all documents in the store"""
    documents = document_store.get_all_documents()
    return [DocumentResponse(**doc) for doc in documents]


@app.get("/documents/by-index/{index}", response_model=DocumentResponse)
def get_document_by_index(index: int):
    """Get a document by its index (1-based)"""
    document = document_store.get_document_by_index(index)
    if document:
        return DocumentResponse(**document)
    raise HTTPException(status_code=404, detail=f"Document at index {index} not found")


@app.delete("/documents/{doc_id}")
def delete_document(doc_id: str):
    """Delete a document by ID"""
    if document_store.delete_document(doc_id):
        return {"message": f"Document {doc_id} deleted successfully"}
    raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")


@app.get("/stats")
def get_stats():
    """Get statistics about the document store"""
    return document_store.get_stats()


@app.delete("/documents/clear-all")
def clear_all_documents():
    """Clear all documents and embeddings from the store"""
    try:
        count = document_store.clear_all()
        return {"message": f"Successfully cleared {count} documents from the store"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/documents/{doc_id}/rename")
def rename_document(doc_id: str, request: RenameRequest):
    """Rename a document by ID"""
    if document_store.rename_document(doc_id, request.new_title):
        return {"message": f"Document {doc_id} renamed to: {request.new_title}"}
    raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")


@app.put("/documents/{doc_id}", response_model=DocumentResponse)
def update_document(doc_id: str, request: UpdateRequest):
    """Update a document's content and metadata"""
    if document_store.update_document(doc_id, request.title, request.content, request.doc_type):
        # Get the updated document
        documents = [d for d in document_store.get_all_documents() if d['id'] == doc_id]
        if documents:
            return DocumentResponse(**documents[0])
    raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")


@app.post("/claude", response_model=DocumentResponse)
def ask_claude(request: ClaudeRequest):
    """Send a prompt to Claude and save the response as a document"""
    if not anthropic_client:
        raise HTTPException(status_code=503, detail="Claude API not configured. Set ANTHROPIC_API_KEY environment variable.")
    
    try:
        # Call Claude API
        message = anthropic_client.messages.create(
            model="claude-3-haiku-20240307",  # Using Haiku for faster responses
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            messages=[
                {"role": "user", "content": request.prompt}
            ]
        )
        
        # Extract the response content
        response_content = message.content[0].text
        
        # Create a title from the first line or first 50 chars of the prompt
        title = request.prompt.split('\n')[0][:50]
        if len(title) == 50 and len(request.prompt) > 50:
            title += "..."
        
        # Create a document with the prompt and response
        doc_content = f"## Prompt\n\n{request.prompt}\n\n## Claude's Response\n\n{response_content}"
        
        # Add to document store
        doc_id = document_store.add_document(
            title=f"Claude: {title}",
            content=doc_content,
            doc_type="claude-response"
        )
        
        # Get the created document
        documents = [d for d in document_store.get_all_documents() if d['id'] == doc_id]
        if documents:
            return DocumentResponse(**documents[0])
        
        raise HTTPException(status_code=500, detail="Failed to save Claude response")
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Claude API error: {str(e)}")


if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8001
    print(f"Starting server on port {port}...")
    uvicorn.run(app, host="0.0.0.0", port=port)