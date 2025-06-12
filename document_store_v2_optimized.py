import os
from typing import List, Dict, Optional
from datetime import datetime
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from sqlalchemy.orm import Session

from models import Document, get_engine, get_session


class DocumentStoreV2Optimized:
    def __init__(self, storage_dir: str = "storage", load_model: bool = False):
        self.storage_dir = storage_dir
        os.makedirs(storage_dir, exist_ok=True)
        
        # Initialize SQLite
        self.engine = get_engine(os.path.join(storage_dir, 'documents.db'))
        
        # Initialize ChromaDB
        self.chroma_client = chromadb.PersistentClient(
            path=os.path.join(storage_dir, 'chroma_db'),
            settings=Settings(anonymized_telemetry=False)
        )
        
        # Get or create collection
        self.collection = self.chroma_client.get_or_create_collection(
            name="documents",
            metadata={"hnsw:space": "cosine"}
        )
        
        # Only load model if needed
        self.model = None
        self.embedding_dim = 384
        if load_model:
            self._load_model()
    
    def _load_model(self):
        """Lazy load the sentence transformer model"""
        if self.model is None:
            self.model = SentenceTransformer('all-MiniLM-L6-v2')
    
    def add_document(self, title: str, content: str, doc_type: Optional[str] = None) -> str:
        """Add a new document to the store"""
        # Ensure model is loaded for embedding generation
        self._load_model()
        
        session = get_session(self.engine)
        
        try:
            # Generate document ID
            doc_id = f"doc_{self.collection.count() + 1}_{int(datetime.now().timestamp())}"
            
            # Create document in SQLite
            document = Document(
                id=doc_id,
                title=title,
                content=content,
                doc_type=doc_type
            )
            session.add(document)
            
            # Generate embedding
            embedding = self.model.encode(content).tolist()
            
            # Add to ChromaDB with metadata
            self.collection.add(
                ids=[doc_id],
                embeddings=[embedding],
                metadatas=[{
                    "title": title,
                    "created_at": datetime.now().isoformat()
                }]
            )
            
            session.commit()
            return doc_id
            
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()
    
    def search(self, query: str, k: int = 5) -> List[Dict]:
        """Search for documents using semantic similarity"""
        if self.collection.count() == 0:
            return []
        
        # Ensure model is loaded for query embedding
        self._load_model()
        
        # Generate query embedding
        query_embedding = self.model.encode(query).tolist()
        
        # Search in ChromaDB
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=min(k, self.collection.count())
        )
        
        # Get full documents from SQLite
        session = get_session(self.engine)
        search_results = []
        
        try:
            for idx, doc_id in enumerate(results['ids'][0]):
                document = session.query(Document).filter_by(id=doc_id).first()
                if document:
                    result = document.to_dict()
                    # Add similarity score (convert distance to similarity)
                    result['similarity_score'] = 1 - results['distances'][0][idx]
                    search_results.append(result)
            
            return search_results
            
        finally:
            session.close()
    
    def get_all_documents(self) -> List[Dict]:
        """Get all documents from the store - no model needed"""
        session = get_session(self.engine)
        try:
            documents = session.query(Document).all()
            return [doc.to_dict() for doc in documents]
        finally:
            session.close()
    
    def get_document_by_index(self, index: int) -> Optional[Dict]:
        """Get document by index (1-based) - no model needed"""
        session = get_session(self.engine)
        try:
            # Get all documents ordered by created_at to ensure consistent ordering
            documents = session.query(Document).order_by(Document.created_at).all()
            
            # Convert to 0-based index
            if 1 <= index <= len(documents):
                return documents[index - 1].to_dict()
            return None
        finally:
            session.close()
    
    def delete_document(self, doc_id: str) -> bool:
        """Delete a document by ID - no model needed"""
        session = get_session(self.engine)
        
        try:
            # Delete from SQLite
            document = session.query(Document).filter_by(id=doc_id).first()
            if not document:
                return False
            
            session.delete(document)
            
            # Delete from ChromaDB
            self.collection.delete(ids=[doc_id])
            
            session.commit()
            return True
            
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()
    
    def get_stats(self) -> Dict:
        """Get statistics about the document store - no model needed"""
        session = get_session(self.engine)
        try:
            doc_count = session.query(Document).count()
            return {
                'total_documents': doc_count,
                'embedding_dimension': self.embedding_dim,
                'model': 'all-MiniLM-L6-v2',
                'storage_location': self.storage_dir,
                'chroma_collection_count': self.collection.count()
            }
        finally:
            session.close()
    
    def clear_all(self) -> int:
        """Clear all documents and embeddings from the store"""
        session = get_session(self.engine)
        try:
            # Count documents before deletion
            count = session.query(Document).count()
            
            # Delete all documents from SQLite
            session.query(Document).delete()
            session.commit()
            
            # Clear ChromaDB collection
            # Delete and recreate the collection to ensure it's empty
            self.chroma_client.delete_collection(name="documents")
            self.collection = self.chroma_client.create_collection(
                name="documents",
                metadata={"hnsw:space": "cosine"}
            )
            
            return count
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()