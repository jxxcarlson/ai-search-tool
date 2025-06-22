"""
Abstract extraction utilities for various document types
"""

import re
from typing import Optional, Tuple
import PyPDF2
import io
from anthropic import Anthropic
import config


class AbstractExtractor:
    def __init__(self, anthropic_client: Optional[Anthropic] = None):
        self.anthropic_client = anthropic_client
    
    def extract_abstract(self, content: str, doc_type: str, title: str = "") -> Tuple[Optional[str], Optional[str]]:
        """
        Extract or generate an abstract for a document.
        Returns tuple of (abstract, source)
        """
        # Try extraction methods first
        abstract, source = self._try_extract_abstract(content, doc_type)
        
        if abstract:
            return abstract, source
        
        # Fallback to AI generation if available
        if self.anthropic_client:
            abstract = self._generate_abstract_with_claude(content, doc_type, title)
            if abstract:
                return abstract, "ai_generated"
        
        # Last resort: extract first paragraph
        abstract = self._extract_first_paragraph(content)
        return abstract, "first_paragraph" if abstract else None
    
    def _try_extract_abstract(self, content: str, doc_type: str) -> Tuple[Optional[str], Optional[str]]:
        """Try to extract abstract from document structure"""
        
        # For PDFs, first clean the content to fix extraction issues
        if doc_type == "pdf":
            # Apply basic cleaning to the entire content first
            content = content.replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('ﬀ', 'ff')
            content = content.replace('ﬃ', 'ffi').replace('ﬄ', 'ffl')
        
        # Common abstract patterns - updated for better matching
        abstract_patterns = [
            # Academic papers - handle various formats
            # Look for Abstract section with flexible spacing
            (r'(?:^|\n)\s*Abstract\s*[\n\s]+((?:[^\n][\n]?)+?)(?:\n\s*(?:1\.?\s*Introduction|Keywords?|Index Terms|I\.\s*INTRODUCTION|\n1\s+Introduction))', re.IGNORECASE | re.DOTALL),
            # Some papers have abstract without explicit "Abstract" header
            (r'^((?:[A-Z][^.!?]*[.!?]\s*){3,})(?:\n\s*(?:1\.?\s*Introduction|Keywords?|Index Terms))', re.MULTILINE | re.DOTALL),
            # Summary patterns
            (r'(?:^|\n)\s*Summary\s*[\n\s]+(.*?)(?:\n\s*(?:Introduction|1\.|I\.))', re.IGNORECASE | re.DOTALL),
            (r'(?:^|\n)\s*Executive Summary\s*[\n\s]+(.*?)(?:\n\s*(?:Introduction|Background|1\.|I\.))', re.IGNORECASE | re.DOTALL),
            # Markdown style
            (r'(?:^|\n)#+\s*Abstract\s*\n+(.*?)(?:\n#|\n\n#|$)', re.IGNORECASE | re.DOTALL),
            (r'(?:^|\n)#+\s*Summary\s*\n+(.*?)(?:\n#|\n\n#|$)', re.IGNORECASE | re.DOTALL),
        ]
        
        for pattern, flags in abstract_patterns:
            match = re.search(pattern, content, flags)
            if match:
                abstract = match.group(1).strip()
                
                # For PDFs, check if we need to extract from a text block
                if doc_type == "pdf" and len(abstract) > 1500:
                    # Might have grabbed too much, try to find the real end
                    # Look for common end markers
                    end_markers = [
                        r'\n\s*Keywords?:',
                        r'\n\s*Index Terms:',
                        r'\n\s*Categories and Subject Descriptors',
                        r'\n\s*\d+\s*Introduction',
                        r'\n\s*1\.\s*Introduction',
                        r'\n\s*I\.\s*INTRODUCTION'
                    ]
                    
                    for end_marker in end_markers:
                        end_match = re.search(end_marker, abstract, re.IGNORECASE)
                        if end_match:
                            abstract = abstract[:end_match.start()]
                            break
                
                # Clean up the abstract
                abstract = self._clean_abstract(abstract)
                
                # Final validation
                if abstract and len(abstract) > 50 and len(abstract) < 2000:  # Reasonable length
                    return abstract, "extracted"
        
        return None, None
    
    def _clean_abstract(self, text: str) -> str:
        """Clean up extracted abstract text"""
        # First, fix common PDF extraction issues
        
        # Fix merged words by adding spaces before capital letters that follow lowercase
        # but preserve acronyms and proper formatting
        text = re.sub(r'([a-z])([A-Z])', r'\1 \2', text)
        
        # Fix specific patterns from academic PDFs
        # Fix "ﬁ" ligature and other common ligatures
        text = text.replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('ﬀ', 'ff')
        text = text.replace('ﬃ', 'ffi').replace('ﬄ', 'ffl')
        
        # Fix common merged words patterns
        text = re.sub(r'([a-z])(learning|networks?|models?|systems?|based|recognition)', r'\1 \2', text, flags=re.IGNORECASE)
        
        # Remove hyphenation at line breaks (but keep real hyphens)
        text = re.sub(r'([a-z])-\s*\n\s*([a-z])', r'\1\2', text)
        
        # Fix spacing around punctuation
        text = re.sub(r'\s+([.,;:!?])', r'\1', text)  # Remove space before punctuation
        text = re.sub(r'([.,;:!?])([A-Za-z])', r'\1 \2', text)  # Add space after punctuation if missing
        
        # Fix spacing around parentheses
        text = re.sub(r'\s+\)', ')', text)
        text = re.sub(r'\(\s+', '(', text)
        text = re.sub(r'\)([A-Za-z])', r') \1', text)
        
        # Remove page numbers (standalone numbers)
        text = re.sub(r'\n\s*\d+\s*\n', ' ', text)
        text = re.sub(r'^\s*\d+\s*$', '', text, flags=re.MULTILINE)
        
        # Clean up multiple spaces
        text = re.sub(r'\s+', ' ', text)
        
        # Remove section headers that might have been included
        text = re.sub(r'^(1\s+)?Introduction.*?(?=[A-Z])', '', text, flags=re.IGNORECASE)
        
        return text.strip()
    
    def _extract_first_paragraph(self, content: str) -> Optional[str]:
        """Extract the first substantial paragraph as abstract"""
        # Split into paragraphs
        paragraphs = re.split(r'\n\s*\n', content.strip())
        
        for paragraph in paragraphs:
            # Skip very short paragraphs (likely titles or headers)
            if len(paragraph) < 100:
                continue
            # Skip paragraphs that look like metadata
            if re.match(r'^(Page|Chapter|Section|\d+)', paragraph, re.IGNORECASE):
                continue
            # Found a good paragraph
            return self._clean_abstract(paragraph)[:500]  # Limit length
        
        # If no good paragraph found, return beginning of content
        if len(content) > 100:
            return self._clean_abstract(content[:500])
        return None
    
    def _generate_abstract_with_claude(self, content: str, doc_type: str, title: str) -> Optional[str]:
        """Generate abstract using Claude API"""
        if not self.anthropic_client:
            return None
        
        try:
            # Limit content length to avoid token limits
            max_content_length = 4000
            if len(content) > max_content_length:
                # Take beginning and end to capture introduction and conclusion
                content_sample = content[:2000] + "\n\n[...]\n\n" + content[-2000:]
            else:
                content_sample = content
            
            # Customize prompt based on document type
            if doc_type == "pdf":
                prompt_type = "academic or technical document"
            elif doc_type == "md":
                prompt_type = "markdown document"
            else:
                prompt_type = "document"
            
            prompt = f"""Generate an abstract for this {prompt_type}. Summarize the main points, key findings, and significance. Do not include any preamble or meta-commentary about the abstract itself. Start directly with the content summary.

Title: {title}

Content:
{content_sample}

Abstract:"""
            
            response = self.anthropic_client.messages.create(
                model="claude-3-haiku-20240307",  # Use faster, cheaper model for abstracts
                max_tokens=400,
                temperature=0.3,  # Lower temperature for more focused summaries
                messages=[{"role": "user", "content": prompt}]
            )
            
            abstract = response.content[0].text.strip()
            
            # Remove common boilerplate patterns
            boilerplate_patterns = [
                r'^Here is a (?:concise )?abstract[^:]*:\s*',
                r'^This (?:document|paper|article) provides[^.]+\.\s*',
                r'^(?:The following is |This is )?(?:a |an )?(?:\d+-word )?(?:abstract|summary)[^:]*:\s*',
                r'^Abstract:\s*',
            ]
            
            for pattern in boilerplate_patterns:
                abstract = re.sub(pattern, '', abstract, flags=re.IGNORECASE)
            
            # Also remove if it starts with "This document" and continues about what the document does
            if abstract.lower().startswith("this document"):
                # Find the end of the first sentence
                first_period = abstract.find('. ')
                if first_period > 0 and first_period < 150:  # Reasonable length for a meta-sentence
                    # Check if it's talking about the document itself
                    first_sentence = abstract[:first_period].lower()
                    if any(word in first_sentence for word in ['provides', 'presents', 'describes', 'explains', 'discusses', 'outlines']):
                        abstract = abstract[first_period + 2:].strip()
            
            return abstract if abstract else None
            
        except Exception as e:
            print(f"Error generating abstract with Claude: {e}")
            return None
    
    def extract_pdf_abstract(self, pdf_content: bytes) -> Tuple[Optional[str], Optional[str]]:
        """
        Extract abstract specifically from PDF content.
        First tries metadata, then content extraction.
        """
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_content))
            
            # Try metadata first
            if pdf_reader.metadata:
                # Some PDFs store abstract in metadata
                abstract = None
                for key in ['/Subject', '/Description', '/Abstract']:
                    if key in pdf_reader.metadata:
                        abstract = pdf_reader.metadata[key]
                        if abstract and len(abstract) > 50:
                            return abstract.strip(), "extracted"
            
            # Extract text from first few pages to look for abstract
            text_content = ""
            for page_num in range(min(5, len(pdf_reader.pages))):
                text_content += pdf_reader.pages[page_num].extract_text() + "\n\n"
            
            # Try to extract abstract from content
            return self._try_extract_abstract(text_content, "pdf")
            
        except Exception as e:
            print(f"Error extracting PDF abstract: {e}")
            return None, None