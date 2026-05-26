APP_NAME = Screenshooter
BUNDLE_ID = com.artem.screenshooter
APP_DIR = $(APP_NAME).app
MAC_OS_DIR = $(APP_DIR)/Contents/MacOS
RESOURCES_DIR = $(APP_DIR)/Contents/Resources
SWIFTC = swiftc
SWIFT_FILES = $(wildcard Sources/*.swift)

all: $(APP_NAME)

$(APP_NAME): $(SWIFT_FILES) Info.plist
	@mkdir -p $(MAC_OS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	$(SWIFTC) -o $(MAC_OS_DIR)/$(APP_NAME) $(SWIFT_FILES) -target arm64-apple-macosx11.0
	@cp Info.plist $(APP_DIR)/Contents/Info.plist
	@echo "Build complete: $(APP_DIR)"

clean:
	rm -rf $(APP_DIR)
