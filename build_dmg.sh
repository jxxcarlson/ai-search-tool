#!/bin/bash

# AI Search Tool DMG Builder
# Creates a professional macOS installer DMG

set -e  # Exit on error

# Configuration
APP_NAME="AI Search Tool"
APP_VERSION="1.0.0"
BUNDLE_ID="com.aisearchtool.app"
DMG_NAME="AI-Search-Tool-${APP_VERSION}"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="${APP_NAME}.app"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Clean previous builds
clean_build() {
    print_status "Cleaning previous builds..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${DIST_DIR}"
    rm -f "${DMG_NAME}.dmg"
    print_success "Clean complete"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check for npm/elm
    if ! command -v elm &> /dev/null; then
        print_warning "Elm not found. Will attempt to build without Elm compilation"
    fi
    
    # Check for create-dmg
    if ! command -v create-dmg &> /dev/null; then
        print_warning "create-dmg not found. Install with: brew install create-dmg"
        print_warning "Falling back to hdiutil"
    fi
    
    # Check for iconutil (for creating icns)
    if ! command -v iconutil &> /dev/null; then
        print_warning "iconutil not found. Will use default icon"
    fi
    
    print_success "Prerequisites check complete"
}

# Create app bundle structure
create_bundle_structure() {
    print_status "Creating app bundle structure..."
    
    mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS"
    mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources"
    mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/Frameworks"
    
    print_success "Bundle structure created"
}

# Create Info.plist
create_info_plist() {
    print_status "Creating Info.plist..."
    
    cat > "${BUILD_DIR}/${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>ai-search-tool</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 AI Search Tool. All rights reserved.</string>
</dict>
</plist>
EOF
    
    print_success "Info.plist created"
}

# Create launch script
create_launch_script() {
    print_status "Creating launch script..."
    
    cat > "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/ai-search-tool" << 'EOF'
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="${SCRIPT_DIR}/../Resources"
APP_DIR="${RESOURCES_DIR}/app"

# Set up environment
export PATH="${RESOURCES_DIR}/venv/bin:$PATH"
export PYTHONPATH="${APP_DIR}:$PYTHONPATH"

# Create user data directory if it doesn't exist
USER_DATA_DIR="${HOME}/Library/Application Support/AI Search Tool"
mkdir -p "${USER_DATA_DIR}"

# Check if this is first run and need to migrate data
if [ ! -f "${USER_DATA_DIR}/.initialized" ]; then
    # First run - set up user data directory
    if [ -d "${APP_DIR}/server/storage" ]; then
        echo "First run detected. Setting up user data..."
        cp -r "${APP_DIR}/server/storage" "${USER_DATA_DIR}/"
        touch "${USER_DATA_DIR}/.initialized"
    fi
fi

# Create symbolic link to user data in app directory
if [ -d "${USER_DATA_DIR}/storage" ]; then
    rm -rf "${APP_DIR}/server/storage"
    ln -sf "${USER_DATA_DIR}/storage" "${APP_DIR}/server/storage"
fi

# Log file location
LOG_DIR="${USER_DATA_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/ai-search-tool.log"

# Function to cleanup on exit
cleanup() {
    # Kill the API server
    if [ ! -z "$API_PID" ]; then
        kill $API_PID 2>/dev/null
    fi
    # Kill the web server  
    if [ ! -z "$WEB_PID" ]; then
        kill $WEB_PID 2>/dev/null
    fi
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start the servers
cd "${APP_DIR}"

# Activate virtual environment
source "${RESOURCES_DIR}/venv/bin/activate"

# Start API server
echo "Starting API server..." >> "${LOG_FILE}"
cd server && python server.py 8010 >> "${LOG_FILE}" 2>&1 &
API_PID=$!
cd ..

# Wait for API server to start
sleep 3

# Start web server
echo "Starting web server..." >> "${LOG_FILE}"
cd elm-app && python -m http.server 8080 >> "${LOG_FILE}" 2>&1 &
WEB_PID=$!
cd ..

# Wait a moment for servers to start
sleep 2

# Open browser
open "http://localhost:8080"

# Keep the script running
while true; do
    # Check if processes are still running
    if ! kill -0 $API_PID 2>/dev/null; then
        echo "API server stopped unexpectedly" >> "${LOG_FILE}"
        break
    fi
    if ! kill -0 $WEB_PID 2>/dev/null; then
        echo "Web server stopped unexpectedly" >> "${LOG_FILE}"
        break
    fi
    sleep 5
done
EOF
    
    chmod +x "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/ai-search-tool"
    print_success "Launch script created"
}

# Copy application files
copy_app_files() {
    print_status "Copying application files..."
    
    # Create app directory in Resources
    APP_RESOURCES="${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/app"
    mkdir -p "${APP_RESOURCES}"
    
    # Copy server files
    print_status "Copying server files..."
    cp -r server "${APP_RESOURCES}/"
    
    # Copy elm-app files
    print_status "Copying frontend files..."
    cp -r elm-app "${APP_RESOURCES}/"
    
    # Copy other necessary files
    cp requirements.txt "${APP_RESOURCES}/"
    cp -r inbox "${APP_RESOURCES}/" 2>/dev/null || true
    cp sample_documents.json "${APP_RESOURCES}/" 2>/dev/null || true
    
    # Remove development files
    find "${APP_RESOURCES}" -name "*.pyc" -delete
    find "${APP_RESOURCES}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "${APP_RESOURCES}" -name ".DS_Store" -delete
    
    print_success "Application files copied"
}

# Create virtual environment
create_virtualenv() {
    print_status "Creating virtual environment..."
    
    VENV_DIR="${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/venv"
    
    # Create virtual environment
    python3 -m venv "${VENV_DIR}"
    
    # Activate and install dependencies
    source "${VENV_DIR}/bin/activate"
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    
    # Remove unnecessary files to reduce size
    find "${VENV_DIR}" -name "*.pyc" -delete
    find "${VENV_DIR}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Virtual environment created"
}

# Build Elm frontend
build_elm() {
    print_status "Building Elm frontend..."
    
    if command -v elm &> /dev/null; then
        cd elm-app
        elm make src/Main.elm --output=main.js --optimize || elm make src/Main.elm --output=main.js
        cd ..
        print_success "Elm frontend built"
    else
        print_warning "Elm not found, using existing main.js"
    fi
}

# Create application icon
create_icon() {
    print_status "Creating application icon..."
    
    # Check if we have a source icon
    if [ -f "assets/icon.png" ]; then
        # Create iconset directory
        ICONSET="${BUILD_DIR}/AppIcon.iconset"
        mkdir -p "${ICONSET}"
        
        # Generate different sizes (if sips is available)
        if command -v sips &> /dev/null; then
            sips -z 16 16     assets/icon.png --out "${ICONSET}/icon_16x16.png"
            sips -z 32 32     assets/icon.png --out "${ICONSET}/icon_16x16@2x.png"
            sips -z 32 32     assets/icon.png --out "${ICONSET}/icon_32x32.png"
            sips -z 64 64     assets/icon.png --out "${ICONSET}/icon_32x32@2x.png"
            sips -z 128 128   assets/icon.png --out "${ICONSET}/icon_128x128.png"
            sips -z 256 256   assets/icon.png --out "${ICONSET}/icon_128x128@2x.png"
            sips -z 256 256   assets/icon.png --out "${ICONSET}/icon_256x256.png"
            sips -z 512 512   assets/icon.png --out "${ICONSET}/icon_256x256@2x.png"
            sips -z 512 512   assets/icon.png --out "${ICONSET}/icon_512x512.png"
            sips -z 1024 1024 assets/icon.png --out "${ICONSET}/icon_512x512@2x.png"
            
            # Convert to icns
            iconutil -c icns "${ICONSET}" -o "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
            rm -rf "${ICONSET}"
            print_success "Icon created"
        else
            print_warning "sips not found, using default icon"
        fi
    else
        print_warning "No icon.png found in assets/, using default icon"
    fi
}

# Create DMG
create_dmg() {
    print_status "Creating DMG..."
    
    mkdir -p "${DIST_DIR}"
    
    if command -v create-dmg &> /dev/null; then
        # Use create-dmg for a fancy DMG
        print_status "Using create-dmg..."
        
        # Create DMG source directory
        DMG_SOURCE="${BUILD_DIR}/dmg_source"
        mkdir -p "${DMG_SOURCE}"
        cp -r "${BUILD_DIR}/${APP_BUNDLE}" "${DMG_SOURCE}/"
        
        # Create DMG with create-dmg
        create-dmg \
            --volname "${APP_NAME}" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "${APP_BUNDLE}" 150 200 \
            --hide-extension "${APP_BUNDLE}" \
            --app-drop-link 450 200 \
            --no-internet-enable \
            "${DIST_DIR}/${DMG_NAME}.dmg" \
            "${DMG_SOURCE}"
            
        rm -rf "${DMG_SOURCE}"
    else
        # Fallback to hdiutil
        print_status "Using hdiutil..."
        
        # Create a temporary directory for the DMG contents
        DMG_TEMP="${BUILD_DIR}/dmg_temp"
        mkdir -p "${DMG_TEMP}"
        
        # Copy app bundle
        cp -r "${BUILD_DIR}/${APP_BUNDLE}" "${DMG_TEMP}/"
        
        # Create a symbolic link to Applications
        ln -s /Applications "${DMG_TEMP}/Applications"
        
        # Create DMG
        hdiutil create -volname "${APP_NAME}" \
            -srcfolder "${DMG_TEMP}" \
            -ov -format UDZO \
            "${DIST_DIR}/${DMG_NAME}.dmg"
            
        rm -rf "${DMG_TEMP}"
    fi
    
    print_success "DMG created: ${DIST_DIR}/${DMG_NAME}.dmg"
}

# Main build process
main() {
    echo -e "${BLUE}Building ${APP_NAME} DMG Installer${NC}"
    echo "======================================"
    
    check_prerequisites
    clean_build
    build_elm
    create_bundle_structure
    create_info_plist
    create_launch_script
    copy_app_files
    create_virtualenv
    create_icon
    create_dmg
    
    echo
    echo -e "${GREEN}Build complete!${NC}"
    echo -e "DMG installer created at: ${DIST_DIR}/${DMG_NAME}.dmg"
    echo
    echo "To install:"
    echo "1. Open the DMG file"
    echo "2. Drag 'AI Search Tool' to the Applications folder"
    echo "3. Launch from Applications"
}

# Run main function
main