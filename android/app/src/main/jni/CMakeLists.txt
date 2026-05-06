# llama.cpp JNI 桥接 CMake 配置
cmake_minimum_required(VERSION 3.18)

project("llama_jni" VERSION 1.0.0)

# C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 添加源文件
add_library(llama SHARED
    llama.cpp
)

# Android log 库
target_link_libraries(llama
    log
)

# 编译选项
target_compile_options(llama PRIVATE
    -O3
    -ffast-math
)

# 包含路径
target_include_directories(llama PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)