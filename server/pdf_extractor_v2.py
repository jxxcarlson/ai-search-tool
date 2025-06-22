"""
Enhanced PDF extraction utilities with better text extraction
"""

import PyPDF2
import io
import re
from typing import Tuple, Optional
import unicodedata


class PDFExtractorV2:
    def __init__(self):
        pass
    
    def extract_text_and_metadata(self, pdf_content: bytes) -> Tuple[str, Optional[str], Optional[str]]:
        """
        Extract text, title, and abstract from PDF with enhanced text processing.
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
            
            # Apply aggressive text cleaning for better extraction
            if i < 3:  # First 3 pages for title/abstract
                cleaned_for_extraction = self._aggressive_clean_text(page_text)
                first_pages_text += cleaned_for_extraction + "\n"
            
            # For full text, use moderate cleaning
            cleaned_text = self._moderate_clean_text(page_text)
            full_text += cleaned_text + "\n\n"
        
        # Extract title from content if not in metadata
        title = title_from_metadata
        if not title:
            title = self._extract_title_from_text(first_pages_text)
        
        # Extract abstract
        abstract = self._extract_abstract_from_text(first_pages_text)
        
        return full_text, title, abstract
    
    def _aggressive_clean_text(self, text: str) -> str:
        """Aggressive text cleaning for title/abstract extraction"""
        # First, normalize unicode
        text = unicodedata.normalize('NFKD', text)
        
        # Fix all known ligatures
        ligature_map = {
            'ﬁ': 'fi', 'ﬂ': 'fl', 'ﬀ': 'ff', 'ﬃ': 'ffi', 'ﬄ': 'ffl',
            'ﬅ': 'st', 'ﬆ': 'st', '№': 'No', '℗': '(P)', '™': 'TM',
            '℠': 'SM', '℡': 'TEL', '∞': 'infinity', '≈': 'approx'
        }
        for lig, replacement in ligature_map.items():
            text = text.replace(lig, replacement)
        
        # Fix spacing between words (common PDF issue)
        # Add space between lowercase and uppercase
        text = re.sub(r'([a-z])([A-Z])', r'\1 \2', text)
        
        # Add space between letter and number
        text = re.sub(r'([a-zA-Z])(\d)', r'\1 \2', text)
        text = re.sub(r'(\d)([a-zA-Z])', r'\1 \2', text)
        
        # Fix specific patterns for academic papers
        # Add spaces before common words that get merged
        common_words = [
            'the', 'and', 'of', 'to', 'in', 'is', 'for', 'with', 'as', 'on', 'at', 'by',
            'from', 'that', 'which', 'are', 'an', 'be', 'has', 'have', 'had', 'do',
            'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must',
            'can', 'this', 'these', 'those', 'such', 'into', 'through', 'during', 'after',
            'before', 'above', 'below', 'between', 'under', 'over'
        ]
        
        for word in common_words:
            # Add space before the word if preceded by a letter (case insensitive)
            text = re.sub(f'([a-z])({word})(?=[^a-z])', rf'\1 \2', text, flags=re.IGNORECASE)
        
        # Fix missing spaces after periods, commas, etc.
        text = re.sub(r'([.!?])([A-Z])', r'\1 \2', text)
        text = re.sub(r'([,;:])([A-Za-z])', r'\1 \2', text)
        
        # Fix hyphenation at line breaks
        text = re.sub(r'([a-z])-\s*\n\s*([a-z])', r'\1\2', text)
        
        # Remove excessive whitespace
        text = re.sub(r'\s+', ' ', text)
        text = re.sub(r'\n\s*\n', '\n', text)
        
        return text.strip()
    
    def _moderate_clean_text(self, text: str) -> str:
        """Moderate text cleaning for general content"""
        # Fix ligatures
        text = text.replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('ﬀ', 'ff')
        text = text.replace('ﬃ', 'ffi').replace('ﬄ', 'ffl')
        
        # Basic spacing fixes
        text = re.sub(r'([a-z])([A-Z])', r'\1 \2', text)
        text = re.sub(r'\.([A-Z])', r'. \1', text)
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
                    title = title.strip()
                    # Validate that this is actually a title, not metadata
                    # Skip if it's an arXiv identifier or other metadata
                    invalid_patterns = [
                        r'^arXiv:.*',  # arXiv headers
                        r'^\d{4}\.\d{4,5}v?\d*',  # Standalone arXiv numbers
                        r'^doi:',  # DOI
                        r'^http',  # URLs
                        r'^\d+$',  # Just numbers
                    ]
                    
                    for pattern in invalid_patterns:
                        if re.match(pattern, title, re.IGNORECASE):
                            # Metadata title rejected - matches invalid pattern
                            return None
                    
                    # Also check for skip words
                    skip_words = ['preprint', 'manuscript', 'accepted', 'published']
                    if any(word in title.lower() for word in skip_words):
                        # Metadata title rejected - contains skip words
                        return None
                    
                    # Metadata title accepted
                    return title
        except:
            pass
        return None
    
    def _extract_title_from_text(self, text: str) -> Optional[str]:
        """Extract title from PDF text content - handles various academic paper formats"""
        # First check if we have a PDF where everything is on one line
        lines = text.split('\n')
        if len(lines) < 5 and len(text) > 1000:
            # Try to intelligently split the text
            # Look for common paper structure markers
            # PDF appears to be single line, attempting intelligent splitting
            
            # First, let's try to find and skip past the arXiv header if present
            # Handle cases where PDF extraction adds spaces within words
            arxiv_pattern = r'ar\s*X\s*iv\s*:\s*\d+\.\d+\s*v?\s*\d*\s*\[[^\]]+\]\s*\d+\s*\w+\s*\d{4}'
            arxiv_match = re.search(arxiv_pattern, text[:500], re.IGNORECASE)
            
            if arxiv_match:
                # Start looking for title after the arXiv header
                start_pos = arxiv_match.end()
                remaining_text = text[start_pos:].strip()
                # Found arXiv header, looking for title after position
                
                # Look for the actual title after the header
                # Often the title starts right after the date
                title_patterns = [
                    # Title that may span multiple "lines" with "with" or other connectors
                    r'^((?:[A-Z][^.!?\n]*?(?:with|using|for|and|of|in|on|via|through|by|from)\s+[^.!?\n]*?)+(?:Learning|Networks?|Model|System|Method|Algorithm|Framework|Analysis|Study|Survey|Review|Approach|Architecture|Technique)s?)\s+',
                    # Title ending with common keywords (but capture the whole phrase)
                    r'^([^.!?\n]*?(?:Learning|Networks?|Model|System|Method|Algorithm|Framework|Analysis|Study|Survey|Review)\s*(?:with|using|for|and|of|in|on|via|through|by|from)?\s*[^.!?\n]*?)\s+(?=[A-Z][a-z]+\s+[A-Z])',
                    # Simple title ending with Networks/Learning/etc
                    r'^(.*?(?:Learning|Networks?|Model|System|Method|Algorithm|Framework|Analysis|Study|Survey|Review|Processing|Recognition|Detection|Classification|Prediction|Translation)s?)\s+(?=[A-Z][a-z]+\s+[A-Z])',
                    # Title up to author names (with flexible spacing)
                    r'^([A-Z][^.!?\n]{10,200}?)(?=\s+[A-Z][a-z]+\s+[A-Z]\.?\s*[A-Z]?[a-z]*)',
                    # Title up to multiple capitalized words
                    r'^([A-Z][^.!?\n]{10,200}?)(?=\s+[A-Z][a-z]+\s+[A-Z][a-z]+\s+[A-Z][a-z]+)',
                    # Fallback: capture until we see typical author/institution patterns
                    r'^([^.!?\n]{10,200}?)(?=\s+(?:[A-Z][a-z]+\s+){2,})',
                ]
                
                # Text after arXiv header
                
                for i, pattern in enumerate(title_patterns):
                    title_match = re.match(pattern, remaining_text)
                    if title_match:
                        potential_title = title_match.group(1).strip()
                        potential_title = re.sub(r'\s+', ' ', potential_title)
                        # Pattern matched. Found title after arXiv header
                        if 10 < len(potential_title) < 200:
                            return potential_title
                    # Pattern did not match
            
            # Original patterns for non-arXiv papers
            patterns = [
                # Title ending with common academic paper keywords
                r'^([\w\s:,-]+?(?:Survey|Study|Analysis|Review|Overview|Approach|Method|Framework|System))\s+[A-Z][a-z]+\s+[A-Z][a-z]+',
                # Title with colon and subtitle
                r'^([^:]+:\s*[A-Za-z\s]+?)\s+(?=[A-Z][a-z]+\s+[A-Z][a-z]+)',
                # Title before author pattern (multiple names)
                r'^(.+?)\s+(?=[A-Z][a-z]+\s+[A-Z][a-z]+\s+[A-Z][a-z]+\s+[a-z]+)',
                # Title followed by special chars
                r'^([^\x00-\x1f\x7f-\x9f]+?)[\x00-\x1f\x7f-\x9f]',
                # Title followed by institution
                r'^([^:\x00-\x1f\x7f-\x9f]{10,200}?)\s+(?:University|Institute|Department|College)',
            ]
            
            for pattern in patterns:
                title_match = re.match(pattern, text[:1000])
                if title_match:
                    potential_title = title_match.group(1).strip()
                    # Clean up any special characters
                    potential_title = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', potential_title)
                    potential_title = re.sub(r'\s+', ' ', potential_title).strip()
                    # Found title via pattern match
                    if 15 < len(potential_title) < 200:
                        return potential_title
            
            # Try splitting by common section markers
            split_patterns = [
                r'(?=Abstract)',
                r'(?=Introduction)',
                r'(?=\d+\s*Introduction)',
                r'(?=[A-Z][a-z]+\s+[A-Z][a-z]+\s*[\x00-\x1f\x7f-\x9f])',  # Author names with special chars
            ]
            
            for pattern in split_patterns:
                parts = re.split(pattern, text[:2000], maxsplit=1)
                if len(parts) > 1 and len(parts[0]) > 10:
                    # Process the first part as potential title + metadata
                    first_part = parts[0]
                    # Try to extract just the title from the beginning
                    lines = [first_part[:200]]  # Take first 200 chars as potential title area
                    break
            else:
                # If no split worked, try to extract from the very beginning
                lines = [text[:500]]
        
        # First 10 lines of PDF text for debugging
        
        # Clean and filter lines
        cleaned_lines = []
        skip_patterns = [
            r'^arXiv:.*\d{4}\.\d{4,5}v?\d*.*$',  # Full arXiv header line (includes categories, dates)
            r'^arXiv:\s*\d+\.\d+v?\d*',  # arXiv identifier with optional version
            r'^\d{4}\.\d{4,5}v?\d*$',  # Standalone arXiv-style numbers (YYMM.NNNNN format)
            r'.*\[(?:cs|math|physics|stat|q-bio|q-fin|econ|eess)\.[\w.-]+\]\s*\d+\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}',  # arXiv category with date
            r'^\d+\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',  # Dates
            r'^https?://',  # URLs
            r'@[a-zA-Z]',  # Email addresses
            r'^\d+$',  # Page numbers
            r'^[A-Z][a-z]+\s+[A-Z][a-z]+$',  # Author names (simple pattern)
            r'^\d+\s*,?\s*\d*$',  # Numbers and affiliations
            r'^doi:',  # DOI identifiers
            r'^\[\d+\]',  # Reference numbers
            r'^(preprint|submitted|accepted|published)',  # Status indicators
            r'^©\s*\d+',  # Copyright notices
            r'^\d+[-–]\d+[-–]\d+',  # Date formats
            r'^ISSN\s*\d+',  # ISSN numbers
            r'^ISBN\s*[\d-]+',  # ISBN numbers
            r'^vol\.\s*\d+',  # Volume numbers
            r'^pp\.\s*\d+',  # Page numbers
        ]
        
        found_content = False
        potential_title_lines = []
        
        for i, line in enumerate(lines[:50]):  # Check first 50 lines
            line = line.strip()
            
            # Skip empty or very short lines
            if not line or len(line) < 10:
                continue
            
            # Skip lines matching skip patterns
            skip_match = False
            for pattern in skip_patterns:
                if re.match(pattern, line):
                    # Line skipped by pattern
                    skip_match = True
                    break
            if skip_match:
                continue
            
            # Skip common headers/footers and metadata
            skip_words = [
                'preprint', 'manuscript', 'accepted', 'published', 'draft',
                'conference', 'journal', 'proceedings', 'volume', 'issue',
                'copyright', 'license', 'arxiv', 'doi:', 'isbn', 'issn'
            ]
            if any(word in line.lower() for word in skip_words):
                # Line skipped by skip_words
                continue
            
            # Look for title characteristics
            # - Mixed case (not all caps, not all lower)
            # - Reasonable length
            # - No special formatting characters
            has_upper = any(c.isupper() for c in line)
            has_lower = any(c.islower() for c in line)
            
            if has_upper and has_lower and 15 < len(line) < 200:
                # Check if this could be a title
                # Titles often have more uppercase at the beginning
                first_word = line.split()[0] if line.split() else ""
                if first_word and first_word[0].isupper():
                    # Found potential title line
                    potential_title_lines.append(line)
                    
                    # Check if next lines continue the title
                    for j in range(i + 1, min(i + 4, len(lines))):
                        next_line = lines[j].strip()
                        if not next_line:
                            break
                        
                        # Check if next line should be skipped
                        should_skip = False
                        for pattern in skip_patterns:
                            if re.match(pattern, next_line):
                                should_skip = True
                                break
                        if should_skip:
                            break
                            
                        if any(word in next_line.lower() for word in skip_words):
                            break
                        
                        # If next line looks like authors, affiliations, or section start, stop
                        if (re.search(r'^[A-Z][a-z]+\s+[A-Z]\.\s*[A-Z][a-z]+', next_line) or  # Author with middle initial
                            re.search(r'^[A-Z][a-z]+\s+[A-Z][a-z]+\s*[\d,†‡§¶]+', next_line) or  # Author with affiliation marker
                            re.search(r'^\d+\s*[A-Z][a-z]+\s+(University|Institute|Department|School|College|Center)', next_line) or  # Affiliation
                            re.search(r'^(Abstract|Introduction|Keywords|Summary|Overview)\s*[:.]?', next_line, re.IGNORECASE) or
                            re.search(r'^(1\.|I\.|1\s+)', next_line)):  # Section numbering
                            found_content = True
                            break
                        
                        # Check if it looks like a title continuation
                        next_has_upper = any(c.isupper() for c in next_line)
                        next_has_lower = any(c.islower() for c in next_line)
                        
                        # If it looks like a continuation of title
                        if (next_has_lower and next_has_upper and len(next_line) > 10):
                            # Adding continuation line
                            potential_title_lines.append(next_line)
                        else:
                            break
                    
                    if found_content or len(potential_title_lines) >= 1:
                        break
        
        if potential_title_lines:
            # Join title lines and clean
            title = ' '.join(potential_title_lines)
            title = re.sub(r'\s+', ' ', title)
            title = title.strip()
            
            # Found potential title
            
            # Final validation
            if 15 < len(title) < 300:  # Reasonable title length
                # Returning title
                return title
            else:
                # Title rejected due to length
        else:
            # No potential title lines found
        
        return None
    
    def _extract_abstract_from_text(self, text: str) -> Optional[str]:
        """Extract abstract from PDF text with better pattern matching"""
        # Multiple patterns to catch different abstract formats
        abstract_patterns = [
            # Standard "Abstract" heading with various endings
            (r'\bAbstract\s*[\n\r]+(.+?)(?=\n\s*(?:1\.?\s*Introduction|Keywords?|Index Terms|Categories|I\.\s*INTRODUCTION|\d+\s+Introduction|Introduction\s*\n))', re.IGNORECASE | re.DOTALL),
            # Abstract with potential formatting
            (r'\bAbstract\s*[:.-]?\s*(.+?)(?=\n\s*(?:1\.?\s*Introduction|Keywords?|Index Terms))', re.IGNORECASE | re.DOTALL),
            # Summary format
            (r'\bSummary\s*[:.-]?\s*\n(.+?)(?=\n\s*(?:1\.?\s*Introduction|Background))', re.IGNORECASE | re.DOTALL),
        ]
        
        for pattern, flags in abstract_patterns:
            match = re.search(pattern, text, flags)
            if match:
                abstract = match.group(1).strip()
                
                # Clean the abstract
                abstract = self._clean_abstract_text(abstract)
                
                # Validate abstract
                if abstract and 50 < len(abstract) < 2000:
                    return abstract
        
        return None
    
    def _clean_abstract_text(self, text: str) -> str:
        """Clean abstract text with comprehensive fixes"""
        # Remove page numbers and headers
        text = re.sub(r'^\d+\s*$', '', text, flags=re.MULTILINE)
        text = re.sub(r'\n\d+\n', '\n', text)
        
        # Fix word spacing issues more aggressively
        # Add spaces between words that commonly get merged
        problem_patterns = [
            # Common word endings followed by new words
            (r'(ing|ion|tion|ment|ness|ity|ence|ance)([A-Z][a-z])', r'\1 \2'),
            (r'(ing|ion|tion|ment|ness|ity|ence|ance)(the|and|of|to|in|for|with)', r'\1 \2'),
            # Common prepositions/articles that get merged
            (r'([a-z])(the|and|of|to|in|is|for|with|as|on|at|by|from)', r'\1 \2'),
            (r'(the|and|of|to|in|is|for|with|as|on|at|by|from)([A-Z])', r'\1 \2'),
        ]
        
        for pattern, replacement in problem_patterns:
            text = re.sub(pattern, replacement, text)
        
        # Fix specific technical terms that often get merged
        technical_fixes = [
            (r'neuralnetwork', 'neural network'),
            (r'machinelearning', 'machine learning'),
            (r'deeplearning', 'deep learning'),
            (r'artificialintelligence', 'artificial intelligence'),
            (r'naturallanguage', 'natural language'),
            (r'computervision', 'computer vision'),
        ]
        
        for wrong, correct in technical_fixes:
            text = re.sub(wrong, correct, text, flags=re.IGNORECASE)
        
        # Remove line breaks within sentences
        text = re.sub(r'([a-z,])\s*\n\s*([a-z])', r'\1 \2', text)
        
        # Fix spacing around punctuation
        text = re.sub(r'\s+([.,;:!?])', r'\1', text)
        text = re.sub(r'([.,;:!?])([A-Za-z])', r'\1 \2', text)
        
        # Clean up whitespace
        text = re.sub(r'\s+', ' ', text)
        
        return text.strip()