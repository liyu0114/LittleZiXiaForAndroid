# 本地模型 CMake 配置
# 
# 用于编译 llama.cpp 为 Android .so

cmake_minimum_required(VERSION 3.18)

project("llama" VERSION 1.0.0)

# 加载 externalNativeCmakeFiles
external_native_cmake_files(
    ${CMAKE_SOURCE_DIR}/../external/llama.cpp/CMakeLists.txt
)

# 设置编译选项
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 添加预编译的 llama.cpp 源
add_library(llama SHARED
    llama.cpp
)

# 链接 log 库 (用于 Android Log)
target_link_libraries(llama 
    log
)

# 包含目录
target_include_directories(llama PRIVATE
    ${CMAKE_SOURCE_DIR}/../external/llama.cpp/include
)

# 编译选项
target_compile_options(llama PRIVATE
    -O3
    -ffast-math
    -fno-exceptions
)