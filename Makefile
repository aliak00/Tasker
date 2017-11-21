WORKSPACE=./Example/Swooft.xcworkspace
PODS_DIR=./Example
MAIN_SCHEME=Swooft-Example
PROFILER_SCHEME=Swooft-Profiler-Tests

BUILD_CONSTRUCT=build
TEST_CONSTRUCT=-destination 'platform=iOS Simulator,name=iPhone 8,OS=11.1' test


define build_scheme
    xcodebuild -workspace $(WORKSPACE) -scheme $(1) \
		-sdk iphonesimulator11.1 \
		-derivedDataPath build/DerivedData
endef

setup:
	mkdir -p build
	scripts/setup.sh
format:
	scripts/format.sh
build: 
	$(call build_scheme,$(MAIN_SCHEME)) $(BUILD_CONSTRUCT) | xcpretty
test: 
	$(call build_scheme,$(MAIN_SCHEME)) $(TEST_CONSTRUCT)  | xcpretty
profile: 
	$(call build_scheme,$(PROFILER_SCHEME)) $(TEST_CONSTRUCT)  | xcpretty
clean:
	rm -rf ./build $(WORKSPACE) $(PODS_DIR)/Pods

.PHONY: build