import os
from typing import List, Dict, Optional
from datetime import datetime
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from sqlalchemy.orm import Session

from models import Document, get_engine, get_session
from database_manager import get_database_manager
import config


class DocumentStoreV2Optimized:
    def __init__(self, storage_dir: str = None, load_model: bool = False, database_id: str = None):
        # Get database manager
        self.db_manager = get_database_manager()
        
        # If database_id provided, switch to it
        if database_id:
            self.db_manager.switch_database(database_id)
        
        # Get current database info
        current_db = self.db_manager.get_current_database()
        
        # Set config paths for current database
        config.set_database_paths(current_db.id)
        
        # Use database-specific storage directory
        self.storage_dir = str(self.db_manager.get_database_path())
        
        # Initialize SQLite
        self.engine = get_engine(str(config.DATABASE_PATH))
        
        # Initialize ChromaDB
        self.chroma_client = chromadb.PersistentClient(
            path=str(config.CHROMA_DB_DIR),
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
            # Try to load with local_files_only first to avoid network issues
            try:
                self.model = SentenceTransformer('all-MiniLM-L12-v2', local_files_only=True)
            except:
                # If that fails, try normal loading (will download if needed)
                self.model = SentenceTransformer('all-MiniLM-L12-v2')
    
    def add_document(self, title: str, content: str, doc_type: Optional[str] = None, tags: Optional[str] = None, abstract: Optional[str] = None, abstract_source: Optional[str] = None, source: Optional[str] = None, authors: Optional[str] = None) -> str:
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
                doc_type=doc_type,
                tags=tags,
                abstract=abstract,
                abstract_source=abstract_source,
                source=source,
                authors=authors
            )
            session.add(document)
            
            # Generate embedding (only use content, not tags)
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
            
            # Update document count in database manager
            self.db_manager.update_document_count()
            
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
            # Get all documents ordered by created_at to find their index
            all_docs = session.query(Document).order_by(Document.created_at).all()
            doc_id_to_index = {doc.id: idx + 1 for idx, doc in enumerate(all_docs)}
            
            for idx, doc_id in enumerate(results['ids'][0]):
                document = session.query(Document).filter_by(id=doc_id).first()
                if document:
                    result = document.to_dict()
                    # Add similarity score (convert distance to similarity)
                    result['similarity_score'] = 1 - results['distances'][0][idx]
                    # Add the document's actual index
                    result['index'] = doc_id_to_index.get(doc_id, 0)
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
            
            # Update document count in database manager
            self.db_manager.update_document_count()
            
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
            
            # Get database file size in kilobytes
            db_path = os.path.join(self.storage_dir, 'documents.db')
            db_size_kb = 0
            if os.path.exists(db_path):
                db_size_bytes = os.path.getsize(db_path)
                db_size_kb = round(db_size_bytes / 1024, 2)
            
            return {
                'total_documents': doc_count,
                'embedding_dimension': self.embedding_dim,
                'model': 'all-MiniLM-L12-v2',
                'storage_location': self.storage_dir,
                'chroma_collection_count': self.collection.count(),
                'database_size_kb': db_size_kb
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
    
    def rename_document(self, doc_id: str, new_title: str) -> bool:
        """Rename a document by ID - no model needed"""
        session = get_session(self.engine)
        
        try:
            # Update in SQLite
            document = session.query(Document).filter_by(id=doc_id).first()
            if not document:
                return False
            
            document.title = new_title
            session.commit()
            
            # Update metadata in ChromaDB
            self.collection.update(
                ids=[doc_id],
                metadatas=[{"title": new_title, "created_at": document.created_at.isoformat()}]
            )
            
            return True
            
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()
    
    def update_document(self, doc_id: str, title: str = None, content: str = None, doc_type: str = None, tags: str = None, abstract: str = None, abstract_source: str = None, source: str = None, authors: str = None) -> bool:
        """Update a document's content and metadata"""
        session = get_session(self.engine)
        
        try:
            # Get the document from SQLite
            document = session.query(Document).filter_by(id=doc_id).first()
            if not document:
                return False
            
            # Update fields if provided
            if title is not None:
                document.title = title
            if content is not None:
                document.content = content
            if doc_type is not None:
                document.doc_type = doc_type
            if tags is not None:
                document.tags = tags
            if abstract is not None:
                document.abstract = abstract
            if abstract_source is not None:
                document.abstract_source = abstract_source
            if source is not None:
                document.source = source
            if authors is not None:
                document.authors = authors
            
            session.commit()
            
            # If content was updated, we need to update the embedding
            if content is not None and self.model:
                # Generate new embedding (only use content, not tags)
                embedding = self.model.encode([document.content])[0].tolist()
                
                # Update in ChromaDB
                self.collection.update(
                    ids=[doc_id],
                    embeddings=[embedding],
                    documents=[content],
                    metadatas=[{
                        "title": document.title,
                        "created_at": document.created_at.isoformat(),
                        "doc_type": document.doc_type or ""
                    }]
                )
            else:
                # Just update metadata if content wasn't changed
                self.collection.update(
                    ids=[doc_id],
                    metadatas=[{
                        "title": document.title,
                        "created_at": document.created_at.isoformat(),
                        "doc_type": document.doc_type or ""
                    }]
                )
            
            return True
            
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()