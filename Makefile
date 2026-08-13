# CLT-only build: current macOS SDK, Apple Silicon. Does not require Xcode.app.
# Nibs / Assets.car / icns are vendored from the last official 1.2 app (MIT).

SDKROOT      ?= $(shell xcrun --sdk macosx --show-sdk-path)
MIN_VER      ?= 13.0
ARCH         ?= arm64
CC           ?= clang
SRC_DIR       = Spectacle/Sources
BUILD_DIR     = build
APP_DIR       = $(BUILD_DIR)/Spectacle.app
CONTENTS      = $(APP_DIR)/Contents
PREBUILT      = packaging/prebuilt
VERSION       = 1.2.1

CFLAGS = -fobjc-arc -fmodules -fobjc-weak \
	-isysroot $(SDKROOT) \
	-mmacosx-version-min=$(MIN_VER) \
	-arch $(ARCH) \
	-I $(SRC_DIR) \
	-Wall -Wno-deprecated-declarations \
	-DSpectacleVersionString=\"$(VERSION)\"

LIBS = -framework Cocoa -framework Carbon -framework JavaScriptCore \
	-framework ApplicationServices -framework ServiceManagement \
	-framework QuartzCore -framework CoreGraphics

SRCS = $(wildcard $(SRC_DIR)/*.m)
OBJS = $(patsubst $(SRC_DIR)/%.m,$(BUILD_DIR)/obj/%.o,$(SRCS)) $(BUILD_DIR)/obj/main.o

.PHONY: all app clean install

all: app

app: $(CONTENTS)/MacOS/Spectacle
	@echo "built $(APP_DIR)"

$(BUILD_DIR)/obj/%.o: $(SRC_DIR)/%.m
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/obj/main.o: Spectacle/Supporting\ Files/main.m
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c "$<" -o $@

$(CONTENTS)/MacOS/Spectacle: $(OBJS) packaging/Info.plist
	@mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	$(CC) $(CFLAGS) $(LIBS) $(OBJS) -o $@
	@# resources
	cp packaging/Info.plist $(CONTENTS)/Info.plist
	printf 'APPLZERO' > $(CONTENTS)/PkgInfo
	rm -rf $(CONTENTS)/Resources/*
	cp -R $(PREBUILT)/Resources/. $(CONTENTS)/Resources/
	cp -R "Spectacle/Resources/Window Position Calculations" "$(CONTENTS)/Resources/"
	cp "Spectacle/Resources/Property Lists/Defaults.plist" "$(CONTENTS)/Resources/Defaults.plist"
	cp -R Spectacle/Resources/Localizations/en.lproj $(CONTENTS)/Resources/
	# drop Sparkle keys from a copy already in packaging/Info.plist
	codesign --force --deep --sign - --options runtime \
		--entitlements "Spectacle/Supporting Files/Spectacle.entitlements" \
		$(APP_DIR)
	file $@

clean:
	rm -rf $(BUILD_DIR)

install: app
	@# replace the 2016 Intel binary; keep bundle id so shortcuts JSON still apply
	-killall Spectacle 2>/dev/null || true
	rm -rf /Applications/Spectacle.app
	cp -R $(APP_DIR) /Applications/Spectacle.app
	codesign --force --deep --sign - --options runtime \
		--entitlements "Spectacle/Supporting Files/Spectacle.entitlements" \
		/Applications/Spectacle.app
	open /Applications/Spectacle.app
	@echo "Installed /Applications/Spectacle.app — re-enable Accessibility if prompted."
