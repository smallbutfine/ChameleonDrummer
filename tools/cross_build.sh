#!/bin/bash
# Cross-compile ChameleonDrummer from Windows to Linux/macOS
# Requires FPC cross-compiler packages installed on Windows

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TARGET="linux"  # linux or darwin
ARCH="x86_64"   # x86_64 or aarch64
PREFIX=""       # Cross-prefix (e.g., x86_64-linux-gnu-)
FPC_PATH="C:/lazarus/fpc/3.2.2/bin/x86_64-win64/fpc.exe"

# Usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --target TARGET    Target platform: linux (default) or darwin"
    echo "  --arch ARCH        Target architecture: x86_64 (default) or aarch64"
    echo "  --prefix PREFIX    Cross-compiler prefix (e.g., x86_64-linux-gnu-)"
    echo "  --fpc PATH         FPC compiler path (default: $FPC_PATH)"
    echo ""
    echo "Example: $0 --target linux --arch x86_64 --prefix x86_64-linux-gnu-"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --fpc)
            FPC_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate target
if [[ "$TARGET" != "linux" && "$TARGET" != "darwin" ]]; then
    echo -e "${RED}Error: Invalid target '$TARGET'. Use 'linux' or 'darwin'.${NC}"
    usage
fi

# Validate arch
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo -e "${RED}Error: Invalid arch '$ARCH'. Use 'x86_64' or 'aarch64'.${NC}"
    usage
fi

# Check if FPC exists
if [[ ! -f "$FPC_PATH" ]]; then
    echo -e "${RED}Error: FPC not found at $FPC_PATH${NC}"
    echo "Please install FPC cross-compiler packages for $TARGET $ARCH"
    echo "Or specify the correct path with --fpc"
    exit 1
fi

# Determine FPC target flag
case "$TARGET" in
    linux)
        FPC_TARGET="-Tlinux"
        ;;
    darwin)
        FPC_TARGET="-Tdarwin"
        ;;
esac

# Determine cross-prefix
if [[ -n "$PREFIX" ]]; then
    CROSS_PREFIX="-P $PREFIX"
else
    # Try to guess from target and arch
    case "$TARGET" in
        linux)
            if [[ "$ARCH" == "x86_64" ]]; then
                PREFIX="x86_64-linux-gnu-"
            else
                PREFIX="aarch64-linux-gnu-"
            fi
            ;;
        darwin)
            if [[ "$ARCH" == "x86_64" ]]; then
                PREFIX="o64-apple-darwin20-"
            else
                PREFIX="aarch64-apple-darwin21-"
            fi
            ;;
    esac
    CROSS_PREFIX="-P $PREFIX"
fi

# Build command
BUILD_CMD="$FPC_PATH $FPC_TARGET $CROSS_PREFIX -O2 -Fusrc -Sg -Sc ChameleonDrummer.lpr"

echo -e "${GREEN}Building ChameleonDrummer for $TARGET $ARCH...${NC}"
echo "Command: $BUILD_CMD"
echo ""

# Run build
if eval "$BUILD_CMD"; then
    echo -e "${GREEN}Build successful!${NC}"
    echo "Output: ChameleonDrummer.exe"
    echo ""
    echo "To run on target system:"
    echo "  Linux:   ./ChameleonDrummer.exe"
    echo "  macOS:   chmod +x ChameleonDrummer.exe && ./ChameleonDrummer.exe"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

# Cross-compile for both targets if requested
if [[ "$TARGET" == "linux" ]]; then
    echo ""
    echo -e "${YELLOW}Building for macOS as well...${NC}"
    MAC_BUILD_CMD="$FPC_PATH -Tdarwin -P o64-apple-darwin20- -O2 -Fusrc -Sg -Sc ChameleonDrummer.lpr"
    if eval "$MAC_BUILD_CMD"; then
        echo -e "${GREEN}macOS build successful!${NC}"
    else
        echo -e "${RED}macOS build failed!${NC}"
    fi
fi