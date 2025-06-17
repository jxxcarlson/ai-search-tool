"""
Database management for AI Search Tool.
Handles multiple named databases with switching capability.
"""

import json
import os
import shutil
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

import config


class DatabaseInfo:
    """Information about a database."""
    
    def __init__(self, id: str, name: str, created_at: str = None, 
                 description: str = None, document_count: int = 0,
                 last_accessed: str = None):
        self.id = id
        self.name = name
        self.created_at = created_at or datetime.now().isoformat()
        self.description = description
        self.document_count = document_count
        self.last_accessed = last_accessed or datetime.now().isoformat()
    
    def to_dict(self) -> Dict:
        return {
            "id": self.id,
            "name": self.name,
            "created_at": self.created_at,
            "description": self.description,
            "document_count": self.document_count,
            "last_accessed": self.last_accessed
        }
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'DatabaseInfo':
        return cls(**data)


class DatabaseManager:
    """Manages multiple databases."""
    
    def __init__(self):
        self.registry_path = config.STORAGE_DIR / "databases.json"
        self.current_database_id = None
        self.databases = {}
        self._load_registry()
    
    def _load_registry(self):
        """Load database registry from file."""
        if self.registry_path.exists():
            with open(self.registry_path, 'r') as f:
                data = json.load(f)
                self.current_database_id = data.get("current_database_id", "default")
                self.databases = {
                    db_data["id"]: DatabaseInfo.from_dict(db_data)
                    for db_data in data.get("databases", [])
                }
        else:
            # First run - migrate existing data
            self._migrate_existing_storage()
    
    def _save_registry(self):
        """Save database registry to file."""
        data = {
            "current_database_id": self.current_database_id,
            "databases": [db.to_dict() for db in self.databases.values()]
        }
        with open(self.registry_path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def _migrate_existing_storage(self):
        """Migrate existing storage to default database."""
        print("Migrating existing storage to multi-database structure...")
        
        # Create default database entry
        default_db = DatabaseInfo(
            id="default",
            name="My Documents",
            description="Main document collection"
        )
        
        # Check if we have existing data to migrate
        old_db_path = config.STORAGE_DIR / "documents.db"
        if old_db_path.exists():
            # Create new structure
            default_storage = config.STORAGE_DIR / "default"
            default_storage.mkdir(exist_ok=True)
            
            # Move existing files
            items_to_move = [
                "documents.db",
                "chroma_db",
                "documents", 
                "pdfs",
                "pdf_thumbnails",
                "document_ids.json"
            ]
            
            for item in items_to_move:
                old_path = config.STORAGE_DIR / item
                if old_path.exists():
                    new_path = default_storage / item
                    shutil.move(str(old_path), str(new_path))
                    print(f"  Moved {item}")
            
            # Count documents
            import sqlite3
            conn = sqlite3.connect(default_storage / "documents.db")
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM documents")
            default_db.document_count = cursor.fetchone()[0]
            conn.close()
        else:
            # No existing data, just create structure
            default_storage = config.STORAGE_DIR / "default"
            default_storage.mkdir(parents=True, exist_ok=True)
        
        self.databases["default"] = default_db
        self.current_database_id = "default"
        self._save_registry()
        print("Migration complete!")
    
    def get_current_database(self) -> DatabaseInfo:
        """Get the currently active database."""
        if self.current_database_id not in self.databases:
            raise ValueError(f"Current database {self.current_database_id} not found")
        
        # Update last accessed time
        db = self.databases[self.current_database_id]
        db.last_accessed = datetime.now().isoformat()
        self._save_registry()
        
        return db
    
    def get_database_path(self, database_id: str = None) -> Path:
        """Get the storage path for a database."""
        if database_id is None:
            database_id = self.current_database_id
        
        if database_id not in self.databases:
            raise ValueError(f"Database {database_id} not found")
        
        return config.STORAGE_DIR / database_id
    
    def list_databases(self) -> List[DatabaseInfo]:
        """List all databases."""
        return list(self.databases.values())
    
    def create_database(self, name: str, description: str = None) -> DatabaseInfo:
        """Create a new database."""
        # Generate unique ID
        db_id = f"db_{uuid.uuid4().hex[:8]}"
        
        # Create database info
        new_db = DatabaseInfo(
            id=db_id,
            name=name,
            description=description
        )
        
        # Create storage directory
        db_path = config.STORAGE_DIR / db_id
        db_path.mkdir(parents=True, exist_ok=True)
        
        # Create subdirectories
        (db_path / "documents").mkdir(exist_ok=True)
        (db_path / "pdfs").mkdir(exist_ok=True) 
        (db_path / "pdf_thumbnails").mkdir(exist_ok=True)
        
        # Initialize document_ids.json
        with open(db_path / "document_ids.json", 'w') as f:
            f.write("[]")
        
        # Initialize empty database
        from models import Base, get_engine
        engine = get_engine(str(db_path / "documents.db"))
        Base.metadata.create_all(bind=engine)
        
        # Save to registry
        self.databases[db_id] = new_db
        self._save_registry()
        
        return new_db
    
    def switch_database(self, database_id: str) -> DatabaseInfo:
        """Switch to a different database."""
        if database_id not in self.databases:
            raise ValueError(f"Database {database_id} not found")
        
        self.current_database_id = database_id
        self._save_registry()
        
        return self.get_current_database()
    
    def update_database(self, database_id: str, name: str = None, 
                       description: str = None) -> DatabaseInfo:
        """Update database metadata."""
        if database_id not in self.databases:
            raise ValueError(f"Database {database_id} not found")
        
        db = self.databases[database_id]
        
        if name is not None:
            db.name = name
        if description is not None:
            db.description = description
        
        self._save_registry()
        return db
    
    def delete_database(self, database_id: str) -> bool:
        """Delete a database."""
        if database_id not in self.databases:
            raise ValueError(f"Database {database_id} not found")
        
        if database_id == self.current_database_id:
            raise ValueError("Cannot delete the current active database")
        
        if len(self.databases) == 1:
            raise ValueError("Cannot delete the last remaining database")
        
        # Remove from registry
        del self.databases[database_id]
        
        # Delete storage directory
        db_path = config.STORAGE_DIR / database_id
        if db_path.exists():
            shutil.rmtree(db_path)
        
        self._save_registry()
        return True
    
    def update_document_count(self, database_id: str = None, count: int = None):
        """Update the document count for a database."""
        if database_id is None:
            database_id = self.current_database_id
        
        if database_id not in self.databases:
            return
        
        if count is None:
            # Count from database
            import sqlite3
            db_path = self.get_database_path(database_id)
            db_file = db_path / "documents.db"
            if db_file.exists():
                conn = sqlite3.connect(db_file)
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM documents")
                count = cursor.fetchone()[0]
                conn.close()
            else:
                count = 0
        
        self.databases[database_id].document_count = count
        self._save_registry()


# Global instance
_database_manager = None


def get_database_manager() -> DatabaseManager:
    """Get the global database manager instance."""
    global _database_manager
    if _database_manager is None:
        _database_manager = DatabaseManager()
    return _database_manager