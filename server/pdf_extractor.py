"""
Enhanced PDF extraction utilities
"""

import PyPDF2
import io
import re
from typing import Tuple, Optional


class PDFExtractor:
    def __init__(self):
        pass
    
    def extract_text_and_metadata(self, pdf_content: bytes) -> Tuple[str, Optional[str], Optional[str]]:
        """
        Extract text, title, and abstract from PDF.
        Returns: (full_text, title, abstract)
        """
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_content))
        
        # First try metadata
        title_from_metadata = self._extract_title_from_metadata(pdf_reader)
        
        # Extract text from first few pages for title/abstract detection
        first_pages_text = ""
        full_text = ""
        
        for i, page in enumerate(pdf_reader.pages):
            page_text = page.extract_text()
            
            # For the first few pages, keep original formatting for better title/abstract extraction
            if i < 3:
                first_pages_text += page_text + "\n"
            
            # For full text, clean it up
            cleaned_text = self._basic_clean_text(page_text)
            full_text += cleaned_text + "\n\n"
        
        # Extract title from content if not in metadata
        title = title_from_metadata
        if not title:
            title = self._extract_title_from_text(first_pages_text)
        
        # Extract abstract
        abstract = self._extract_abstract_from_text(first_pages_text)
        
        return full_text, title, abstract
    
    def _basic_clean_text(self, text: str) -> str:
        """Basic text cleaning for general content"""
        # Fix ligatures
        text = text.replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('ﬀ', 'ff')
        text = text.replace('ﬃ', 'ffi').replace('ﬄ', 'ffl')
        
        # Fix spacing issues - add space between lowercase and uppercase
        text = re.sub(r'([a-z])([A-Z])', r'\1 \2', text)
        
        # Fix missing spaces after periods
        text = re.sub(r'\.([A-Z])', r'. \1', text)
        
        # Clean up extra whitespace
        text = re.sub(r'\s+', ' ', text)
        
        return text.strip()
    
    def _extract_title_from_metadata(self, pdf_reader) -> Optional[str]:
        """Extract title from PDF metadata"""
        try:
            if pdf_reader.metadata:
                title = (
                    pdf_reader.metadata.get('/Title') or 
                    pdf_reader.metadata.get('/title') or
                    pdf_reader.metadata.get('Title')
                )
                if title:
                    return title.strip()
        except:
            pass
        return None
    
    def _extract_title_from_text(self, text: str) -> Optional[str]:
        """Extract title from PDF text content - handles arXiv papers better"""
        lines = text.split('\n')
        
        # Track potential title lines
        title_lines = []
        found_content_start = False
        skip_until_line = 0
        
        for i, line in enumerate(lines[:50]):  # Look at first 50 lines
            if i < skip_until_line:
                continue
                
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
            
            # Skip arXiv headers and dates
            if re.match(r'^arXiv:\d+\.\d+', line):
                continue
            if re.match(r'^\d+\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)', line):
                continue
            
            # Skip URLs and emails
            if '@' in line or 'http' in line or 'www.' in line:
                continue
            
            # Skip author affiliations (numbers in superscript, institutions)
            if re.match(r'^[\d,\s]+$', line):  # Just numbers and commas
                continue
            if len(line.split()) <= 3 and any(inst in line for inst in ['University', 'Institute', 'Department', 'Laboratory', 'Center']):
                continue
            
            # Skip very short lines that are likely artifacts
            if len(line) < 10:
                continue
            
            # Check if this looks like a title
            # Titles are usually:
            # - Not all caps (but might have some caps)
            # - Not starting with common section markers
            # - Of reasonable length
            # - Often followed by authors or empty lines
            
            if line.isupper() and len(line.split()) > 5:  # Skip long all-caps lines
                continue
            
            section_starters = ['abstract', 'introduction', 'contents', 'keywords', 'acknowledgments', 'references']
            if any(line.lower().startswith(starter) for starter in section_starters):
                break  # We've gone too far
            
            # This might be part of the title
            if not found_content_start and len(line) > 15:
                # Check if it's a reasonable title candidate
                # - Has both upper and lower case (not all caps)
                # - Doesn't start with a number (unless it's a short prefix)
                # - Reasonable length
                
                has_lower = any(c.islower() for c in line)
                has_upper = any(c.isupper() for c in line)
                
                if has_lower and has_upper and len(line) < 200:
                    title_lines.append(line)
                    
                    # Check next few lines to see if they continue the title
                    for j in range(i + 1, min(i + 4, len(lines))):
                        next_line = lines[j].strip()
                        if not next_line:  # Empty line might signal end of title
                            found_content_start = True
                            break
                        
                        # Check if it's an author line (contains names, possibly with numbers)
                        if re.search(r'\b[A-Z][a-z]+\s+[A-Z][a-z]+', next_line):  # Looks like names
                            found_content_start = True
                            break
                        
                        # If it's another title-like line
                        if len(next_line) > 10 and len(next_line) < 100 and not '@' in next_line:
                            if any(c.islower() for c in next_line) and any(c.isupper() for c in next_line):
                                title_lines.append(next_line)
                            else:
                                break
                        else:
                            break
                    
                    if found_content_start or len(title_lines) >= 3:
                        break
        
        if title_lines:
            # Combine the title lines
            title = ' '.join(title_lines)
            # Clean up
            title = re.sub(r'\s+', ' ', title)
            title = title.strip()
            return title
        
        return None
    
    def _extract_abstract_from_text(self, text: str) -> Optional[str]:
        """Extract abstract from PDF text - handles poor text extraction"""
        # First, let's fix common issues in the text
        text = text.replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('ﬀ', 'ff')
        text = text.replace('ﬃ', 'ffi').replace('ﬄ', 'ffl')
        
        # Look for Abstract section
        abstract_match = re.search(
            r'(?:^|\n)\s*Abstract\s*\n+(.+?)(?:\n\s*(?:1\.?\s*Introduction|I\.\s*INTRODUCTION|Keywords?|Index Terms|Categories)|$)',
            text,
            re.IGNORECASE | re.DOTALL
        )
        
        if abstract_match:
            abstract = abstract_match.group(1).strip()
            
            # Clean the abstract
            abstract = self._clean_abstract_text(abstract)
            
            if abstract and 50 < len(abstract) < 2000:
                return abstract
        
        return None
    
    def _clean_abstract_text(self, text: str) -> str:
        """Clean abstract text with better handling of PDF extraction issues"""
        # Fix merged words - more comprehensive
        # Add space between lowercase and uppercase (but not in acronyms)
        text = re.sub(r'([a-z])([A-Z][a-z])', r'\1 \2', text)
        
        # Fix specific patterns that are commonly merged
        problem_words = [
            'performance', 'networks', 'learning', 'models', 'systems', 'recognition',
            'classification', 'algorithms', 'processing', 'analysis', 'method',
            'approach', 'techniques', 'applications', 'framework', 'architecture'
        ]
        for word in problem_words:
            # Add space before the word if it's preceded by a lowercase letter
            text = re.sub(f'([a-z])({word})', r'\1 \2', text, flags=re.IGNORECASE)
        
        # Fix spacing around punctuation
        text = re.sub(r'\s+([.,;:!?])', r'\1', text)
        text = re.sub(r'([.,;:!?])([A-Za-z])', r'\1 \2', text)
        
        # Fix "achieve a" type patterns
        text = re.sub(r'([a-z])(a|an|the|to|of|in|on|at|by|for|with|from)\s+', r'\1 \2 ', text)
        
        # Remove line breaks within sentences
        text = re.sub(r'([a-z,])\s*\n\s*([a-z])', r'\1 \2', text)
        
        # Fix hyphenation
        text = re.sub(r'([a-z])-\s*\n\s*([a-z])', r'\1\2', text)
        
        # Clean up whitespace
        text = re.sub(r'\s+', ' ', text)
        text = re.sub(r'\n+', ' ', text)
        
        # Remove page numbers at the end
        text = re.sub(r'\s+\d+\s*$', '', text)
        
        return text.strip()