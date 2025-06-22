from sqlalchemy import create_engine, Column, String, Text, DateTime, ForeignKey, Table
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, sessionmaker
from datetime import datetime
import os

Base = declarative_base()

class Document(Base):
    __tablename__ = 'documents'
    
    id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    doc_type = Column(String, nullable=True)  # e.g., 'txt', 'md', 'pdf', 'json'
    tags = Column(String, nullable=True)  # Comma-separated tags
    abstract = Column(Text, nullable=True)  # Document abstract/summary
    abstract_source = Column(String, nullable=True)  # 'extracted', 'ai_generated', 'manual', 'first_paragraph'
    source = Column(String, nullable=True)  # URL or other source reference
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'doc_type': self.doc_type,
            'tags': self.tags,
            'abstract': self.abstract,
            'abstract_source': self.abstract_source,
            'source': self.source,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


def get_engine(db_path='storage/documents.db'):
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    engine = create_engine(f'sqlite:///{db_path}')
    Base.metadata.create_all(engine)
    return engine


def get_session(engine=None):
    if engine is None:
        engine = get_engine()
    Session = sessionmaker(bind=engine)
    return Session()