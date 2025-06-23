#!/usr/bin/env python3
"""
Update path references in scripts after moving them to scripts/ directory
"""

import os
import re

def update_paths_in_file(filepath):
    """Update path references in a single file"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Update common path patterns
    replacements = [
        # Server paths
        (r'(["\'])server/', r'\1../server/'),
        (r'(["\'])./server/', r'\1../server/'),
        
        # Elm-app paths
        (r'(["\'])elm-app/', r'\1../elm-app/'),
        (r'(["\'])./elm-app/', r'\1../elm-app/'),
        
        # Venv paths
        (r'(["\'])venv/', r'\1../venv/'),
        (r'(["\'])./venv/', r'\1../venv/'),
        
        # Update sys.path inserts
        (r'sys\.path\.insert\(0, (["\'])server(["\'])\)', r'sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "server"))'),
        
        # Already relative paths that need ../ prefix
        (r'path="server/', r'path="../server/'),
        (r'db_path="server/', r'db_path="../server/'),
    ]
    
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)
    
    # Don't update if no changes were made
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated: {os.path.basename(filepath)}")
        return True
    return False

def main():
    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    updated_count = 0
    
    for filename in os.listdir(scripts_dir):
        if filename.endswith('.py') and filename != 'update_paths.py':
            filepath = os.path.join(scripts_dir, filename)
            if update_paths_in_file(filepath):
                updated_count += 1
    
    print(f"\nUpdated {updated_count} files")

if __name__ == "__main__":
    main()