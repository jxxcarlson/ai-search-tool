#!/usr/bin/env python3
"""
Stop the AI Search Tool services
"""
import subprocess
import sys
import time
import argparse
import socket
import psutil
import os
import signal

# ANSI color codes
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
RED = '\033[0;31m'
YELLOW = '\033[0;33m'
NC = '\033[0m'  # No Color

def is_port_in_use(port):
    """Check if a port is in use"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('localhost', port))
    sock.close()
    return result == 0

def find_process_by_port(port):
    """Find process using a specific port"""
    try:
        import psutil
        for conn in psutil.net_connections():
            if conn.laddr.port == port and conn.status == 'LISTEN':
                return conn.pid
    except ImportError:
        # Fallback for systems without psutil
        if sys.platform == "win32":
            # Windows netstat command
            try:
                result = subprocess.run(['netstat', '-ano'], capture_output=True, text=True)
                for line in result.stdout.splitlines():
                    if f':{port}' in line and 'LISTENING' in line:
                        parts = line.split()
                        return int(parts[-1])
            except:
                pass
        else:
            # Unix-like systems
            try:
                result = subprocess.run(['lsof', '-ti', f':{port}'], capture_output=True, text=True)
                if result.stdout.strip():
                    return int(result.stdout.strip().split()[0])
            except:
                pass
    return None

def stop_service(port, service_name):
    """Stop a service running on a specific port"""
    if not is_port_in_use(port):
        print(f"{YELLOW}No {service_name} found on port {port}{NC}")
        return True
    
    pid = find_process_by_port(port)
    if not pid:
        print(f"{YELLOW}Could not find PID for {service_name} on port {port}{NC}")
        return False
    
    print(f"{BLUE}Stopping {service_name} on port {port} (PID: {pid})...{NC}")
    
    try:
        # Try graceful shutdown first
        if sys.platform == "win32":
            # Windows
            subprocess.run(['taskkill', '/PID', str(pid)], check=False)
        else:
            # Unix-like
            os.kill(pid, signal.SIGTERM)
        
        # Wait up to 5 seconds for graceful shutdown
        for i in range(5):
            if not is_port_in_use(port):
                print(f"{GREEN}✓ {service_name} stopped successfully{NC}")
                return True
            time.sleep(1)
        
        # Force kill if still running
        print(f"{YELLOW}Force stopping {service_name}...{NC}")
        if sys.platform == "win32":
            subprocess.run(['taskkill', '/F', '/PID', str(pid)], check=False)
        else:
            os.kill(pid, signal.SIGKILL)
        
        time.sleep(1)
        
        if not is_port_in_use(port):
            print(f"{GREEN}✓ {service_name} stopped{NC}")
            return True
        else:
            print(f"{RED}✗ Failed to stop {service_name}{NC}")
            return False
            
    except Exception as e:
        print(f"{RED}Error stopping {service_name}: {e}{NC}")
        return False

def find_and_stop_process_by_name(process_name):
    """Find and stop processes by name pattern"""
    found = False
    try:
        import psutil
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if process_name in cmdline and 'stop.py' not in cmdline:
                    print(f"{BLUE}Found {process_name} process (PID: {proc.info['pid']})...{NC}")
                    proc.terminate()
                    found = True
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except ImportError:
        # Fallback without psutil
        if sys.platform != "win32":
            try:
                result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
                for line in result.stdout.splitlines():
                    if process_name in line and 'stop.py' not in line and 'grep' not in line:
                        parts = line.split()
                        if len(parts) > 1:
                            pid = parts[1]
                            print(f"{BLUE}Found {process_name} process (PID: {pid})...{NC}")
                            try:
                                os.kill(int(pid), signal.SIGTERM)
                                found = True
                            except:
                                pass
            except:
                pass
    
    return found

def main():
    parser = argparse.ArgumentParser(description='Stop the AI Search Tool services')
    parser.add_argument('--api-port', type=int, default=8010, 
                       help='API server port to stop (default: 8010)')
    parser.add_argument('--web-port', type=int, default=8080, 
                       help='Web server port to stop (default: 8080)')
    args = parser.parse_args()
    
    print(f"{BLUE}Stopping AI Search Tool services...{NC}")
    
    # Stop the services
    api_stopped = stop_service(args.api_port, "API server")
    web_stopped = stop_service(args.web_port, "Web server")
    
    # Also look for any Python processes running our scripts
    print(f"{BLUE}Checking for related Python processes...{NC}")
    
    # Find processes running server.py
    server_found = find_and_stop_process_by_name("server.py")
    
    # Find processes running http.server
    http_found = find_and_stop_process_by_name("http.server")
    
    # Wait a moment for processes to terminate
    if server_found or http_found:
        time.sleep(1)
    
    # Summary
    print()
    if api_stopped and web_stopped:
        print(f"{GREEN}✓ All services stopped successfully{NC}")
        sys.exit(0)
    else:
        print(f"{YELLOW}⚠ Some services may not have stopped properly{NC}")
        print(f"{YELLOW}  You can check for remaining processes with:{NC}")
        if sys.platform == "win32":
            print(f"{YELLOW}  netstat -ano | findstr :{args.api_port}{NC}")
            print(f"{YELLOW}  netstat -ano | findstr :{args.web_port}{NC}")
        else:
            print(f"{YELLOW}  lsof -i:{args.api_port}{NC}")
            print(f"{YELLOW}  lsof -i:{args.web_port}{NC}")
        sys.exit(1)

if __name__ == "__main__":
    # Check if psutil is available and suggest installing it if not
    try:
        import psutil
    except ImportError:
        print(f"{YELLOW}Note: Installing 'psutil' will improve process management:{NC}")
        print(f"{YELLOW}  pip install psutil{NC}")
        print()
    
    main()