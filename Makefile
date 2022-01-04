LLVM_VERSION=12.0.1
LLVM_DOWNLOAD_URL?="https://github.com/llvm/llvm-project/releases/download/llvmorg-$(LLVM_VERSION)/llvm-project-$(LLVM_VERSION).src.tar.xz"
LLVM_BUILD_ARGS?=""
LLVM_SOURCE_ARCHIVE=lib/llvm-$(LLVM_VERSION).src.tar.gz
LLVM_RELEASE_DIR=lib/llvm-$(LLVM_VERSION)
LLVM_INSTALL_DIR=lib/llvm
LLVM_CACHE_BUSTER_DATE=20220103
PWD?=$(shell pwd)

# By default, use all cores available except one, so things stay responsive.
NUM_THREADS?=$(shell expr `getconf _NPROCESSORS_ONLN 2>/dev/null` - 1)

PHONY:

# Download the LLVM project source code.
#
# This is a prerequisite for all of the targets that build LLVM.
# We keep the version as part of the name so that we can download a different
# version without clobbering the old version we previously downloaded.
$(LLVM_SOURCE_ARCHIVE):
	mkdir -p `dirname $@`
	curl -L --fail ${LLVM_DOWNLOAD_URL} --output $@

# Extract the LLVM project source code to a folder for a release build.
$(LLVM_RELEASE_DIR): $(LLVM_SOURCE_ARCHIVE)
	mkdir -p $@
	tar -xvf $(LLVM_SOURCE_ARCHIVE) --strip-components=1 -C $@
	touch $@

# Configure CMake for the LLVM release build.
$(LLVM_RELEASE_DIR)/build/CMakeCache.txt: $(LLVM_RELEASE_DIR)
	mkdir -p $(LLVM_RELEASE_DIR)/build
	cd $(LLVM_RELEASE_DIR)/build && env CC=clang CXX=clang++ cmake \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/$(LLVM_INSTALL_DIR) \
		-DCMAKE_OSX_ARCHITECTURES='x86_64;arm64' \
		-DLIBCLANG_BUILD_STATIC=ON \
		-DLLVM_ENABLE_BINDINGS=OFF \
		-DLLVM_ENABLE_LIBXML2=OFF \
		-DLLVM_ENABLE_LTO=OFF \
		-DLLVM_ENABLE_OCAMLDOC=OFF \
		-DLLVM_ENABLE_PIC=OFF \
		-DLLVM_ENABLE_PROJECTS='clang;lld' \
		-DLLVM_ENABLE_TERMINFO=OFF \
		-DLLVM_ENABLE_WARNINGS=OFF \
		-DLLVM_ENABLE_Z3_SOLVER=OFF \
		-DLLVM_ENABLE_ZLIB=OFF \
		-DLLVM_INCLUDE_BENCHMARKS=OFF \
		-DLLVM_INCLUDE_TESTS=OFF \
		-DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
		$(LLVM_BUILD_ARGS) \
		../llvm

# Build an install LLVM to the relative install path, so it's ready to use.
# Then remove all the unnecessary parts we don't need to put in our bundle.
# We remove everything except includes, static libs and the llvm-config binary.
# For convenience of troubleshooting, for now we also include llc and clang.
llvm: $(LLVM_RELEASE_DIR)/build/CMakeCache.txt
	mkdir -p $(LLVM_INSTALL_DIR)
	make -C $(LLVM_RELEASE_DIR)/build -j$(NUM_THREADS) install
	rm -r $(LLVM_INSTALL_DIR)/share/
	rm -r $(LLVM_INSTALL_DIR)/lib/clang/
	rm -r $(LLVM_INSTALL_DIR)/lib/cmake/
	rm -r $(LLVM_INSTALL_DIR)/libexec/
	rm `ls -rtd $(LLVM_INSTALL_DIR)/bin/* | grep -v llvm-config | grep -v llc | grep -v clang`

# The output of this command is used by Cirrus CI as a cache key,
# so that it can know when to invalidate the cache.
# Currently, we use both the target triple and LLVM version, as well as
# a date number tacked onto the end as an arbitrary cache buster, which we
# can update whenever we change something else about the way we build.
llvm-ci-cache-key: PHONY
	@echo "`clang -v 2>&1 | grep Target`, LLVM: $(LLVM_VERSION), Date: $(LLVM_CACHE_BUSTER_DATE)"
