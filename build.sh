#!/usr/bin/env bash

# Android Common Kernel Build Script
# Based on reference implementation for successful kernel compilation

DEVICE_CODENAME="stone"
DEVICE_NAME="POCO X5 5G"
KERNEL_NAME="Rebased-Black"
KERNEL_DEFCONFIG="stone_defconfig"
ANYKERNEL_DIR="$PWD/anykernel"
BUILD_TYPE="RELEASE"

# Initialize logging
LOG_FILE="build.log"
BUILD_START_TIME=$(date)
echo "Build started at: $BUILD_START_TIME" > "$LOG_FILE"
echo "Device: $DEVICE_NAME ($DEVICE_CODENAME)" >> "$LOG_FILE"
echo "Kernel: $KERNEL_NAME" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Print colored output and log
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

check_and_install_dependencies() {
    print_status "Checking dependencies..."

    local required_packages=(
        "build-essential" "libncurses-dev" "flex" "bison"
        "libssl-dev" "bc" "curl" "wget" "unzip" "zip"
        "git" "llvm" "clang" "lld" "gcc-aarch64-linux-gnu"
        "gcc-arm-linux-gnueabi"
    )

    if command -v apt-get &> /dev/null; then
        print_status "Detected Debian/Ubuntu-based system"
        sudo apt-get update

        local missing_packages=()
        for package in "${required_packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package "; then
                missing_packages+=("$package")
            fi
        done

        if [ ${#missing_packages[@]} -gt 0 ]; then
            print_status "Installing missing packages: ${missing_packages[*]}"
            sudo apt-get install -y "${missing_packages[@]}"
        else
            print_status "All required packages are already installed"
        fi
    else
        print_error "Unsupported package manager. Please install dependencies manually:"
        print_error "Required packages: ${required_packages[*]}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    local required_tools=("make" "gcc" "clang" "ld.lld" "llvm-ar" "llvm-nm" "llvm-objcopy" "llvm-strip" "aarch64-linux-gnu-gcc" "arm-linux-gnueabi-gcc")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install them and try again"
        exit 1
    else
        print_status "All required tools are available"
    fi

    print_status "Dependency check completed successfully!"
}

setup_clang() {
    if command -v clang &> /dev/null; then
        COMPILER_STRING="$(clang --version | head -n 1)"
        print_status "Compiler: $COMPILER_STRING"
    else
        print_error "Clang compiler not found!"
        exit 1
    fi
}

export ARCH=arm64
export LLVM=1
export LLVM_IAS=1
export KBUILD_BUILD_USER="Black"
export KBUILD_BUILD_HOST="X"

compile_kernel() {
    print_status "Building kernel..."
    mkdir -p out

    if [ ! -f "arch/arm64/configs/$KERNEL_DEFCONFIG" ]; then
        print_error "$KERNEL_DEFCONFIG not found!"
        exit 1
    fi

    print_status "Configuring kernel with $KERNEL_DEFCONFIG..."
    make O=out "$KERNEL_DEFCONFIG"
    print_status "Running non-interactive configuration..."
    make O=out olddefconfig

    print_status "Generating OID registry data..."
    mkdir -p out/lib
    perl lib/build_OID_registry include/linux/oid_registry.h out/lib/oid_registry_data.c

    if [ ! -s "out/lib/oid_registry_data.c" ]; then
        print_error "Failed to generate OID registry data!"
        exit 1
    fi

    print_status "OID registry data generated successfully."
    print_status "Compiling kernel with all available CPU cores..."

    if make -j"$(nproc --all)" O=out Image -i \
        CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
        OBJCOPY=llvm-objcopy STRIP=llvm-strip \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-; then
        print_status "Kernel Image compilation successful!"
    else
        print_status "Image build failed, trying alternative compilation..."
        make -j"$(nproc --all)" O=out -i \
            CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
            OBJCOPY=llvm-objcopy STRIP=llvm-strip \
            CLANG_TRIPLE=aarch64-linux-gnu- \
            CROSS_COMPILE=aarch64-linux-gnu- \
            CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    fi

    if [ -f "out/arch/arm64/boot/Image" ] || [ -f "out/arch/arm64/boot/Image.gz" ]; then
        print_status "Kernel compilation completed successfully!"
    else
        print_error "Kernel compilation failed!"
        exit 1
    fi
}

# Store original directory and setup cleanup trap
ORIGINAL_DIR=$(pwd)
STATIC_ANYKERNEL_DIR="$ORIGINAL_DIR/anykernel"
BACKUP_DIR="$ORIGINAL_DIR/.anykernel_backup"

cleanup_anykernel() {
    cd "$ORIGINAL_DIR" 2>/dev/null || true

    # Only restore if backup exists
    if [ -d "$BACKUP_DIR" ]; then
        # Remove any files that were added during build process
        rm -f "$STATIC_ANYKERNEL_DIR/Image" "$STATIC_ANYKERNEL_DIR/Image.gz" "$STATIC_ANYKERNEL_DIR/dtbo.img"
        rm -f "$STATIC_ANYKERNEL_DIR/Image.bak" "$STATIC_ANYKERNEL_DIR/Image.gz.bak" "$STATIC_ANYKERNEL_DIR/dtbo.img.bak"

        # Restore original files from backup
        if [ -f "$BACKUP_DIR/Image" ]; then
            cp "$BACKUP_DIR/Image" "$STATIC_ANYKERNEL_DIR/Image"
        fi
        if [ -f "$BACKUP_DIR/Image.gz" ]; then
            cp "$BACKUP_DIR/Image.gz" "$STATIC_ANYKERNEL_DIR/Image.gz"
        fi
        if [ -f "$BACKUP_DIR/dtbo.img" ]; then
            cp "$BACKUP_DIR/dtbo.img" "$STATIC_ANYKERNEL_DIR/dtbo.img"
        fi

        # Remove backup directory
        rm -rf "$BACKUP_DIR"
    fi
}

package_zip() {
    [ ! -f "out/arch/arm64/boot/Image" ] && {
        if [ ! -f "out/arch/arm64/boot/Image.gz" ]; then
            print_error "Kernel Image or Image.gz missing!"
            exit 1
        fi
    }

    print_status "Packaging kernel..."
    if [ ! -d "$STATIC_ANYKERNEL_DIR" ]; then
        print_error "Static AnyKernel directory does not exist at $STATIC_ANYKERNEL_DIR"
        exit 1
    fi

    # Create backup of original files
    rm -rf "$BACKUP_DIR"  # Clean any old backup
    mkdir -p "$BACKUP_DIR"
    cp -a "$STATIC_ANYKERNEL_DIR/Image" "$BACKUP_DIR/" 2>/dev/null || true
    cp -a "$STATIC_ANYKERNEL_DIR/Image.gz" "$BACKUP_DIR/" 2>/dev/null || true
    cp -a "$STATIC_ANYKERNEL_DIR/dtbo.img" "$BACKUP_DIR/" 2>/dev/null || true

    # Set trap to restore original files on exit (success or failure)
    trap cleanup_anykernel EXIT

    print_status "Using static AnyKernel directory directly..."

    # Remove old build artifacts from static directory
    rm -f "$STATIC_ANYKERNEL_DIR/Image" "$STATIC_ANYKERNEL_DIR/Image.gz" "$STATIC_ANYKERNEL_DIR/dtbo.img"

    if [ -f "out/arch/arm64/boot/Image" ]; then
        cp "out/arch/arm64/boot/Image" "$STATIC_ANYKERNEL_DIR/"
        print_status "Copied Image to AnyKernel directory"
    elif [ -f "out/arch/arm64/boot/Image.gz" ]; then
        cp "out/arch/arm64/boot/Image.gz" "$STATIC_ANYKERNEL_DIR/"
        print_status "Copied Image.gz to AnyKernel directory"
    fi

    if [ -f "out/arch/arm64/boot/dtbo.img" ]; then
        cp "out/arch/arm64/boot/dtbo.img" "$STATIC_ANYKERNEL_DIR/"
        print_status "Copied dtbo.img to AnyKernel directory"
    fi

    cd "$STATIC_ANYKERNEL_DIR" || exit 1
    sed -i "s|kernel.string=.*|kernel.string=${DEVICE_NAME}|g" anykernel.sh
    sed -i 's|do.devicecheck=.*|do.devicecheck=0|' anykernel.sh

    zip -r9 "../${KERNEL_NAME}-${DEVICE_CODENAME}-$(date '+%Y%m%d').zip" * -x .git README.md

    # Clean up build artifacts before restoring originals
    rm -f "$STATIC_ANYKERNEL_DIR/Image" "$STATIC_ANYKERNEL_DIR/Image.gz" "$STATIC_ANYKERNEL_DIR/dtbo.img"
    cd "$ORIGINAL_DIR"  # Return to original directory for zip check

    ZIP_NAME="${KERNEL_NAME}-${DEVICE_CODENAME}-$(date '+%Y%m%d').zip"
    if [ -f "$ZIP_NAME" ]; then
        print_status "Flashable zip created in project root directory: $ZIP_NAME"
    else
        print_error "Flashable zip not found in project root!"
        exit 1
    fi

    # Since we're using a trap handler, the cleanup_anykernel function will be called automatically
    # when the script exits, so we don't need to call it manually or remove the trap.
}

build_start_time=$(date +%s)
print_status "Build started at: $build_start_time"

check_and_install_dependencies
setup_clang
compile_kernel
package_zip

build_end_time=$(date +%s)
build_duration=$((build_end_time - build_start_time))
print_status "Build completed successfully in $build_duration seconds!"
echo "Build log saved to: $LOG_FILE"
