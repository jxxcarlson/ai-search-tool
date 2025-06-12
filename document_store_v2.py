import os
from typing import List, Dict, Optional
from datetime import datetime
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from sqlalchemy.orm import Session

from models import Document, get_engine, get_session


class DocumentStoreV2:
    def __init__(self, storage_dir: str = "storage"):
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
        
        # Initialize sentence transformer
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
        self.embedding_dim = 384
    
    def add_document(self, title: str, content: str) -> str:
        """Add a new document to the store"""
        session = get_session(self.engine)
        
        try:
            # Generate document ID
            doc_id = f"doc_{self.collection.count() + 1}_{int(datetime.now().timestamp())}"
            
            # Create document in SQLite
            document = Document(
                id=doc_id,
                title=title,
                content=content
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
        """Get all documents from the store"""
        session = get_session(self.engine)
        try:
            documents = session.query(Document).all()
            return [doc.to_dict() for doc in documents]
        finally:
            session.close()
    
    def delete_document(self, doc_id: str) -> bool:
        """Delete a document by ID"""
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
        """Get statistics about the document store"""
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