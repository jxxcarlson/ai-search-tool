#!/bin/bash

# Advanced AI Search Tool DMG Builder
# Includes code signing and notarization options

set -e  # Exit on error

# Load configuration from environment or use defaults
APP_NAME="${APP_NAME:-AI Search Tool}"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUNDLE_ID="${BUNDLE_ID:-com.aisearchtool.app}"
DEVELOPER_ID="${DEVELOPER_ID:-}"  # Set to your Apple Developer ID for signing
TEAM_ID="${TEAM_ID:-}"  # Set to your Apple Team ID for notarization

# Advanced options
SIGN_APP="${SIGN_APP:-false}"
NOTARIZE_APP="${NOTARIZE_APP:-false}"
CREATE_INSTALLER_PKG="${CREATE_INSTALLER_PKG:-false}"

# Build configuration
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

# Include all functions from the basic build script
source "$(dirname "$0")/build_dmg.sh" --source-only 2>/dev/null || true

# Code signing function
code_sign_app() {
    if [ "$SIGN_APP" != "true" ] || [ -z "$DEVELOPER_ID" ]; then
        print_warning "Skipping code signing (SIGN_APP=$SIGN_APP, DEVELOPER_ID=$DEVELOPER_ID)"
        return
    fi
    
    print_status "Code signing application..."
    
    # Sign all frameworks first
    find "${BUILD_DIR}/${APP_BUNDLE}" -name "*.dylib" -o -name "*.so" | while read -r lib; do
        codesign --force --sign "$DEVELOPER_ID" "$lib"
    done
    
    # Sign Python executable
    if [ -d "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/venv" ]; then
        find "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/venv" -name "python*" -type f | while read -r py; do
            codesign --force --sign "$DEVELOPER_ID" "$py"
        done
    fi
    
    # Sign the main app bundle
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --options runtime \
        --entitlements entitlements.plist \
        "${BUILD_DIR}/${APP_BUNDLE}"
    
    # Verify signature
    codesign --verify --verbose "${BUILD_DIR}/${APP_BUNDLE}"
    
    print_success "Application signed"
}

# Create entitlements file
create_entitlements() {
    print_status "Creating entitlements.plist..."
    
    cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF
    
    print_success "Entitlements created"
}

# Notarize app
notarize_app() {
    if [ "$NOTARIZE_APP" != "true" ] || [ -z "$DEVELOPER_ID" ] || [ -z "$TEAM_ID" ]; then
        print_warning "Skipping notarization"
        return
    fi
    
    print_status "Notarizing application..."
    
    # Create a zip for notarization
    ditto -c -k --keepParent "${BUILD_DIR}/${APP_BUNDLE}" "${BUILD_DIR}/${APP_BUNDLE}.zip"
    
    # Submit for notarization
    xcrun notarytool submit "${BUILD_DIR}/${APP_BUNDLE}.zip" \
        --team-id "$TEAM_ID" \
        --wait
    
    # Staple the notarization
    xcrun stapler staple "${BUILD_DIR}/${APP_BUNDLE}"
    
    rm "${BUILD_DIR}/${APP_BUNDLE}.zip"
    
    print_success "Application notarized"
}

# Create installer package
create_installer_pkg() {
    if [ "$CREATE_INSTALLER_PKG" != "true" ]; then
        return
    fi
    
    print_status "Creating installer package..."
    
    pkgbuild --root "${BUILD_DIR}" \
        --identifier "${BUNDLE_ID}" \
        --version "${APP_VERSION}" \
        --install-location "/Applications" \
        "${DIST_DIR}/${APP_NAME}-${APP_VERSION}.pkg"
    
    if [ "$SIGN_APP" = "true" ] && [ -n "$DEVELOPER_ID" ]; then
        productsign --sign "$DEVELOPER_ID" \
            "${DIST_DIR}/${APP_NAME}-${APP_VERSION}.pkg" \
            "${DIST_DIR}/${APP_NAME}-${APP_VERSION}-signed.pkg"
        mv "${DIST_DIR}/${APP_NAME}-${APP_VERSION}-signed.pkg" \
           "${DIST_DIR}/${APP_NAME}-${APP_VERSION}.pkg"
    fi
    
    print_success "Installer package created"
}

# Enhanced DMG creation with background
create_dmg_with_background() {
    print_status "Creating DMG with custom background..."
    
    mkdir -p "${DIST_DIR}"
    
    if [ -f "assets/dmg_background.png" ] && command -v create-dmg &> /dev/null; then
        # Create DMG source directory
        DMG_SOURCE="${BUILD_DIR}/dmg_source"
        mkdir -p "${DMG_SOURCE}"
        cp -r "${BUILD_DIR}/${APP_BUNDLE}" "${DMG_SOURCE}/"
        
        # Create DMG with create-dmg and background
        create-dmg \
            --volname "${APP_NAME}" \
            --volicon "assets/icon.icns" \
            --background "assets/dmg_background.png" \
            --window-pos 200 120 \
            --window-size 800 400 \
            --icon-size 100 \
            --icon "${APP_BUNDLE}" 200 200 \
            --hide-extension "${APP_BUNDLE}" \
            --app-drop-link 600 200 \
            --no-internet-enable \
            "${DIST_DIR}/${DMG_NAME}.dmg" \
            "${DMG_SOURCE}"
            
        rm -rf "${DMG_SOURCE}"
    else
        # Fallback to standard DMG creation
        create_dmg
    fi
    
    # Sign the DMG if code signing is enabled
    if [ "$SIGN_APP" = "true" ] && [ -n "$DEVELOPER_ID" ]; then
        codesign --force --sign "$DEVELOPER_ID" "${DIST_DIR}/${DMG_NAME}.dmg"
    fi
    
    print_success "DMG created: ${DIST_DIR}/${DMG_NAME}.dmg"
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --sign              Enable code signing (requires DEVELOPER_ID env var)"
    echo "  --notarize          Enable notarization (requires TEAM_ID env var)"
    echo "  --pkg               Create installer package"
    echo "  --version VERSION   Set app version (default: 1.0.0)"
    echo "  --help              Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  DEVELOPER_ID        Apple Developer ID for code signing"
    echo "  TEAM_ID             Apple Team ID for notarization"
    echo "  APP_VERSION         Application version"
    echo ""
    echo "Examples:"
    echo "  $0                           # Basic build"
    echo "  $0 --sign                    # Build with code signing"
    echo "  $0 --sign --notarize         # Build with signing and notarization"
    echo "  DEVELOPER_ID='Developer ID Application: Your Name (XXXXXXXXXX)' $0 --sign"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_APP=true
            shift
            ;;
        --notarize)
            NOTARIZE_APP=true
            SIGN_APP=true  # Notarization requires signing
            shift
            ;;
        --pkg)
            CREATE_INSTALLER_PKG=true
            shift
            ;;
        --version)
            APP_VERSION="$2"
            DMG_NAME="AI-Search-Tool-${APP_VERSION}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        --source-only)
            # Used for sourcing functions only
            return 0 2>/dev/null || exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Enhanced main build process
main_advanced() {
    echo -e "${BLUE}Building ${APP_NAME} DMG Installer (Advanced)${NC}"
    echo "=============================================="
    echo "Version: ${APP_VERSION}"
    echo "Code Signing: ${SIGN_APP}"
    echo "Notarization: ${NOTARIZE_APP}"
    echo "Create PKG: ${CREATE_INSTALLER_PKG}"
    echo
    
    check_prerequisites
    
    # Check for code signing prerequisites
    if [ "$SIGN_APP" = "true" ]; then
        if [ -z "$DEVELOPER_ID" ]; then
            print_error "DEVELOPER_ID environment variable not set"
            echo "Set it with: export DEVELOPER_ID='Developer ID Application: Your Name (XXXXXXXXXX)'"
            exit 1
        fi
        
        # Verify developer ID
        if ! security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID"; then
            print_error "Developer ID certificate not found: $DEVELOPER_ID"
            exit 1
        fi
    fi
    
    clean_build
    build_elm
    create_bundle_structure
    create_info_plist
    create_launch_script
    copy_app_files
    create_virtualenv
    create_icon
    
    if [ "$SIGN_APP" = "true" ]; then
        create_entitlements
        code_sign_app
    fi
    
    if [ "$NOTARIZE_APP" = "true" ]; then
        notarize_app
    fi
    
    create_dmg_with_background
    
    if [ "$CREATE_INSTALLER_PKG" = "true" ]; then
        create_installer_pkg
    fi
    
    # Clean up temporary files
    rm -f entitlements.plist
    
    echo
    echo -e "${GREEN}Build complete!${NC}"
    echo -e "DMG installer created at: ${DIST_DIR}/${DMG_NAME}.dmg"
    
    if [ "$CREATE_INSTALLER_PKG" = "true" ]; then
        echo -e "PKG installer created at: ${DIST_DIR}/${APP_NAME}-${APP_VERSION}.pkg"
    fi
    
    echo
    echo "To install:"
    echo "1. Open the DMG file"
    echo "2. Drag '${APP_NAME}' to the Applications folder"
    echo "3. Launch from Applications"
    
    if [ "$SIGN_APP" = "true" ]; then
        echo
        echo "The app has been code signed and can be distributed outside the App Store."
    fi
}

# Run main function if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main_advanced
fi