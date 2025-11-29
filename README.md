Here is the combined `README.md` file, tailored for your GitHub repository. It synthesizes the technical workflow and project overview into a human-readable format.

-----

# Rebased-Black-X (Android Common Kernel 5.4)

**Repository:** [https://github.com/evrahimkhan/Rebased-Black-X.git](https://github.com/evrahimkhan/Rebased-Black-X.git)

## Project Overview

This repository contains the source code for the Android Common Kernel (ACK) based on Linux kernel version **5.4.300**. This kernel is part of the Android 11 (R) release line and is specifically designed to support multiple architectures, with a primary focus on Qualcomm-based devices (specifically the Lahaina chipset).

We aim to maintain a stable branch that adheres to Android's General Kernel Image (GKI) standards while providing vendor-specific support for Qualcomm platforms.

-----

## Environment Setup

Before building, ensure your development environment is set up correctly.

### Prerequisites

  * **Operating System:** Linux-based development environment (Ubuntu/Debian recommended).
  * **Compiler:** Clang/LLVM compiler (Version 19+ recommended).
  * **Android Tools:** Android SDK and NDK tools.
  * **Cross-Compilation Toolchains:**
      * `aarch64-linux-gnu-gcc` (for ARM64)
      * `arm-linux-gnueabi-gcc` (for ARM)
      * `x86_64-linux-gnu-gcc` (for x86\_64)

### Installing Dependencies

If you are running Ubuntu or Debian, you can install the common build dependencies with the following command:

```bash
sudo apt-get install build-essential libssl-dev libelf-dev flex bison libncurses5-dev device-tree-compiler
```

-----

## Build Instructions

This project supports both the traditional Make-based system and Android's Soong build system (`Android.bp`).

### 1\. Configuration

You can configure the kernel for generic Android use or specifically for the Qualcomm Lahaina platform.

  * **Generic Kernel Image (GKI):**

    ```bash
    make ARCH=arm64 gki_defconfig
    ```

  * **Qualcomm Lahaina Platform:**

    ```bash
    make ARCH=arm64 msm.lahaina_defconfig
    ```

### 2\. Building the Kernel

To build the kernel and modules, run the following. We recommend using `ccache` to speed up rebuilds:

```bash
# Optional: Enable ccache
export CC='ccache clang'

# Build command
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

### Build Variants

You can choose different configurations based on your testing needs:

  * `gki_defconfig`: Default Generic Kernel Image.
  * `gki_kasan_defconfig`: GKI with Kernel Address Sanitizer (for debugging).
  * `gki_kprobes_defconfig`: GKI with kprobes support.
  * `allmodconfig`: Enables all modules (primarily for compile testing).

-----

## Development Workflow & Contributing

We follow strict Android and Linux kernel coding standards.

### Patch Submission Guidelines

When submitting patches to this repository, please ensure the following:

1.  **Code Standards:** Code must conform to Linux kernel standards and pass `checkpatch.pl` validation.
2.  **Integrity:** Patches must not break GKI or `allmodconfig` builds.
3.  **Tags:** Patches must include the appropriate subject tag (`UPSTREAM:`, `BACKPORT:`, `FROMGIT:`, `FROMLIST:`, or `ANDROID:`).
4.  **Metadata:** Include `Change-Id:`, `Signed-off-by:`, and `Bug:` (if applicable).

### Patch Format Examples

**Upstream Patch (Cherry-pick):**

```text
UPSTREAM: patch title

Patch description...

Signed-off-by: Original Author <author@example.com>
(cherry-picked from commit SHA)
Change-Id: Ixxxxx
Signed-off-by: Your Name <your.name@example.com>
```

**Android-Specific Fix:**

```text
ANDROID: fix android-specific issue in file.c

Patch description...

Fixes: abcdef12345 ("original commit that introduced issue")
Change-Id: Ixxxxx
Signed-off-by: Your Name <your.name@example.com>
```

-----

## Special Features

### HHG Device Vibrator Driver

This kernel includes support for the HHG device vibrator driver. To enable this, the following changes are required:

1.  Copy `drivers/hid/hid-aksys.c` to `drivers/hid/`.
2.  Update `drivers/hid/hid-ids.h` with the correct device IDs.
3.  Update `drivers/hid/Kconfig` and `drivers/hid/Makefile`.
4.  Ensure `CONFIG_HID_AKSYS_QRD=m` and `CONFIG_AKSYS_QRD_FF=y` are present in your config.

-----

## Testing & Verification

Before submitting, verify that your changes work across supported architectures.

### Architecture Testing

Run the following commands to ensure cross-architecture compatibility:

  * **ARM:** `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-`
  * **ARM64:** `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`
  * **x86\_64:** `make ARCH=x86_64 CROSS_COMPILE=x86_64-linux-gnu-`

-----

## Troubleshooting

  * **Clang Issues:** If you experience version issues, check the `build.config.common` file for the specific `CLANG_PREBUILT_BIN` requirement.
  * **Toolchain Errors:** Verify your cross-compilation toolchain is in your PATH using `which aarch64-linux-gnu-gcc`.

For detailed documentation, refer to the `Documentation/` directory within the source tree.

**Next Step:** Would you like me to generate a specific `.gitignore` file for this kernel repository to keep your commits clean?
