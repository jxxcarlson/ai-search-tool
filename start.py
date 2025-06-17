#!/usr/bin/env python3
"""
Start the AI Search Tool - launches both API and web servers
"""
import subprocess
import sys
import time
import signal
import os
import argparse
from pathlib import Path
import socket

# ANSI color codes
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color

# Global process references
api_process = None
web_process = None

def is_port_open(port):
    """Check if a port is available"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('localhost', port))
    sock.close()
    return result != 0

def cleanup(signum=None, frame=None):
    """Clean up processes on exit"""
    print(f"\n{BLUE}Shutting down services...{NC}")
    
    if api_process:
        api_process.terminate()
        try:
            api_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            api_process.kill()
    
    if web_process:
        web_process.terminate()
        try:
            web_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            web_process.kill()
    
    print(f"{GREEN}Services stopped.{NC}")
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(description='Start the AI Search Tool')
    parser.add_argument('--api-port', type=int, default=8010, help='API server port (default: 8010)')
    parser.add_argument('--web-port', type=int, default=8080, help='Web server port (default: 8080)')
    parser.add_argument('--clean', '--reset', action='store_true', help='Start with a clean database (deletes all data)')
    args = parser.parse_args()
    
    global api_process, web_process
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    
    print(f"{BLUE}Starting AI Search Tool...{NC}")
    
    # Handle clean start if requested
    if args.clean:
        print(f"\n{RED}⚠️  Clean start requested!{NC}")
        print(f"{RED}This will delete all documents and data.{NC}")
        response = input("Are you sure you want to continue? (yes/N): ")
        
        if response.lower() != 'yes':
            print(f"{RED}Clean start cancelled.{NC}")
            sys.exit(0)
        
        print(f"{BLUE}Resetting database...{NC}")
        result = subprocess.run([sys.executable, "reset_database.py", "--confirm"])
        
        if result.returncode != 0:
            print(f"{RED}Failed to reset database!{NC}")
            sys.exit(1)
        
        print(f"{GREEN}✓ Database reset complete{NC}")
        print()
    
    # Check if virtual environment exists
    if not Path("venv").exists():
        print(f"{RED}Virtual environment not found!{NC}")
        print("Please run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt")
        sys.exit(1)
    
    # Check if Elm app is built
    if not Path("elm-app/main.js").exists():
        print(f"{BLUE}Building Elm application...{NC}")
        try:
            subprocess.run(["elm", "make", "src/Main.elm", "--output=main.js"], 
                         cwd="elm-app", check=True)
        except subprocess.CalledProcessError:
            print(f"{RED}Elm build failed!{NC}")
            sys.exit(1)
        except FileNotFoundError:
            print(f"{RED}Elm not found! Please install Elm: npm install -g elm{NC}")
            sys.exit(1)
    
    # Check if ports are available
    if not is_port_open(args.api_port):
        print(f"{RED}Port {args.api_port} is already in use!{NC}")
        sys.exit(1)
    
    if not is_port_open(args.web_port):
        print(f"{RED}Port {args.web_port} is already in use!{NC}")
        sys.exit(1)
    
    # Update API URL in index.html if using non-default port
    if args.api_port != 8010:
        print(f"{BLUE}Updating API URL in Elm app...{NC}")
        index_path = Path("elm-app/index.html")
        content = index_path.read_text()
        import re
        content = re.sub(r'http://localhost:\d+', f'http://localhost:{args.api_port}', content)
        index_path.write_text(content)
    
    # Start API server
    print(f"{BLUE}Starting API server on port {args.api_port}...{NC}")
    
    # Determine the Python executable in the virtual environment
    if sys.platform == "win32":
        python_exe = "venv\\Scripts\\python.exe"
    else:
        python_exe = "venv/bin/python"
    
    api_process = subprocess.Popen([python_exe, "server/server.py", str(args.api_port)])
    
    # Wait for API server to start
    for i in range(10):
        time.sleep(1)
        if not is_port_open(args.api_port):
            break
    else:
        print(f"{RED}API server failed to start!{NC}")
        cleanup()
    
    # Start web server
    print(f"{BLUE}Starting web server on port {args.web_port}...{NC}")
    web_process = subprocess.Popen([sys.executable, "-m", "http.server", str(args.web_port)], 
                                 cwd="elm-app")
    
    # Wait for web server to start
    time.sleep(2)
    
    print(f"{GREEN}✓ AI Search Tool is running!{NC}")
    print(f"{GREEN}✓ Web interface: http://localhost:{args.web_port}{NC}")
    print(f"{GREEN}✓ API server: http://localhost:{args.api_port}{NC}")
    print(f"\nPress Ctrl+C to stop all services")
    
    # Keep the script running
    try:
        while True:
            time.sleep(1)
            # Check if processes are still running
            if api_process.poll() is not None:
                print(f"{RED}API server stopped unexpectedly!{NC}")
                cleanup()
            if web_process.poll() is not None:
                print(f"{RED}Web server stopped unexpectedly!{NC}")
                cleanup()
    except KeyboardInterrupt:
        cleanup()

if __name__ == "__main__":
    main()