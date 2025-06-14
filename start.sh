#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
      echo "Usage: ./start.sh [OPTIONS]"
      echo "Options:"
      echo "  --api-port PORT    API server port (default: 8010)"
      echo "  --web-port PORT    Web server port (default: 8080)"
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

echo -e "${BLUE}Starting AI Search Tool...${NC}"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${RED}Virtual environment not found!${NC}"
    echo "Please run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# Check if Elm app is built
if [ ! -f "elm-app/main.js" ]; then
    echo -e "${BLUE}Building Elm application...${NC}"
    cd elm-app
    elm make src/Main.elm --output=main.js
    if [ $? -ne 0 ]; then
        echo -e "${RED}Elm build failed!${NC}"
        exit 1
    fi
    cd ..
fi

# Function to cleanup on exit
cleanup() {
    echo -e "\n${BLUE}Shutting down services...${NC}"
    # Kill the API server
    if [ ! -z "$API_PID" ]; then
        kill $API_PID 2>/dev/null
    fi
    # Kill the web server
    if [ ! -z "$WEB_PID" ]; then
        kill $WEB_PID 2>/dev/null
    fi
    # Kill any remaining Python processes on our ports
    lsof -ti:$API_PORT | xargs kill 2>/dev/null
    lsof -ti:$WEB_PORT | xargs kill 2>/dev/null
    echo -e "${GREEN}Services stopped.${NC}"
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start API server
echo -e "${BLUE}Starting API server on port $API_PORT...${NC}"
echo -e "${BLUE}Loading document store and model...${NC}"
source venv/bin/activate

# Check if virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    echo -e "${RED}Failed to activate virtual environment!${NC}"
    echo -e "${YELLOW}Make sure you have created a virtual environment with: python3 -m venv venv${NC}"
    exit 1
fi

# Start the server and capture output
# Export environment variables to ensure they're passed to the subprocess
export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
# Set offline mode if no internet connection
export HF_HUB_OFFLINE=1
python -u server.py $API_PORT 2>&1 | tee api_server.log &
API_PID=$!

# Wait for API server to start (give it more time for model loading)
echo -e "${BLUE}Waiting for API server to initialize...${NC}"
for i in {1..30}; do
    if lsof -i:$API_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API server started successfully${NC}"
        break
    fi
    sleep 1
done

# Check if API server is running
if ! lsof -i:$API_PORT > /dev/null 2>&1; then
    echo -e "${RED}API server failed to start!${NC}"
    echo -e "${YELLOW}Checking logs...${NC}"
    if [ -f api_server.log ]; then
        echo -e "${YELLOW}Last 10 lines of API server log:${NC}"
        tail -10 api_server.log
    fi
    
    # Check if process is still alive
    if ! kill -0 $API_PID 2>/dev/null; then
        echo -e "${RED}API server process crashed${NC}"
    fi
    
    exit 1
fi

# Update the Elm app's API URL if using non-default port
if [ "$API_PORT" != "8010" ]; then
    echo -e "${BLUE}Updating API URL in Elm app...${NC}"
    sed -i.bak "s|http://localhost:[0-9]*|http://localhost:$API_PORT|g" elm-app/index.html
fi

# Start web server
echo -e "${BLUE}Starting web server on port $WEB_PORT...${NC}"
cd elm-app
python3 -m http.server $WEB_PORT &
WEB_PID=$!
cd ..

# Wait for web server to start
sleep 2

# Check if web server is running
if ! lsof -i:$WEB_PORT > /dev/null; then
    echo -e "${RED}Web server failed to start!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AI Search Tool is running!${NC}"
echo -e "${GREEN}✓ Web interface: http://localhost:$WEB_PORT${NC}"
echo -e "${GREEN}✓ API server: http://localhost:$API_PORT${NC}"
echo -e "\nPress Ctrl+C to stop all services"

# Wait indefinitely
while true; do
    sleep 1
done