KEXT_NAME     = DisableTurboBoost
KEXT_BUNDLE   = $(KEXT_NAME).kext
SRC           = $(KEXT_NAME)/$(KEXT_NAME).c
PLIST         = $(KEXT_NAME)/Info.plist
INSTALL_DIR   = /Library/Extensions

# Kernel framework paths (resolved via SDK to support modern Xcode/CLT installs)
SDK           = $(shell xcrun --show-sdk-path)
KERNEL_FW     = $(SDK)/System/Library/Frameworks/Kernel.framework
KERNEL_HEADERS = $(KERNEL_FW)/Headers
KERNEL_PRIVHEADERS = $(KERNEL_FW)/PrivateHeaders

# Compiler settings
CC            = clang
ARCH          = x86_64
CFLAGS        = -arch $(ARCH) \
                -mkernel \
                -nostdlib \
                -Xlinker -kext \
                -isystem $(KERNEL_HEADERS) \
                -isystem $(KERNEL_PRIVHEADERS) \
                -DKERNEL \
                -DKERNEL_PRIVATE \
                -DDRIVER_PRIVATE \
                -DAPPLE \
                -DNeXT \
                -I$(KERNEL_HEADERS) \
                -Wall -Werror \
                -O2

.PHONY: all clean install uninstall load unload

all: $(KEXT_BUNDLE)

$(KEXT_BUNDLE): $(SRC) $(PLIST)
	@echo "==> Building $(KEXT_BUNDLE)..."
	@mkdir -p $(KEXT_BUNDLE)/Contents/MacOS
	$(CC) $(CFLAGS) -o $(KEXT_BUNDLE)/Contents/MacOS/$(KEXT_NAME) $(SRC)
	@cp $(PLIST) $(KEXT_BUNDLE)/Contents/Info.plist
	@echo "==> Built $(KEXT_BUNDLE)"

clean:
	@echo "==> Cleaning..."
	@rm -rf $(KEXT_BUNDLE)

install: $(KEXT_BUNDLE)
	@echo "==> Installing to $(INSTALL_DIR)..."
	sudo cp -R $(KEXT_BUNDLE) $(INSTALL_DIR)/
	sudo chown -R root:wheel $(INSTALL_DIR)/$(KEXT_BUNDLE)
	sudo chmod -R 755 $(INSTALL_DIR)/$(KEXT_BUNDLE)
	sudo kextload $(INSTALL_DIR)/$(KEXT_BUNDLE)
	@echo "==> Turbo Boost disabled"

uninstall:
	@echo "==> Uninstalling..."
	-sudo kextunload $(INSTALL_DIR)/$(KEXT_BUNDLE) 2>/dev/null
	sudo rm -rf $(INSTALL_DIR)/$(KEXT_BUNDLE)
	@echo "==> Turbo Boost re-enabled"

load:
	sudo kextload $(KEXT_BUNDLE)
	@echo "==> Turbo Boost disabled"

unload:
	sudo kextunload $(KEXT_BUNDLE)
	@echo "==> Turbo Boost re-enabled"
