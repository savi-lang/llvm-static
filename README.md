# llvm-static

CI/CD automation for building LLVM/clang/lld static libraries for a variety of supported platforms. 

The resulting bundle is uploaded to GitHub Releases, to be downloaded by the automation that is used to build the Savi compiler, which links to these libraries statically so that it can include LLVM/clang features without requiring the end-user of the compiler to have the (correct version of the) LLVM/clang/lld shared libraries installed.
