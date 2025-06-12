import json
import os
from typing import List, Dict, Optional
from datetime import datetime
import numpy as np
from sentence_transformers import SentenceTransformer
import faiss
from pydantic import BaseModel


class Document(BaseModel):
    id: str
    title: str
    content: str
    created_at: str
    embedding: Optional[List[float]] = None


class DocumentStore:
    def __init__(self, storage_dir: str = "storage"):
        self.storage_dir = storage_dir
        self.documents_dir = os.path.join(storage_dir, "documents")
        self.embeddings_dir = os.path.join(storage_dir, "embeddings")
        self.index_path = os.path.join(storage_dir, "faiss_index")
        
        os.makedirs(self.documents_dir, exist_ok=True)
        os.makedirs(self.embeddings_dir, exist_ok=True)
        
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
        self.embedding_dim = 384
        self.index = None
        self.document_ids = []
        
        self._load_index()
    
    def _load_index(self):
        if os.path.exists(self.index_path):
            self.index = faiss.read_index(self.index_path)
            ids_path = os.path.join(self.storage_dir, "document_ids.json")
            if os.path.exists(ids_path):
                with open(ids_path, 'r') as f:
                    self.document_ids = json.load(f)
        else:
            self.index = faiss.IndexFlatL2(self.embedding_dim)
    
    def _save_index(self):
        faiss.write_index(self.index, self.index_path)
        ids_path = os.path.join(self.storage_dir, "document_ids.json")
        with open(ids_path, 'w') as f:
            json.dump(self.document_ids, f)
    
    def add_document(self, title: str, content: str) -> str:
        doc_id = f"doc_{len(self.document_ids) + 1}_{int(datetime.now().timestamp())}"
        
        embedding = self.model.encode(content).tolist()
        
        document = Document(
            id=doc_id,
            title=title,
            content=content,
            created_at=datetime.now().isoformat(),
            embedding=embedding
        )
        
        doc_path = os.path.join(self.documents_dir, f"{doc_id}.json")
        with open(doc_path, 'w') as f:
            json.dump(document.dict(), f, indent=2)
        
        embedding_np = np.array([embedding], dtype=np.float32)
        self.index.add(embedding_np)
        self.document_ids.append(doc_id)
        
        self._save_index()
        
        return doc_id
    
    def search(self, query: str, k: int = 5) -> List[Dict]:
        if not self.document_ids:
            return []
        
        query_embedding = self.model.encode(query)
        query_embedding_np = np.array([query_embedding], dtype=np.float32)
        
        distances, indices = self.index.search(query_embedding_np, min(k, len(self.document_ids)))
        
        results = []
        for idx, distance in zip(indices[0], distances[0]):
            if idx < len(self.document_ids):
                doc_id = self.document_ids[idx]
                doc_path = os.path.join(self.documents_dir, f"{doc_id}.json")
                
                with open(doc_path, 'r') as f:
                    doc_data = json.load(f)
                    doc_data['similarity_score'] = float(1 / (1 + distance))
                    results.append(doc_data)
        
        return results
    
    def get_all_documents(self) -> List[Dict]:
        documents = []
        for doc_id in self.document_ids:
            doc_path = os.path.join(self.documents_dir, f"{doc_id}.json")
            with open(doc_path, 'r') as f:
                documents.append(json.load(f))
        return documents
    
    def delete_document(self, doc_id: str) -> bool:
        if doc_id not in self.document_ids:
            return False
        
        idx = self.document_ids.index(doc_id)
        self.document_ids.pop(idx)
        
        doc_path = os.path.join(self.documents_dir, f"{doc_id}.json")
        if os.path.exists(doc_path):
            os.remove(doc_path)
        
        self._rebuild_index()
        return True
    
    def _rebuild_index(self):
        self.index = faiss.IndexFlatL2(self.embedding_dim)
        
        for doc_id in self.document_ids:
            doc_path = os.path.join(self.documents_dir, f"{doc_id}.json")
            with open(doc_path, 'r') as f:
                doc_data = json.load(f)
                embedding = np.array([doc_data['embedding']], dtype=np.float32)
                self.index.add(embedding)
        
        self._save_index()