BINARY?=rocketboot
BUILD_FOLDER?=.build
ROOT?=$(PWD)
RELEASE_FOLDER?=release
TESTS_RESOURCES_EMPTY_FOLDER?=TestResources/empty
TESTS_RESOURCES_EMPTY_REPO_FOLDER?=TestResources/emptyrepo
TESTS_RESOURCES_NO_REPO_FOLDER?=TestResources/norepo
TESTS_RESOURCES_NORMAL_FOLDER?=TestResources/normal
TESTS_RESOURCES_CARTHAGE_FOLDER?=TestResources/carthage
TESTS_RESOURCES_CARTHAGE_WITH_TAG_FOLDER?=TestResources/carthageWithTag
TESTS_RESOURCES_XCODE_8_FOLDER?=TestResources/xcode8
OS?=sierra
PREFIX?=/usr/local
PROJECT?=RocketBoot
RELEASE_BINARY_FOLDER?=$(BUILD_FOLDER)/release/$(PROJECT)

release:
	swift build -c release -Xswiftc -static-stdlib
	cp -f $(RELEASE_BINARY_FOLDER) $(RELEASE_FOLDER)
build:
	swift build
test: build
	cd $(TESTS_RESOURCES_EMPTY_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
	cd $(TESTS_RESOURCES_EMPTY_REPO_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
	cd $(TESTS_RESOURCES_NO_REPO_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
	cd $(TESTS_RESOURCES_NORMAL_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
	cd $(TESTS_RESOURCES_CARTHAGE_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
	cd $(TESTS_RESOURCES_CARTHAGE_WITH_TAG_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
	cd $(TESTS_RESOURCES_XCODE_8_FOLDER) && $(ROOT)/$(BUILD_FOLDER)/debug/RocketBoot
clean:
	swift package clean
	rm -rf $(BUILD_FOLDER) $(PROJECT).xcodeproj
xcode:
	swift package generate-xcodeproj
install: release
	mkdir -p $(PREFIX)/bin
	if [ -f "/usr/local/bin/rocketboot" ]; then rm /usr/local/bin/rocketboot; fi
	cp -f $(RELEASE_BINARY_FOLDER) $(PREFIX)/bin/$(BINARY)
	rocketboot help
.PHONY: release
