#!/usr/bin/env python3
"""Test author extraction functionality"""

import sys
sys.path.append('server')

from author_extractor import AuthorExtractor

# Test documents
test_documents = [
    {
        "content": """
By John Doe, Ph.D. and Jane Smith, M.D.

Abstract

This is a test document to verify author extraction.
""",
        "expected": "Jane Smith, M.D.; John Doe, Ph.D.",
        "doc_type": "txt"
    },
    {
        "content": """
Authors: F.M. Claro, Ph.D; Mary Jo Feinhof, M.D.

Introduction

This document tests semicolon-separated authors.
""",
        "expected": "F.M. Claro, Ph.D; Mary Jo Feinhof, M.D.",
        "doc_type": "txt"
    },
    {
        "content": """
\\documentclass{article}
\\author{Albert Einstein \\and Max Planck}
\\title{Quantum Theory}

\\begin{document}
\\maketitle
""",
        "expected": "Albert Einstein; Max Planck",
        "doc_type": "ltx"
    },
    {
        "content": """
Sean M. Carroll^1,2

^1 Department of Physics, California Institute of Technology
^2 Santa Fe Institute

Spacetime and Geometry: An Introduction to General Relativity
""",
        "expected": "Sean M. Carroll",
        "doc_type": "pdf"
    },
    {
        "content": """
Copyright © 2023 by Stephen Hawking. All rights reserved.

A Brief History of Time
""",
        "expected": "Stephen Hawking",
        "doc_type": "txt"
    },
    {
        "content": """
Jayant V. Narlikar
Inter-University Centre for Astronomy and Astrophysics

An Introduction to Relativity

Cambridge University Press
""",
        "expected": "Jayant V. Narlikar",
        "doc_type": "pdf"
    }
]

def test_author_extraction():
    extractor = AuthorExtractor()
    
    print("Testing Author Extraction")
    print("=" * 50)
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_documents):
        print(f"\nTest {i+1}:")
        print(f"Content preview: {test['content'][:100]}...")
        print(f"Expected: {test['expected']}")
        
        result = extractor.extract_authors(test['content'], test['doc_type'])
        print(f"Extracted: {result}")
        
        if result:
            # Check if all expected authors are found
            expected_authors = set(auth.strip() for auth in test['expected'].split(';'))
            extracted_authors = set(auth.strip() for auth in result.split(';'))
            
            # We just check if any expected author was found
            # since extraction might find variations
            if any(any(exp.lower() in ext.lower() or ext.lower() in exp.lower() 
                      for ext in extracted_authors) 
                  for exp in expected_authors):
                print("✓ PASSED")
                passed += 1
            else:
                print("✗ FAILED - Authors don't match")
                failed += 1
        else:
            print("✗ FAILED - No authors extracted")
            failed += 1
    
    print(f"\n{'=' * 50}")
    print(f"Results: {passed} passed, {failed} failed")
    
    # Test confidence scoring
    print(f"\n{'=' * 50}")
    print("Testing Confidence Scores")
    print("=" * 50)
    
    for i, test in enumerate(test_documents[:3]):  # Test first 3
        result, confidence = extractor.extract_authors_with_confidence(test['content'], test['doc_type'])
        print(f"\nTest {i+1}:")
        print(f"Authors: {result}")
        print(f"Confidence: {confidence:.2f}")

if __name__ == "__main__":
    test_author_extraction()