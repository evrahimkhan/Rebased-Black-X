#!/usr/bin/env bash

# Android Common Kernel Build Script
# Supports multiple Linux distributions: Ubuntu, Debian, Linux Mint, Arch Linux, Manjaro, Fedora, openSUSE, and Gentoo
# Based on reference implementation for successful kernel compilation

DEVICE_CODENAME="stone"
DEVICE_NAME="POCO X5 5G (moonstone)"
KERNEL_NAME="Rebased-Black"
KERNEL_DEFCONFIG="stone_defconfig"
ANYKERNEL_DIR="$PWD/anykernel"
BUILD_TYPE="RELEASE"

# Enhanced logging system
LOG_FILE="build.log"
BUILD_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BUILD_START_EPOCH=$(date +%s)

# Initialize detailed logging
{
    echo "Build started at: $BUILD_START_TIME"
    echo "Device: $DEVICE_NAME ($DEVICE_CODENAME)"
    echo "Kernel: $KERNEL_NAME"
    echo "Defconfig: $KERNEL_DEFCONFIG"
    echo "Build Type: $BUILD_TYPE"
    echo "Architecture: $ARCH"
    echo "OS: $(cat /etc/os-release 2>/dev/null | grep -E "^PRETTY_NAME=" | cut -d= -f2 | tr -d '"')"
    echo "CPU Cores: $(nproc)"
    echo "Total Memory: $(free -h | grep -E '^Mem:' | awk '{print $2}')"
} > "$LOG_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Simple logging functions without function context (matches requested format)
log_with_context() {
    local level="$1"
    local message="$2"

    # Output to console with color coding - just the message
    case "$level" in
        "INFO")
            echo -e "$message"
            ;;
        "WARNING")
            echo -e "WARNING: $message"
            ;;
        "ERROR")
            echo -e "ERROR: $message"
            ;;
    esac

    # Write simple entry to log file
    echo "[$level] $message" >> "$LOG_FILE"
}

# Print output and log
print_status() {
    local message="$1"
    echo -e "$message"
    echo "[STATUS] $message" >> "$LOG_FILE"
}

print_warning() {
    local message="$1"
    echo -e "WARNING: $message"
    echo "[WARNING] $message" >> "$LOG_FILE"
}

print_error() {
    local message="$1"
    echo -e "ERROR: $message"
    echo "[ERROR] $message" >> "$LOG_FILE"
}

# Simple logging functions for different needs
log_build_step() {
    local step_name="$1"
    local message="$2"
    echo -e "$message"
    echo "[STATUS:$step_name] $message" >> "$LOG_FILE"
}

log_dependency_check() {
    local package="$1"
    local status="$2"
    local log_entry="[PACKAGE:$package] [STATUS:$status]"
    echo "$log_entry"
    echo "$log_entry" >> "$LOG_FILE"
}

log_compilation_progress() {
    local progress="$1"
    local details="$2"
    local log_entry="[PROGRESS:$progress] $details"
    echo "$log_entry"
    echo "$log_entry" >> "$LOG_FILE"
}

check_and_install_dependencies() {
    log_build_step "DEPENDENCY_CHECK" "Starting dependency check process"
    print_status "Checking dependencies..."

    # Define packages for different distributions
    local apt_packages=(
        "build-essential" "libncurses-dev" "flex" "bison"
        "libssl-dev" "bc" "curl" "wget" "unzip" "zip"
        "git" "llvm" "clang" "lld" "gcc-aarch64-linux-gnu"
        "gcc-arm-linux-gnueabi"
    )

    local pacman_packages=(
        "base-devel" "ncurses" "flex" "bison"
        "openssl" "bc" "curl" "wget" "unzip" "zip"
        "git" "llvm" "clang" "lld" "aarch64-linux-gnu-gcc"
        "arm-linux-gnueabi-gcc"
    )

    local dnf_packages=(
        "gcc" "gcc-c++" "ncurses-devel" "flex" "bison"
        "openssl-devel" "bc" "curl" "wget" "unzip" "zip"
        "git" "llvm" "clang" "lld" "gcc-aarch64-linux-gnu"
        "gcc-arm-linux-gnueabi" "make"
    )

    local emerge_packages=(
        "sys-devel/gcc" "sys-libs/ncurses" "sys-devel/flex" "sys-devel/bison"
        "dev-libs/openssl" "sys-devel/bc" "net-misc/curl" "app-arch/wget"
        "app-arch/unzip" "app-arch/zip" "dev-vcs/git" "sys-devel/llvm"
        "sys-devel/clang" "sys-devel/lld" "sys-devel/crossdev" "sys-devel/make"
    )

    log_dependency_check "package_lists" "Defined package lists for all supported distributions"

    # Detect the package manager and set the appropriate package list
    local package_manager=""
    local packages=()

    if command -v apt-get &> /dev/null; then
        package_manager="apt-get"
        packages=("${apt_packages[@]}")
        print_status "Detected Debian/Ubuntu-based system"
    elif command -v pacman &> /dev/null; then
        package_manager="pacman"
        packages=("${pacman_packages[@]}")
        print_status "Detected Arch Linux/Manjaro-based system"
    elif command -v dnf &> /dev/null; then
        package_manager="dnf"
        packages=("${dnf_packages[@]}")
        print_status "Detected Fedora-based system"
    elif command -v emerge &> /dev/null; then
        package_manager="emerge"
        packages=("${emerge_packages[@]}")
        print_status "Detected Gentoo-based system"
    elif command -v zypper &> /dev/null; then
        package_manager="zypper"
        # Use same packages as dnf for openSUSE
        packages=("${dnf_packages[@]}")
        print_status "Detected openSUSE-based system"
    else
        print_error "Unsupported package manager. Please install dependencies manually:"
        print_error "For Debian/Ubuntu/Linux Mint: ${apt_packages[*]}"
        print_error "For Arch Linux/Manjaro: ${pacman_packages[*]}"
        print_error "For Fedora/openSUSE/RHEL: ${dnf_packages[*]}"
        print_error "For Gentoo: ${emerge_packages[*]} (with cross-compilation tools set up via crossdev)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 0
    fi

    log_dependency_check "package_manager" "Detected package manager: $package_manager"

    # Install packages based on detected package manager
    local missing_packages=()
    local total_packages=${#packages[@]}
    log_dependency_check "total_packages" "Total packages to check: $total_packages"

    if [ "$package_manager" = "apt-get" ]; then
        for package in "${packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package "; then
                missing_packages+=("$package")
                log_dependency_check "$package" "MISSING"
            else
                log_dependency_check "$package" "INSTALLED"
            fi
        done
    elif [ "$package_manager" = "pacman" ]; then
        for package in "${packages[@]}"; do
            if ! pacman -Q "$package" &> /dev/null; then
                missing_packages+=("$package")
                log_dependency_check "$package" "MISSING"
            else
                log_dependency_check "$package" "INSTALLED"
            fi
        done
    elif [ "$package_manager" = "dnf" ]; then
        for package in "${packages[@]}"; do
            if ! dnf list installed "$package" &> /dev/null; then
                missing_packages+=("$package")
                log_dependency_check "$package" "MISSING"
            else
                log_dependency_check "$package" "INSTALLED"
            fi
        done
    elif [ "$package_manager" = "emerge" ]; then
        for package in "${packages[@]}"; do
            # Use equery if available, otherwise check with eix, and finally assume missing
            # equery is part of gentoolkit package, while eix is a separate tool
            if ! equery list "$package" &> /dev/null; then
                missing_packages+=("$package")
                log_dependency_check "$package" "MISSING"
            else
                log_dependency_check "$package" "INSTALLED"
            fi
        done
    elif [ "$package_manager" = "zypper" ]; then
        for package in "${packages[@]}"; do
            if ! zypper search -i --match-exact "$package" 2>/dev/null | grep -q "Installed"; then
                missing_packages+=("$package")
                log_dependency_check "$package" "MISSING"
            else
                log_dependency_check "$package" "INSTALLED"
            fi
        done
    fi

    local missing_count=${#missing_packages[@]}
    log_dependency_check "summary" "Found $missing_count missing packages out of $total_packages total"

    if [ $missing_count -gt 0 ]; then
        print_status "Installing $missing_count missing packages: ${missing_packages[*]}"
        if [ "$package_manager" = "apt-get" ]; then
            ensure_sudo_session
            log_dependency_check "apt_update" "Running apt-get update"
            sudo apt-get update
            if sudo apt-get install -y "${missing_packages[@]}"; then
                print_status "APT packages installed successfully"
                log_dependency_check "apt_install" "SUCCESS: Installed ${#missing_packages[@]} packages"
            else
                print_error "Failed to install APT packages. Exiting..."
                log_dependency_check "apt_install" "FAILED: Could not install packages"
                exit 1
            fi
        elif [ "$package_manager" = "pacman" ]; then
            ensure_sudo_session
            if sudo pacman -Sy --noconfirm "${missing_packages[@]}"; then
                print_status "Pacman packages installed successfully"
                log_dependency_check "pacman_install" "SUCCESS: Installed ${#missing_packages[@]} packages"
            else
                print_error "Failed to install Pacman packages. Exiting..."
                log_dependency_check "pacman_install" "FAILED: Could not install packages"
                exit 1
            fi
        elif [ "$package_manager" = "dnf" ]; then
            ensure_sudo_session
            if sudo dnf install -y "${missing_packages[@]}"; then
                print_status "DNF packages installed successfully"
                log_dependency_check "dnf_install" "SUCCESS: Installed ${#missing_packages[@]} packages"
            else
                print_error "Failed to install DNF packages. Exiting..."
                log_dependency_check "dnf_install" "FAILED: Could not install packages"
                exit 1
            fi
        elif [ "$package_manager" = "emerge" ]; then
            ensure_sudo_session
            local crossdev_needed=false
            local packages_to_emerge=()

            log_dependency_check "emerge_process" "Processing packages for Gentoo emerge"

            # Check if cross-compilation tools are needed and handle them
            for package in "${missing_packages[@]}"; do
                if [[ "$package" == *"aarch64-linux-gnu"* ]] || [[ "$package" == *"arm-linux-gnueabi"* ]]; then
                    crossdev_needed=true
                    log_dependency_check "$package" "CROSS_COMPILE_TOOL - will be handled specially"
                else
                    packages_to_emerge+=("$package")
                    log_dependency_check "$package" "REGULAR_PACKAGE"
                fi
            done

            # Install regular packages first
            local installed_count=0
            for package in "${packages_to_emerge[@]}"; do
                if sudo emerge -v "$package"; then
                    print_status "Package $package installed successfully"
                    log_dependency_check "$package" "INSTALLED"
                    ((installed_count++))
                else
                    print_error "Failed to install package $package. Exiting..."
                    log_dependency_check "$package" "INSTALL_FAILED"
                    exit 1
                fi
            done
            log_dependency_check "emerge_summary" "Installed $installed_count regular packages"

            # Install cross-compilation tools using crossdev
            if [ "$crossdev_needed" = true ]; then
                if command -v crossdev &> /dev/null; then
                    print_status "Setting up cross-compilation tools with crossdev..."
                    if sudo crossdev --target aarch64-unknown-linux-gnu && sudo crossdev --target arm-linux-gnueabi; then
                        print_status "Cross-compilation tools installed successfully"
                        log_dependency_check "crossdev" "SUCCESS: Cross-compilation tools set up"
                    else
                        print_error "Failed to install cross-compilation tools. Exiting..."
                        log_dependency_check "crossdev" "FAILED: Could not set up cross-compilation tools"
                        exit 1
                    fi
                else
                    print_error "crossdev not available but cross-compilation tools needed. Please install sys-devel/crossdev first."
                    log_dependency_check "crossdev" "ERROR: crossdev command not found"
                    exit 1
                fi
            fi
        elif [ "$package_manager" = "zypper" ]; then
            ensure_sudo_session
            if sudo zypper install -y "${missing_packages[@]}"; then
                print_status "Zypper packages installed successfully"
                log_dependency_check "zypper_install" "SUCCESS: Installed ${#missing_packages[@]} packages"
            else
                print_error "Failed to install Zypper packages. Exiting..."
                log_dependency_check "zypper_install" "FAILED: Could not install packages"
                exit 1
            fi
        fi
    else
        print_status "All $total_packages required packages are already installed"
        # Still ensure sudo is available for the tool check that comes next
        ensure_sudo_session
        log_dependency_check "install_summary" "All packages were already installed"
    fi

    # Check for required tools availability
    local required_tools=("make" "gcc" "clang" "ld.lld" "llvm-ar" "llvm-nm" "llvm-objcopy" "llvm-strip" "aarch64-linux-gnu-gcc" "arm-linux-gnueabi-gcc")
    local missing_tools=()
    local found_tools=0
    local total_tools=${#required_tools[@]}

    print_status "Checking for required build tools..."
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            log_dependency_check "tool:$tool" "MISSING"
        else
            log_dependency_check "tool:$tool" "FOUND"
            ((found_tools++))
        fi
    done

    local tools_missing_count=${#missing_tools[@]}
    log_dependency_check "tools_summary" "Found $found_tools/$total_tools tools available, $tools_missing_count missing"
    
    if [ $tools_missing_count -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install them and try again"
        exit 1
    else
        print_status "All $total_tools required build tools are available"
    fi

    print_status "Dependency check completed successfully!"
    log_build_step "DEPENDENCY_CHECK" "Dependency check completed successfully"
}

setup_clang() {
    local compiler_found=false
    local compiler_cmd=""

    # Check for different variations of clang across distributions (newest first)
    for cmd in clang clang-18 clang-17 clang-16 clang-15 clang-14 clang-13 clang-12 clang-11 clang-10; do
        if command -v "$cmd" &> /dev/null; then
            compiler_cmd="$cmd"
            compiler_found=true
            break
        fi
    done

    if [ "$compiler_found" = true ]; then
        COMPILER_STRING="$($compiler_cmd --version | head -n 1)"
        print_status "Compiler: $COMPILER_STRING"
        
        # Check if clang version is sufficient (need at least version 10 for proper kernel compilation)
        local version_output
        version_output=$($compiler_cmd --version | head -n 1)
        local clang_version
        if [[ $version_output =~ clang[[:space:]]+version[[:space:]]+([0-9]+) ]]; then
            clang_version="${BASH_REMATCH[1]}"
            if [ "$clang_version" -lt 10 ]; then
                print_warning "Clang version $clang_version might be too old for kernel compilation. Recommended version is 10 or higher."
            else
                print_status "Clang version $clang_version is adequate for kernel compilation"
            fi
        else
            print_warning "Could not determine Clang version from '$version_output'"
        fi
    else
        print_error "Clang compiler not found!"
        exit 1
    fi
}

# Global variable for sudo keepalive process ID
SUDO_KEEPALIVE_PID=""

# Function to ensure sudo session is active
ensure_sudo_session() {
    if ! sudo -vn 2>/dev/null; then
        print_status "Requesting sudo access for package management operations..."
        sudo -v
        # If there's an existing keepalive process, kill it first
        if [ ! -z "$SUDO_KEEPALIVE_PID" ] && [ "$SUDO_KEEPALIVE_PID" != "" ]; then
            kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
        fi
        # Keep sudo alive in background
        while true; do
            sudo -nv 2>/dev/null || break
            sleep 120
        done &
        SUDO_KEEPALIVE_PID=$!
    fi
}

# Function to kill sudo keepalive process
kill_sudo_keepalive() {
    if [ ! -z "$SUDO_KEEPALIVE_PID" ] && [ "$SUDO_KEEPALIVE_PID" != "" ]; then
        kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
        SUDO_KEEPALIVE_PID=""
    fi
}

export ARCH=arm64
export LLVM=1
export LLVM_IAS=1
export KBUILD_BUILD_USER="Black"
export KBUILD_BUILD_HOST="X"

compile_kernel() {
    print_status "Building kernel for $DEVICE_NAME ($DEVICE_CODENAME)..."
    mkdir -p out

    if [ ! -f "arch/arm64/configs/$KERNEL_DEFCONFIG" ]; then
        print_error "$KERNEL_DEFCONFIG not found in arch/arm64/configs/!"
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

    # Get system information before compilation
    local cpu_cores=$(nproc --all)
    local sys_total_memory=$(free -m | awk 'NR==2{print $2}')
    local sys_available_memory=$(free -m | awk 'NR==2{print $7}')
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local start_epoch=$(date +%s)

    print_status "Preparing kernel compilation environment..."
    echo "[COMPILE:ENVIRONMENT] CPU Cores Available: $cpu_cores"
    echo "[COMPILE:ENVIRONMENT] Total Memory: ${sys_total_memory}MB"
    echo "[COMPILE:ENVIRONMENT] Available Memory: ${sys_available_memory}MB"

    print_status "Starting kernel compilation with $cpu_cores CPU cores..."
    echo "[COMPILE:START] Compilation started at: $start_time"
    echo "[COMPILE:CONFIG] Using clang compiler with LLVM toolchain"
    echo "[COMPILE:CROSS_COMPILE] Target architecture: aarch64-linux-gnu"
    echo "[COMPILE:CROSS_COMPILE_ARM32] Target architecture: arm-linux-gnueabi"
    echo "[COMPILE:JOBS] Parallel jobs: $cpu_cores"

    # Start compilation with real-time output and logging
    echo "[COMPILE:PROCESS] Building kernel - showing real-time progress..."

    # Set up trap for interrupt handling (Ctrl+C)
    cleanup_on_interrupt() {
        echo
        print_error "Build interrupted by user (Ctrl+C)! Cleaning up..."
        echo "[COMPILE:INTERRUPT] Build was interrupted by user at $(date '+%Y-%m-%d %H:%M:%S')"
        # Kill any sudo keepalive process
        kill_sudo_keepalive 2>/dev/null || true
        exit 130  # Standard exit code for Ctrl+C interruption
    }

    trap cleanup_on_interrupt INT TERM

    if make -j"$cpu_cores" O=out Image -i \
        CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
        OBJCOPY=llvm-objcopy STRIP=llvm-strip \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1; then
        # Remove trap since we completed successfully
        trap - INT TERM
        local end_epoch=$(date +%s)
        local duration=$((end_epoch - start_epoch))
        print_status "Kernel Image compilation successful! (Duration: ${duration}s)"
        echo "[COMPILE:SUCCESS] Image built in ${duration} seconds"

        # Show size information of the compiled kernel
        if [ -f "out/arch/arm64/boot/Image" ]; then
            local image_size=$(stat -c%s "out/arch/arm64/boot/Image" 2>/dev/null || echo "unknown")
            echo "[COMPILE:ARTIFACT] Image size: $image_size bytes ($(echo "scale=2; $image_size/1024/1024" | bc 2>/dev/null || echo "N/A") MB)"
        fi

        if [ -f "out/arch/arm64/boot/Image.gz" ]; then
            local image_gz_size=$(stat -c%s "out/arch/arm64/boot/Image.gz" 2>/dev/null || echo "unknown")
            echo "[COMPILE:ARTIFACT] Image.gz size: $image_gz_size bytes ($(echo "scale=2; $image_gz_size/1024/1024" | bc 2>/dev/null || echo "N/A") MB)"
        fi
    else
        local fail_epoch=$(date +%s)
        local fail_duration=$((fail_epoch - start_epoch))
        print_status "Primary Image build failed after ${fail_duration}s, trying alternative compilation..."
        echo "[COMPILE:FAILURE] Primary compilation failed after ${fail_duration} seconds"
        echo "[COMPILE:RETRY] Attempting alternative compilation method"

        local alt_start_time=$(date +%s)
        # Set up trap for interrupt handling during alternative compilation
        trap cleanup_on_interrupt INT TERM

        if make -j"$cpu_cores" O=out -i \
            CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
            OBJCOPY=llvm-objcopy STRIP=llvm-strip \
            CLANG_TRIPLE=aarch64-linux-gnu- \
            CROSS_COMPILE=aarch64-linux-gnu- \
            CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1; then
            # Remove trap since we completed successfully
            trap - INT TERM
            local alt_end_time=$(date +%s)
            local alt_duration=$((alt_end_time - alt_start_time))
            local total_duration=$((alt_end_time - start_epoch))
            print_status "Alternative kernel compilation successful! (Retry Duration: ${alt_duration}s, Total: ${total_duration}s)"
            echo "[COMPILE:RECOVERY] Alternative compilation succeeded after ${alt_duration}s (Total time: ${total_duration}s)"
        else
            # Remove trap since compilation failed
            trap - INT TERM
            local alt_fail_time=$(date +%s)
            local alt_total_duration=$((alt_fail_time - start_epoch))
            print_error "Kernel compilation failed after ${alt_total_duration}s!"
            echo "[COMPILE:FINAL_FAILURE] All compilation attempts failed after ${alt_total_duration} seconds"
            exit 1
        fi
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
echo "Starting main build process"

# Setup sudo session for all operations that need it
ensure_sudo_session

check_and_install_dependencies
setup_clang
compile_kernel
package_zip

# Clean up sudo session
kill_sudo_keepalive

build_end_time=$(date +%s)
build_duration=$((build_end_time - build_start_time))
echo "Build completed successfully in $build_duration seconds!"
echo "Build log saved to: $LOG_FILE"