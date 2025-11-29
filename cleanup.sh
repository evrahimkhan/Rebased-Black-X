#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
cleanup() {
    print_status "Starting cleanup process..."
    if [ -d "out" ]; then
        print_status "Removing build output directory..."
        rm -rf out
    else
        print_warning "Build output directory does not exist."
    fi
    print_status "Removing temporary files..."
    find . -type f -name "*.o" -delete 2>/dev/null || true
    find . -type f -name "*.cmd" -delete 2>/dev/null || true
    find . -type f -name ".*.cmd" -delete 2>/dev/null || true
    find . -type f -name "*.dwo" -delete 2>/dev/null || true
    find . -type f -name "*.mod.c" -delete 2>/dev/null || true
    find . -type f -name "*.o.cmd" -delete 2>/dev/null || true
    find . -type f -name "*.a" -delete 2>/dev/null || true
    find . -type f -name "*.lst" -delete 2>/dev/null || true
    find . -type f -name "*~" -delete 2>/dev/null || true
    find . -type f -name "#*#" -delete 2>/dev/null || true
    if [ -f "build.log" ]; then
        rm build.log
        print_status "Removed build log file."
    fi
    if [ -d "tmp" ]; then
        rm -rf tmp
        print_status "Removed temporary directory."
    fi
    if [ -d "anykernel" ]; then
        # Remove only build artifacts, preserve the directory structure
        rm -f anykernel/Image anykernel/Image.gz anykernel/dtbo.img
        print_status "Cleaned build artifacts from static AnyKernel directory."
    fi

    # Remove any temporary backup directory that might have been created if build was interrupted
    if [ -d ".anykernel_backup" ]; then
        rm -rf .anykernel_backup
        print_status "Removed temporary backup directory."
    fi

    # Remove generated ZIP files (kernel flashable zips) - find files with date pattern in name
    # Using a flexible pattern that matches the build.sh naming convention:
    # ${KERNEL_NAME}-${DEVICE_CODENAME}-$(date '+%Y%m%d').zip
    # This looks for files with an 8-digit date pattern at the end (YYYYMMDD)
    find . -maxdepth 1 -name "*-*-*[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].zip" -type f -delete 2>/dev/null || true

    # Count and report how many zip files were removed
    zip_count=$(find . -maxdepth 1 -name "*-*-*[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].zip" -type f 2>/dev/null | wc -l)
    if [ "$zip_count" -gt 0 ]; then
        print_status "Removed generated ZIP files"
    fi

    print_status "Cleanup process completed!"
}
cleanup
