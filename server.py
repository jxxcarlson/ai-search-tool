from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uvicorn
import os
from anthropic import Anthropic
from datetime import datetime
import numpy as np
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
import time
from collections import defaultdict
import PyPDF2
import io
import shutil
import platform
import subprocess
from pdf2image import convert_from_path
from PIL import Image
import json

from document_store_v2_optimized import DocumentStoreV2Optimized as DocumentStoreV2


class DocumentRequest(BaseModel):
    title: str
    content: str
    doc_type: Optional[str] = None
    tags: Optional[str] = None  # Comma-separated tags


class RenameRequest(BaseModel):
    new_title: str


class UpdateRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    doc_type: Optional[str] = None
    tags: Optional[str] = None  # Comma-separated tags


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
    naming_method: Optional[str] = "v5"  # "v1", "v2", "v3", "v4", or "v5", defaults to v5


class ClusterResponse(BaseModel):
    clusters: List[Dict[str, Any]]
    num_clusters: int
    silhouette_score: float
    total_documents: int


class OpenPDFRequest(BaseModel):
    filename: str


class DocumentResponse(BaseModel):
    id: str
    title: str
    content: str
    doc_type: Optional[str] = None
    tags: Optional[str] = None
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
    doc_id = document_store.add_document(doc.title, doc.content, doc_type=doc.doc_type, tags=doc.tags)
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
        doc_id = document_store.add_document(doc.title, doc.content, doc_type=doc.doc_type, tags=doc.tags)
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
    if document_store.update_document(doc_id, request.title, request.content, request.doc_type, request.tags):
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
            title=title,
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


def generate_pdf_thumbnails(pdf_path: str, thumbnail_dir: str, filename_base: str, max_pages: int = 10) -> List[str]:
    """Generate thumbnail images for PDF pages"""
    try:
        # Try to import and use pdf2image
        from pdf2image import convert_from_path
        from pdf2image.exceptions import PDFInfoNotInstalledError, PDFPageCountError, PDFSyntaxError
        
        try:
            # Convert PDF pages to images
            images = convert_from_path(pdf_path, dpi=72, first_page=1, last_page=max_pages)
            
            thumbnail_paths = []
            for i, image in enumerate(images):
                # Create thumbnail (max width/height of 200px)
                thumbnail = image.copy()
                thumbnail.thumbnail((200, 200), Image.Resampling.LANCZOS)
                
                # Save thumbnail
                thumb_filename = f"{filename_base}_page_{i+1}.jpg"
                thumb_path = os.path.join(thumbnail_dir, thumb_filename)
                thumbnail.save(thumb_path, "JPEG", quality=85)
                thumbnail_paths.append(thumb_filename)
                
            return thumbnail_paths
        except (PDFInfoNotInstalledError, PDFPageCountError) as e:
            print(f"Poppler not installed or PDF error. Thumbnail generation skipped: {e}")
            return []
    except ImportError:
        print("pdf2image not installed. Thumbnail generation skipped.")
        return []
    except Exception as e:
        print(f"Error generating thumbnails: {e}")
        return []


@app.post("/upload-pdf", response_model=DocumentResponse)
async def upload_pdf(file: UploadFile = File(...)):
    """Upload a PDF file and extract its text for indexing"""
    # Validate file type
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed")
    
    try:
        # Read PDF content
        pdf_content = await file.read()
        
        # Extract text from PDF
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_content))
        text_content = ""
        num_pages = len(pdf_reader.pages)
        
        for page_num in range(num_pages):
            page = pdf_reader.pages[page_num]
            text_content += page.extract_text() + "\n\n"
        
        # Clean up the text
        text_content = text_content.strip()
        
        if not text_content:
            raise HTTPException(status_code=400, detail="Could not extract text from PDF")
        
        # Generate a unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_filename = f"{timestamp}_{file.filename}"
        pdf_path = f"storage/pdfs/{safe_filename}"
        
        # Save the original PDF
        with open(pdf_path, "wb") as pdf_file:
            pdf_file.write(pdf_content)
        
        # Generate thumbnails
        thumbnail_dir = "storage/pdf_thumbnails"
        os.makedirs(thumbnail_dir, exist_ok=True)
        filename_base = safe_filename.rsplit('.', 1)[0]
        thumbnail_paths = generate_pdf_thumbnails(pdf_path, thumbnail_dir, filename_base)
        
        # Create document with extracted text
        doc_id = document_store.add_document(
            title=file.filename,
            content=text_content,
            doc_type="pdf"
        )
        
        # Store the PDF path and metadata in the document content
        metadata = {
            "filename": safe_filename,
            "pages": num_pages,
            "thumbnails": thumbnail_paths
        }
        updated_content = f"[PDF_FILE:{safe_filename}]\n[PDF_META:{json.dumps(metadata)}]\n\n{text_content}"
        document_store.update_document(doc_id, content=updated_content)
        
        # Get the created document
        documents = [d for d in document_store.get_all_documents() if d['id'] == doc_id]
        if documents:
            return DocumentResponse(**documents[0])
        
        raise HTTPException(status_code=500, detail="Failed to save PDF document")
        
    except PyPDF2.errors.PdfReadError as e:
        raise HTTPException(status_code=400, detail=f"Invalid or corrupted PDF file: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing PDF: {str(e)}")


@app.get("/pdf/{filename}")
async def get_pdf(filename: str):
    """Serve a PDF file for viewing"""
    pdf_path = f"storage/pdfs/{filename}"
    
    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="PDF not found")
    
    return FileResponse(
        path=pdf_path,
        media_type="application/pdf",
        filename=filename,
        headers={
            "Content-Disposition": f"inline; filename={filename}",
            "X-Content-Type-Options": "nosniff"
        }
    )


@app.get("/pdf/thumbnail/{filename}")
async def get_pdf_thumbnail(filename: str):
    """Serve a PDF thumbnail image"""
    thumb_path = f"storage/pdf_thumbnails/{filename}"
    
    if not os.path.exists(thumb_path):
        raise HTTPException(status_code=404, detail="Thumbnail not found")
    
    return FileResponse(
        path=thumb_path,
        media_type="image/jpeg",
        headers={
            "Cache-Control": "public, max-age=3600"
        }
    )


@app.get("/pdf/thumbnails/{pdf_filename}")
async def get_pdf_thumbnails(pdf_filename: str):
    """Get list of thumbnails for a PDF"""
    # Extract base filename
    base_name = pdf_filename.rsplit('.', 1)[0]
    thumbnail_dir = "storage/pdf_thumbnails"
    
    thumbnails = []
    if os.path.exists(thumbnail_dir):
        for file in os.listdir(thumbnail_dir):
            if file.startswith(base_name) and file.endswith('.jpg'):
                thumbnails.append(file)
    
    thumbnails.sort()  # Sort by page number
    return {"thumbnails": thumbnails}


@app.post("/open-pdf-native")
async def open_pdf_native(request: OpenPDFRequest):
    """Open a PDF file in the system's native PDF viewer"""
    pdf_path = f"storage/pdfs/{request.filename}"
    
    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="PDF not found")
    
    try:
        system = platform.system()
        
        if system == "Darwin":  # macOS
            subprocess.run(["open", pdf_path], check=True)
        elif system == "Windows":
            os.startfile(pdf_path)
        elif system == "Linux":
            # Try xdg-open first (works on most desktop environments)
            try:
                subprocess.run(["xdg-open", pdf_path], check=True)
            except:
                # Fallback to other common PDF viewers
                for viewer in ["evince", "okular", "firefox", "chromium"]:
                    try:
                        subprocess.run([viewer, pdf_path], check=True)
                        break
                    except:
                        continue
                else:
                    raise Exception("No PDF viewer found")
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported OS: {system}")
        
        return {"message": f"Opening PDF in {system} native viewer", "filename": request.filename}
        
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Failed to open PDF: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error opening PDF: {str(e)}")


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
        'document', 'documents', 'file', 'files'
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
        # Get document title
        title = doc['title']
        
        # Remove punctuation and split into words
        words = re.findall(r'\b[a-zA-Z]+\b', title.lower())
        # Filter out stop words and short words
        for word in words:
            if len(word) > 2 and word not in stop_words and word.lower() != 'claude':
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


def generate_cluster_name_v5(documents, doc_store, representative_id):
    """
    Use common tags if available, otherwise fall back to representative title.
    Prioritizes tags that appear in all or most documents in the cluster.
    """
    # Extract tags from all documents
    all_tags = []
    for doc in documents:
        tags_str = doc.get('tags', '')
        if tags_str:
            # Split and clean tags
            doc_tags = [tag.strip().lower() for tag in tags_str.split(',') if tag.strip()]
            all_tags.extend(doc_tags)
    
    if all_tags:
        # Count tag frequency
        from collections import Counter
        tag_counter = Counter(all_tags)
        total_docs = len(documents)
        
        # Find tags that appear in all or most documents
        common_tags = []
        for tag, count in tag_counter.most_common():
            # If a tag appears in at least 80% of documents, consider it common
            if count >= total_docs * 0.8:
                common_tags.append(tag)
        
        if common_tags:
            # Use up to 3 most common tags, capitalize properly
            selected_tags = common_tags[:3]
            formatted_tags = [tag.title() for tag in selected_tags]
            return " + ".join(formatted_tags)
    
    # Fallback to v4 behavior (representative title)
    return generate_cluster_name_v4(documents, doc_store, representative_id)


def generate_cluster_name_v4(documents, doc_store, representative_id):
    """
    Simply use the representative document's title as the cluster name.
    This is the simplest and often most effective approach.
    """
    # Find the representative document
    for doc in documents:
        if doc['id'] == representative_id:
            return doc.get('title', 'Untitled')
    
    # Fallback if we can't find the representative
    return "Unnamed Cluster"


def generate_cluster_name_v3(documents, doc_store, representative_id):
    """
    Extract a meaningful phrase from the representative document.
    Returns a descriptive phrase that captures the essence of the cluster.
    """
    import re
    
    # Find the representative document
    representative_doc = None
    for doc in documents:
        if doc['id'] == representative_id:
            representative_doc = doc
            break
    
    if not representative_doc:
        # Fallback if we can't find the representative
        return generate_cluster_name_v2(documents, doc_store)
    
    content = representative_doc.get('content', '')
    
    # Try to find meaningful phrases in order of preference
    
    # 1. Look for a section heading (## or ###)
    section_headings = re.findall(r'^#{2,3}\s+(.+)$', content, re.MULTILINE)
    if section_headings:
        # Use the first section heading, clean it up
        heading = section_headings[0].strip()
        if 10 <= len(heading) <= 50:  # Reasonable length
            return heading
    
    # 2. Look for a strong statement (ending with period, not too long)
    sentences = re.split(r'[.!?]\s+', content)
    for sentence in sentences[:10]:  # Check first 10 sentences
        sentence = sentence.strip()
        # Skip very short or very long sentences
        if 20 <= len(sentence) <= 60:
            # Skip sentences that are questions or contain certain words
            if not any(word in sentence.lower() for word in ['?', 'this', 'these', 'that', 'those', 'here', 'there']):
                # Prefer sentences with key verbs or concepts
                if any(word in sentence.lower() for word in ['is', 'are', 'defines', 'creates', 'provides', 'explains', 'shows', 'demonstrates']):
                    return sentence
    
    # 3. Extract key noun phrases from the beginning
    # Look for pattern: "The/A [adjective]* noun [preposition phrase]"
    noun_phrases = re.findall(r'\b(?:The|A|An)\s+(?:\w+\s+){0,2}\w+\s+(?:of|for|in|with|about)\s+\w+', content[:500])
    if noun_phrases:
        phrase = noun_phrases[0]
        if 15 <= len(phrase) <= 50:
            return phrase
    
    # 4. Use the title if it's descriptive enough
    title = representative_doc.get('title', '')
    if title and 15 <= len(title) <= 50 and not title.lower().startswith('untitled'):
        return title
    
    # 5. Fallback: Use first meaningful chunk of content
    # Remove markdown formatting
    clean_content = re.sub(r'[#*`\[\]()]', '', content[:200])
    clean_content = re.sub(r'\s+', ' ', clean_content).strip()
    
    if len(clean_content) > 30:
        # Find a good breaking point
        for i in range(min(50, len(clean_content)), 20, -1):
            if clean_content[i] in ' ,:;-':
                return clean_content[:i].strip() + "..."
    
    # Last resort: Use v2 algorithm
    return generate_cluster_name_v2(documents, doc_store)


def generate_cluster_name_v2(documents, doc_store):
    """
    Enhanced cluster naming that analyzes document content in addition to titles.
    Returns a more descriptive name based on content analysis.
    """
    import re
    from collections import Counter
    import math
    
    # Common stop words to filter out
    stop_words = {
        'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
        'of', 'with', 'by', 'from', 'is', 'was', 'are', 'were', 'been', 'be',
        'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should',
        'could', 'may', 'might', 'must', 'shall', 'can', 'need', 'ought',
        'i', 'you', 'he', 'she', 'it', 'we', 'they', 'them', 'their', 'this',
        'that', 'these', 'those', 'which', 'what', 'when', 'where', 'why', 'how',
        'not', 'no', 'yes', 'all', 'some', 'any', 'each', 'every', 'either',
        'neither', 'both', 'more', 'most', 'less', 'least', 'many', 'much',
        'few', 'several', 'such', 'own', 'same', 'other', 'another', 'next',
        'as', 'than', 'if', 'then', 'else', 'so', 'therefore', 'however',
        'because', 'since', 'although', 'though', 'unless', 'until', 'while',
        'after', 'before', 'during', 'through', 'about', 'above', 'below',
        'between', 'into', 'out', 'up', 'down', 'over', 'under', 'again',
        'also', 'just', 'only', 'very', 'too', 'quite', 'rather', 'really',
        'still', 'even', 'yet', 'already', 'here', 'there', 'now', 'then',
        'today', 'tomorrow', 'yesterday', 'always', 'never', 'sometimes',
        'often', 'usually', 'generally', 'specifically', 'particularly',
        'doc', 'document', 'new', 'edit', 'untitled', 'test', 'one', 'two',
        'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'
    }
    
    # Get full documents with content - they already have content in them
    full_docs = documents[:5]  # Analyze up to 5 representative documents
    
    if not full_docs:
        return generate_cluster_name(documents)  # Fallback to v1
    
    # Collect all words from titles and content
    word_freq = Counter()
    doc_word_count = defaultdict(set)  # Track which docs contain each word
    
    for doc in full_docs:
        # Process title
        title_words = re.findall(r'\b[a-zA-Z]+\b', doc['title'].lower())
        content_words = re.findall(r'\b[a-zA-Z]+\b', doc.get('content', '').lower())[:500]  # First 500 words
        
        # Combine and filter
        all_doc_words = set(title_words + content_words)
        meaningful_words = {w for w in all_doc_words if len(w) > 3 and w not in stop_words}
        
        # Add to frequency counter with boost for title words
        for word in meaningful_words:
            if word in title_words:
                word_freq[word] += 3  # Boost title words
            else:
                word_freq[word] += 1
            doc_word_count[word].add(doc['id'])
    
    # Calculate scores emphasizing words that appear in more documents
    total_docs = len(full_docs)
    word_scores = {}
    
    for word, freq in word_freq.items():
        # How many documents contain this word
        doc_frequency = len(doc_word_count[word])
        doc_coverage = doc_frequency / total_docs
        
        # Base score from frequency
        score = freq
        
        # Strong bonus for words that appear in multiple documents
        if doc_coverage >= 0.8:  # Word appears in 80%+ of docs
            score *= 3.0  # Triple the score
        elif doc_coverage >= 0.6:  # Word appears in 60-80% of docs
            score *= 2.0  # Double the score
        elif doc_coverage >= 0.4:  # Word appears in 40-60% of docs
            score *= 1.5
        else:  # Word appears in fewer than 40% of docs
            score *= 0.5  # Penalize rare words
            
        # Additional boost for perfect coverage (appears in all docs)
        if doc_frequency == total_docs:
            score *= 1.2
            
        word_scores[word] = score
    
    # Get top scoring words
    top_words = sorted(word_scores.items(), key=lambda x: x[1], reverse=True)[:10]
    
    # Build cluster name from top distinctive words
    name_parts = []
    used_concepts = set()
    
    for word, score in top_words:
        # Skip if too similar to already used words
        if any(word[:4] == used[:4] for used in used_concepts):
            continue
            
        name_parts.append(word.capitalize())
        used_concepts.add(word)
        
        if len(name_parts) >= 3:
            break
    
    if len(name_parts) >= 2:
        return " ".join(name_parts)
    elif name_parts:
        return name_parts[0] + " Group"
    else:
        return generate_cluster_name(documents)  # Fallback to v1


# Timing statistics storage
cluster_naming_stats = {
    'v1_times': [],
    'v2_times': [],
    'v1_total': 0,
    'v2_total': 0,
    'v1_count': 0,
    'v2_count': 0
}


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
        
        # Clean embeddings to handle numerical issues
        # Replace NaN/inf with 0
        embeddings = np.nan_to_num(embeddings, nan=0.0, posinf=0.0, neginf=0.0)
        
        # Normalize embeddings to prevent numerical overflow
        norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
        norms[norms == 0] = 1  # Avoid division by zero
        embeddings = embeddings / norms
        
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
                    cluster_docs.append(doc_info)  # Keep full document info
            
            # Calculate cluster center and find nearest document as representative
            cluster_center = kmeans.cluster_centers_[i]
            cluster_embeddings = embeddings[cluster_indices]
            distances = np.linalg.norm(cluster_embeddings - cluster_center, axis=1)
            representative_idx = cluster_indices[np.argmin(distances)]
            representative_id = doc_ids[representative_idx]
            
            # Generate cluster name based on documents with timing
            if request.naming_method == "v1":
                start_time = time.time()
                cluster_name = generate_cluster_name(cluster_docs)
                elapsed = time.time() - start_time
                cluster_naming_stats['v1_times'].append(elapsed)
                cluster_naming_stats['v1_total'] += elapsed
                cluster_naming_stats['v1_count'] += 1
            elif request.naming_method == "v2":
                start_time = time.time()
                cluster_name = generate_cluster_name_v2(cluster_docs, document_store)
                elapsed = time.time() - start_time
                cluster_naming_stats['v2_times'].append(elapsed)
                cluster_naming_stats['v2_total'] += elapsed
                cluster_naming_stats['v2_count'] += 1
            elif request.naming_method == "v3":
                start_time = time.time()
                cluster_name = generate_cluster_name_v3(cluster_docs, document_store, representative_id)
                elapsed = time.time() - start_time
                # Store v3 stats in v2 slots for now (we can add v3_times later if needed)
                cluster_naming_stats['v2_times'].append(elapsed)
                cluster_naming_stats['v2_total'] += elapsed
                cluster_naming_stats['v2_count'] += 1
            elif request.naming_method == "v4":
                start_time = time.time()
                cluster_name = generate_cluster_name_v4(cluster_docs, document_store, representative_id)
                elapsed = time.time() - start_time
                # Store v4 stats in v2 slots for now
                cluster_naming_stats['v2_times'].append(elapsed)
                cluster_naming_stats['v2_total'] += elapsed
                cluster_naming_stats['v2_count'] += 1
            else:  # v5 (default)
                start_time = time.time()
                cluster_name = generate_cluster_name_v5(cluster_docs, document_store, representative_id)
                elapsed = time.time() - start_time
                # Store v5 stats in v2 slots for now
                cluster_naming_stats['v2_times'].append(elapsed)
                cluster_naming_stats['v2_total'] += elapsed
                cluster_naming_stats['v2_count'] += 1
            
            # Create metadata-only version for response
            cluster_docs_metadata = [{
                'id': doc['id'],
                'title': doc['title'],
                'doc_type': doc.get('doc_type'),
                'created_at': doc.get('created_at')
            } for doc in cluster_docs]
            
            clusters.append({
                'cluster_id': i,
                'cluster_name': cluster_name,
                'size': len(cluster_docs),
                'documents': cluster_docs_metadata,
                'representative_document_id': representative_id
            })
        
        return ClusterResponse(
            clusters=clusters,
            num_clusters=num_clusters,
            silhouette_score=float(final_score),
            total_documents=len(documents)
        )
        
    except Exception as e:
        import traceback
        print(f"Clustering error: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Clustering error: {str(e)}")


@app.get("/cluster-naming-stats")
def get_cluster_naming_stats():
    """Get statistics about cluster naming performance"""
    stats = {
        'v1': {
            'total_time': cluster_naming_stats['v1_total'],
            'count': cluster_naming_stats['v1_count'],
            'average_time': cluster_naming_stats['v1_total'] / cluster_naming_stats['v1_count'] if cluster_naming_stats['v1_count'] > 0 else 0,
            'recent_times': cluster_naming_stats['v1_times'][-10:]  # Last 10 times
        },
        'v2': {
            'total_time': cluster_naming_stats['v2_total'],
            'count': cluster_naming_stats['v2_count'],
            'average_time': cluster_naming_stats['v2_total'] / cluster_naming_stats['v2_count'] if cluster_naming_stats['v2_count'] > 0 else 0,
            'recent_times': cluster_naming_stats['v2_times'][-10:]  # Last 10 times
        },
        'comparison': {
            'v2_vs_v1_ratio': (cluster_naming_stats['v2_total'] / cluster_naming_stats['v2_count']) / (cluster_naming_stats['v1_total'] / cluster_naming_stats['v1_count']) if cluster_naming_stats['v1_count'] > 0 and cluster_naming_stats['v2_count'] > 0 else None
        }
    }
    return stats


if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8001
    print(f"Starting server on port {port}...")
    uvicorn.run(app, host="0.0.0.0", port=port)