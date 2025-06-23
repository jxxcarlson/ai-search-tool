import re
from typing import List, Optional, Set
import logging

logger = logging.getLogger(__name__)

class AuthorExtractor:
    """Extract author information from document content"""
    
    def __init__(self):
        # Common author patterns
        self.author_patterns = [
            # "By Author Name" patterns - stop at newline or certain keywords
            r"(?i)^by\s+([A-Z][A-Za-z\s\-\.,']+?)(?=\s*(?:\n|Abstract|Introduction|Chapter|$))",
            r"(?i)\nby\s+([A-Z][A-Za-z\s\-\.,']+?)(?=\s*(?:\n|Abstract|Introduction|Chapter|$))",
            
            # "Author: Name" patterns
            r"(?i)authors?:\s*([A-Za-z\s\-\.,';&]+?)(?:\n|$)",
            
            # Academic paper patterns (e.g., "John Doe^1, Jane Smith^2")
            r"^([A-Z][a-z]+(?:\s+[A-Z]\.?\s*)*[A-Z][a-z]+)(?:\s*[\^\d\*†‡§¶,]+)(?:\s|$)",
            
            # Author name at beginning of line (for papers)
            r"^([A-Z][a-z]+(?:\s+[A-Z]\.?\s+)?[A-Z][a-z]+)\s*$",
            
            # LaTeX author commands
            r"\\author\{([^}]+)\}",
            r"\\author\[([^\]]+)\]\{([^}]+)\}",
            
            # Markdown/HTML author metadata
            r"(?i)author:\s*([^\n]+)",
            r"(?i)<meta\s+name=[\"']author[\"']\s+content=[\"']([^\"']+)[\"']",
            
            # Copyright patterns
            r"(?i)(?:copyright|©)\s*(?:\d{4}\s*)?(?:by\s+)?([A-Z][A-Za-z\s\-\.,']+?)(?:\.|,|\s*All|\s*$)",
            
            # Email-based patterns (extract name before email)
            r"([A-Z][a-z]+(?:\s+[A-Z]\.?\s*)*[A-Z][a-z]+)\s*(?:<[^>]+@[^>]+>|\([^)]+@[^)]+\))",
            
            # Academic affiliations (Name^1,2 or Name*) 
            r"^([A-Z][a-z]+(?:\s+(?:[A-Z]\.?\s*)+)?[A-Z][a-z]+)(?:\s*[\*\d,†‡§¶]+)",
        ]
        
        # Patterns to exclude false positives
        self.exclusion_patterns = [
            r"(?i)^(?:abstract|introduction|conclusion|references|acknowledgments|table|figure|chapter|section|part|volume|appendix)",
            r"(?i)^(?:january|february|march|april|may|june|july|august|september|october|november|december)",
            r"(?i)^(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)",
            r"(?i)^(?:university|institute|department|laboratory|center|college|school)\s+of",
        ]
        
        # Common titles and suffixes to preserve
        self.title_pattern = r"(?:Ph\.?D\.?|M\.?D\.?|M\.?S\.?|B\.?S\.?|M\.?A\.?|B\.?A\.?|Prof\.?|Dr\.?|Mr\.?|Ms\.?|Mrs\.?|Jr\.?|Sr\.?|III|II|IV)"
        
    def extract_authors(self, content: str, doc_type: Optional[str] = None) -> Optional[str]:
        """
        Extract authors from document content
        
        Args:
            content: The document content
            doc_type: The document type (e.g., 'pdf', 'md', 'ltx')
            
        Returns:
            Semicolon-separated list of authors or None if no authors found
        """
        if not content:
            return None
            
        authors = set()
        
        # First check the beginning of the document (first 2000 characters)
        # as authors are usually mentioned early
        early_content = content[:2000]
        
        # Try each pattern
        for pattern in self.author_patterns:
            try:
                matches = re.findall(pattern, early_content, re.MULTILINE)
                for match in matches:
                    # Handle tuple matches from patterns with groups
                    if isinstance(match, tuple):
                        match = ' '.join(match).strip()
                    
                    # Clean and validate the match
                    cleaned_authors = self._clean_author_string(match)
                    for author in cleaned_authors:
                        if self._is_valid_author(author):
                            authors.add(author)
            except Exception as e:
                logger.debug(f"Error with pattern {pattern}: {e}")
                continue
        
        # Special handling for LaTeX documents
        if doc_type == 'ltx' or '\\documentclass' in early_content:
            latex_authors = self._extract_latex_authors(content)
            # If we have LaTeX authors, prefer them over pattern matches
            if latex_authors:
                authors = latex_authors
            else:
                authors.update(latex_authors)
        
        # Special handling for PDF metadata (if it's in the content)
        if doc_type == 'pdf' and '/Author' in content[:5000]:
            pdf_authors = self._extract_pdf_metadata_authors(content)
            authors.update(pdf_authors)
        
        # Convert to list and sort for consistent output
        author_list = sorted(list(authors))
        
        if author_list:
            return '; '.join(author_list)
        return None
    
    def _clean_author_string(self, author_string: str) -> List[str]:
        """Clean and split author string into individual authors"""
        # Remove common separators and clean up
        author_string = re.sub(r'[\*†‡§¶\d]+', '', author_string)
        author_string = re.sub(r'\s+', ' ', author_string)
        author_string = author_string.strip()
        
        # Split by common separators
        authors = []
        for separator in [';', ' and ', ' & ', ', and ', ', & ', ',']:
            if separator in author_string:
                parts = author_string.split(separator)
                for part in parts:
                    part = part.strip()
                    if part:
                        authors.append(part)
                return authors
        
        # If no separator found, return as single author
        if author_string:
            authors.append(author_string)
        
        return authors
    
    def _is_valid_author(self, author: str) -> bool:
        """Check if a string is likely to be a valid author name"""
        # Remove titles for validation
        author_without_title = re.sub(self.title_pattern, '', author).strip()
        
        # Too short or too long
        if len(author_without_title) < 3 or len(author_without_title) > 100:
            return False
        
        # Must contain at least one letter
        if not re.search(r'[a-zA-Z]', author_without_title):
            return False
        
        # Check against exclusion patterns
        for pattern in self.exclusion_patterns:
            if re.match(pattern, author_without_title):
                return False
        
        # Must have at least two parts (first and last name)
        # unless it includes titles
        parts = author_without_title.split()
        if len(parts) < 2 and not re.search(self.title_pattern, author):
            return False
        
        # Check if it looks like a name (starts with capital letter)
        if not re.match(r'^[A-Z]', author_without_title):
            return False
        
        return True
    
    def _extract_latex_authors(self, content: str) -> Set[str]:
        """Extract authors from LaTeX documents"""
        authors = set()
        
        # Look for \author{...} command
        author_matches = re.findall(r'\\author\s*(?:\[[^\]]*\])?\s*\{([^}]+)\}', content)
        for match in author_matches:
            # Handle \and separator in LaTeX
            latex_authors = match.split('\\and')
            for author in latex_authors:
                # Remove LaTeX commands like \thanks{...}
                author = re.sub(r'\\[a-zA-Z]+\{[^}]*\}', '', author)
                author = re.sub(r'\\[a-zA-Z]+', '', author)
                author = author.strip()
                
                # Skip if it's the full string with \and
                if '\\and' in author:
                    continue
                    
                cleaned_authors = self._clean_author_string(author)
                for cleaned in cleaned_authors:
                    if self._is_valid_author(cleaned):
                        authors.add(cleaned)
        
        return authors
    
    def _extract_pdf_metadata_authors(self, content: str) -> Set[str]:
        """Extract authors from PDF metadata"""
        authors = set()
        
        # Look for /Author (Name) pattern in PDF metadata
        author_matches = re.findall(r'/Author\s*\(([^)]+)\)', content[:5000])
        for match in author_matches:
            # Handle Unicode escape sequences in PDFs
            try:
                # Basic handling of escaped characters
                match = match.encode('latin-1').decode('unicode_escape')
            except:
                pass
            
            cleaned_authors = self._clean_author_string(match)
            for author in cleaned_authors:
                if self._is_valid_author(author):
                    authors.add(author)
        
        return authors
    
    def extract_authors_with_confidence(self, content: str, doc_type: Optional[str] = None) -> tuple[Optional[str], float]:
        """
        Extract authors and return confidence score
        
        Returns:
            Tuple of (authors_string, confidence_score)
            confidence_score is between 0 and 1
        """
        authors = self.extract_authors(content, doc_type)
        
        if not authors:
            return None, 0.0
        
        # Calculate confidence based on various factors
        confidence = 0.5  # Base confidence
        
        author_list = authors.split('; ')
        
        # Higher confidence if multiple authors found
        if len(author_list) > 1:
            confidence += 0.2
        
        # Higher confidence if authors have titles
        if re.search(self.title_pattern, authors):
            confidence += 0.15
        
        # Higher confidence for LaTeX or academic paper formats
        if doc_type == 'ltx' or '\\documentclass' in content[:1000]:
            confidence += 0.15
        
        # Cap confidence at 1.0
        confidence = min(confidence, 1.0)
        
        return authors, confidence