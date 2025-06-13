#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Default ports
API_PORT=8010
WEB_PORT=8080

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-port)
      API_PORT="$2"
      shift 2
      ;;
    --web-port)
      WEB_PORT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./stop.sh [OPTIONS]"
      echo "Options:"
      echo "  --api-port PORT    API server port to stop (default: 8010)"
      echo "  --web-port PORT    Web server port to stop (default: 8080)"
      echo "  -h, --help         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}Stopping AI Search Tool services...${NC}"

# Function to stop a service on a port
stop_service() {
    local port=$1
    local service_name=$2
    
    # Find PIDs using the port
    local pids=$(lsof -ti:$port 2>/dev/null)
    
    if [ -z "$pids" ]; then
        echo -e "${YELLOW}No $service_name found on port $port${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Stopping $service_name on port $port (PID: $pids)...${NC}"
    
    # Try graceful shutdown first
    kill $pids 2>/dev/null
    
    # Wait up to 5 seconds for graceful shutdown
    local count=0
    while [ $count -lt 5 ]; do
        if ! lsof -ti:$port >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name stopped successfully${NC}"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    # Force kill if still running
    echo -e "${YELLOW}Force stopping $service_name...${NC}"
    kill -9 $pids 2>/dev/null
    sleep 1
    
    if ! lsof -ti:$port >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $service_name stopped${NC}"
    else
        echo -e "${RED}✗ Failed to stop $service_name${NC}"
        return 1
    fi
}

# Stop the services
stop_service $API_PORT "API server"
api_result=$?

stop_service $WEB_PORT "Web server"
web_result=$?

# Also look for any Python processes running our scripts
echo -e "${BLUE}Checking for related Python processes...${NC}"

# Find processes running server.py
server_pids=$(ps aux | grep -E "python.*server\.py" | grep -v grep | awk '{print $2}')
if [ ! -z "$server_pids" ]; then
    echo -e "${BLUE}Found server.py processes: $server_pids${NC}"
    kill $server_pids 2>/dev/null
    sleep 1
fi

# Find processes running http.server in elm-app directory
http_server_pids=$(ps aux | grep -E "python.*http\.server.*elm-app" | grep -v grep | awk '{print $2}')
if [ ! -z "$http_server_pids" ]; then
    echo -e "${BLUE}Found http.server processes: $http_server_pids${NC}"
    kill $http_server_pids 2>/dev/null
    sleep 1
fi

# Summary
echo
if [ $api_result -eq 0 ] && [ $web_result -eq 0 ]; then
    echo -e "${GREEN}✓ All services stopped successfully${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some services may not have stopped properly${NC}"
    echo -e "${YELLOW}  You can check for remaining processes with:${NC}"
    echo -e "${YELLOW}  lsof -i:$API_PORT${NC}"
    echo -e "${YELLOW}  lsof -i:$WEB_PORT${NC}"
    exit 1
fi