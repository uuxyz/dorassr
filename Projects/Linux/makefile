.PHONY: all debug release lib lib-debug lib-release

DORA_WITH_SPINE ?= OFF
SPINE_CMAKE_OPTION = $(if $(filter 1 ON on TRUE true,$(DORA_WITH_SPINE)),ON,OFF)

all: release

debug: lib-debug
	[ -d build ] || mkdir build
	cd build && cmake -DCMAKE_BUILD_TYPE=debug -DDORA_WITH_SPINE=$(SPINE_CMAKE_OPTION) ..
	$(MAKE) -C build

release: lib-release
	[ -d build ] || mkdir build
	cd build && cmake -DCMAKE_BUILD_TYPE=release -DDORA_WITH_SPINE=$(SPINE_CMAKE_OPTION) ..
	$(MAKE) -C build

lib: lib-release

lib-debug:
	../../Tools/build-scripts/build_lib_linux.sh debug

lib-release:
	../../Tools/build-scripts/build_lib_linux.sh release
