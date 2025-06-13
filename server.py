from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uvicorn
import os
from anthropic import Anthropic
from datetime import datetime
import numpy as np
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

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


class ClusterRequest(BaseModel):
    num_clusters: Optional[int] = None  # If None, will use silhouette score to find optimal
    min_clusters: Optional[int] = 2
    max_clusters: Optional[int] = 10


class ClusterResponse(BaseModel):
    clusters: List[Dict[str, Any]]
    num_clusters: int
    silhouette_score: float
    total_documents: int


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


def generate_cluster_name(documents: List[dict]) -> str:
    """Generate a descriptive name for a cluster based on document titles"""
    if not documents:
        return "Empty Cluster"
    
    # Comprehensive list of stop words including low-information words
    stop_words = {
        # Articles and determiners
        'the', 'a', 'an', 'this', 'that', 'these', 'those', 'my', 'your', 'his', 'her', 
        'its', 'our', 'their', 'all', 'both', 'each', 'every', 'any', 'some', 'few', 'many',
        
        # Pronouns
        'i', 'me', 'we', 'us', 'you', 'he', 'him', 'she', 'it', 'they', 'them',
        'who', 'whom', 'whose', 'which', 'what', 'where', 'when', 'why', 'how',
        
        # Prepositions and conjunctions
        'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'up', 'down', 'out',
        'off', 'over', 'under', 'about', 'into', 'through', 'during', 'before', 'after',
        'above', 'below', 'between', 'among', 'and', 'or', 'but', 'if', 'then', 'because',
        'as', 'until', 'while', 'since', 'unless', 'although', 'though', 'whether',
        
        # Auxiliary verbs and common verbs
        'is', 'are', 'was', 'were', 'been', 'be', 'being', 'have', 'has', 'had', 'having',
        'do', 'does', 'did', 'doing', 'done', 'will', 'would', 'shall', 'should', 'could',
        'may', 'might', 'must', 'can', 'cannot', 'could', 'should', 'would',
        'get', 'got', 'getting', 'gets', 'make', 'made', 'making', 'makes',
        
        # Common adverbs and other low-information words
        'not', 'no', 'nor', 'yes', 'very', 'just', 'only', 'well', 'even', 'also', 'too',
        'so', 'now', 'then', 'here', 'there', 'where', 'when', 'why', 'how', 'what',
        'more', 'most', 'less', 'least', 'much', 'many', 'few', 'little', 'very',
        'new', 'old', 'good', 'bad', 'great', 'small', 'large', 'big',
        
        # Numbers and common words specific to this app
        'one', 'two', 'three', 'four', 'five', 'first', 'second', 'third',
        'claude:', 'claude', 'document', 'documents', 'file', 'files'
    }
    
    # Simple stemming function to group similar words
    def simple_stem(word):
        """Simple stemming to group plural/singular forms"""
        word = word.lower()
        # Common suffixes to remove
        if word.endswith('ies') and len(word) > 4:
            return word[:-3] + 'y'
        elif word.endswith('es') and len(word) > 3:
            if word.endswith('ses') or word.endswith('xes') or word.endswith('zes'):
                return word[:-2]
            else:
                return word[:-2]
        elif word.endswith('s') and len(word) > 3 and not word.endswith('ss'):
            return word[:-1]
        elif word.endswith('ing') and len(word) > 5:
            return word[:-3]
        elif word.endswith('ed') and len(word) > 4:
            return word[:-2]
        elif word.endswith('er') and len(word) > 4:
            return word[:-2]
        elif word.endswith('est') and len(word) > 5:
            return word[:-3]
        return word
    
    # Get all words from titles
    all_words = []
    word_to_original = {}  # Map stems to most common original form
    
    for doc in documents:
        # Split title into words, handle punctuation
        import re
        # Remove punctuation and split into words
        words = re.findall(r'\b[a-zA-Z]+\b', doc['title'].lower())
        # Filter out stop words and short words
        for word in words:
            if len(word) > 2 and word not in stop_words:
                stem = simple_stem(word)
                all_words.append(stem)
                # Keep track of original forms
                if stem not in word_to_original:
                    word_to_original[stem] = word
                elif len(word) < len(word_to_original[stem]):
                    # Prefer shorter form (usually singular)
                    word_to_original[stem] = word
    
    # Count word frequencies by stem
    from collections import Counter
    word_counts = Counter(all_words)
    
    # Get the most common meaningful words
    if word_counts:
        # Get more candidates to ensure we have enough after filtering
        most_common = word_counts.most_common(10)
        
        # Use the most common words to create a name, avoiding repetition
        name_parts = []
        used_stems = set()
        
        for stem, count in most_common:
            # Check if we should use this word
            if stem not in used_stems:
                # Only include words that appear in multiple documents or are very distinctive
                if count > 1 or len(documents) <= 2:
                    # Use the preferred original form
                    original = word_to_original.get(stem, stem)
                    name_parts.append(original.capitalize())
                    used_stems.add(stem)
                
                # Stop when we have 2-3 good words
                if len(name_parts) >= 3:
                    break
        
        # If we have at least 2 good words, use them
        if len(name_parts) >= 2:
            return " ".join(name_parts[:3])  # Limit to 3 words max
        elif name_parts:
            # If we only have one word, try to add more context
            return name_parts[0]
    
    # Fallback: use first few meaningful words from the first document
    first_title = documents[0]['title']
    words = re.findall(r'\b[a-zA-Z]+\b', first_title)
    filtered = [w for w in words if len(w) > 2 and w.lower() not in stop_words]
    
    if filtered:
        return " ".join(filtered[:3])
    else:
        # Last resort: just use the first part of the title
        return first_title.split()[:4][-1] if first_title else "Unnamed"


@app.post("/clusters", response_model=ClusterResponse)
def get_document_clusters(request: ClusterRequest):
    """Cluster documents based on their semantic embeddings"""
    # Get all documents with their embeddings
    documents = document_store.get_all_documents()
    
    if len(documents) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 documents to perform clustering")
    
    # Get embeddings from ChromaDB
    try:
        # Get the collection from ChromaDB
        collection = document_store.collection
        
        # Get all embeddings
        all_data = collection.get(include=['embeddings', 'metadatas', 'documents'])
        embeddings = np.array(all_data['embeddings'])
        doc_ids = all_data['ids']
        
        if len(embeddings) < 2:
            raise HTTPException(status_code=400, detail="Not enough documents with embeddings")
        
        # Determine optimal number of clusters if not specified
        if request.num_clusters is None:
            best_score = -1
            best_k = 2
            
            # Try different numbers of clusters
            for k in range(request.min_clusters, min(request.max_clusters + 1, len(embeddings))):
                kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
                labels = kmeans.fit_predict(embeddings)
                
                # Calculate silhouette score
                if k < len(embeddings):
                    score = silhouette_score(embeddings, labels)
                    if score > best_score:
                        best_score = score
                        best_k = k
            
            num_clusters = best_k
        else:
            num_clusters = min(request.num_clusters, len(embeddings) - 1)
        
        # Perform final clustering
        kmeans = KMeans(n_clusters=num_clusters, random_state=42, n_init=10)
        labels = kmeans.fit_predict(embeddings)
        final_score = silhouette_score(embeddings, labels)
        
        # Organize documents by cluster
        clusters = []
        for i in range(num_clusters):
            cluster_docs = []
            cluster_indices = np.where(labels == i)[0]
            
            for idx in cluster_indices:
                doc_id = doc_ids[idx]
                # Find the document info
                doc_info = next((d for d in documents if d['id'] == doc_id), None)
                if doc_info:
                    cluster_docs.append({
                        'id': doc_info['id'],
                        'title': doc_info['title'],
                        'doc_type': doc_info.get('doc_type'),
                        'created_at': doc_info.get('created_at')
                    })
            
            # Calculate cluster center and find nearest document as representative
            cluster_center = kmeans.cluster_centers_[i]
            cluster_embeddings = embeddings[cluster_indices]
            distances = np.linalg.norm(cluster_embeddings - cluster_center, axis=1)
            representative_idx = cluster_indices[np.argmin(distances)]
            representative_id = doc_ids[representative_idx]
            
            # Generate cluster name based on documents
            cluster_name = generate_cluster_name(cluster_docs)
            
            clusters.append({
                'cluster_id': i,
                'cluster_name': cluster_name,
                'size': len(cluster_docs),
                'documents': cluster_docs,
                'representative_document_id': representative_id
            })
        
        return ClusterResponse(
            clusters=clusters,
            num_clusters=num_clusters,
            silhouette_score=float(final_score),
            total_documents=len(documents)
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Clustering error: {str(e)}")


if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8001
    print(f"Starting server on port {port}...")
    uvicorn.run(app, host="0.0.0.0", port=port)