#!/usr/bin/env python3
"""
Wrapper to run generate_abstracts.py with correct Python path
"""

import sys
import os

# Add server directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'server'))

# Now import and run the main script
from server.generate_abstracts import main

if __name__ == "__main__":
    main()