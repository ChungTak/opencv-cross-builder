#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 默认参数
TARGET="x86_64-linux-gnu"
ACTION=""
FIRST_ARG_SET=""
OPTIMIZE_SIZE=false
OPENCV_VERSION="4.12.0"

# 解析命令行参数
for arg in "$@"; do
  case $arg in
    --target=*)
      TARGET="${arg#*=}"
      shift
      ;;
    --opencv-version=*)
      OPENCV_VERSION="${arg#*=}"
      shift
      ;;
    --optimize-size)
      OPTIMIZE_SIZE=true
      shift
      ;;
    clean)
      ACTION="clean"
      shift
      ;;
    clean-dist)
      ACTION="clean-dist"
      shift
      ;;
    --help)
      echo "用法: $0 [选项] [动作]"
      echo "选项:"
      echo "  --target=<目标>    指定目标架构 (默认: x86_64-linux-gnu)"
      echo "  --opencv-version=<版本>    指定OpenCV版本 (默认: 4.12.0)"
      echo "  --optimize-size    启用库文件大小优化 (保持性能)"
      echo "  --help             显示此帮助信息"
      echo ""
      echo "动作:"
      echo "  clean              清除build目录和缓存"
      echo "  clean-dist         清除build目录和install目录"
      echo ""
      echo "支持的目标架构示例:"
      echo "  x86_64-linux-gnu      - x86_64 Linux (GNU libc)"
      echo "  arm-linux-gnueabihf     - ARM64 32-bit Linux (GNU libc)"
      echo "  aarch64-linux-gnu     - ARM64 Linux (GNU libc)"
      echo "  arm-linux-android         - ARM 32-bit Android"   
      echo "  aarch64-linux-android     - ARM64 Android"
      echo "  x86-linux-android         - x86 32-bit Android"      
      echo "  x86_64-linux-android     - x86_64 Android"
      echo "  x86_64-windows-gnu    - x86_64 Windows (MinGW)"
      echo "  aarch64-windows-gnu    - aarch64 Windows (MinGW)"
      echo "  x86_64-macos          - x86_64 macOS"
      echo "  aarch64-macos         - ARM64 macOS"
      echo "  riscv64-linux-gnu      - RISC-V 64-bit Linux"      
      echo "  loongarch64-linux-gnu   - LoongArch64 Linux"
      echo "  aarch64-linux-harmonyos     - ARM64 HarmonyOS"
      echo "  arm-linux-harmonyos         - ARM 32-bit HarmonyOS"  
      echo "  x86_64-linux-harmonyos     - x86_64 harmonyos"
      exit 0
      ;;
    *)
      # 处理位置参数 (第一个参数作为target)
      if [ -z "$FIRST_ARG_SET" ]; then
        TARGET="$arg"
        FIRST_ARG_SET=1
      fi
      ;;
  esac
done

# 参数配置 - 调整为根目录结构
PROJECT_ROOT_DIR="$(pwd)"
OPENCV_SOURCE_DIR="$PROJECT_ROOT_DIR/opencv"
BUILD_TYPE="Release"
INSTALL_DIR="$PROJECT_ROOT_DIR/opencv_install/Release/${TARGET}"
BUILD_DIR="$PROJECT_ROOT_DIR/opencv_build/${TARGET}"

# 处理清理动作
if [ "$ACTION" = "clean" ]; then
    echo -e "${YELLOW}清理构建目录和缓存...${NC}"
    rm -rf "$PROJECT_ROOT_DIR/opencv_build"
    echo -e "${GREEN}构建目录已清理!${NC}"
    exit 0
elif [ "$ACTION" = "clean-dist" ]; then
    echo -e "${YELLOW}清理构建目录和安装目录...${NC}"
    rm -rf "$PROJECT_ROOT_DIR/opencv_build"
    rm -rf "$PROJECT_ROOT_DIR/opencv_install"
    echo -e "${GREEN}构建目录和安装目录已清理!${NC}"
    exit 0
fi

# 设置 CMake 交叉编译变量 - 基于原始目标而不是 Zig 目标
case "$TARGET" in
    arm-linux-*)
        CMAKE_SYSTEM_NAME="Linux"
        CMAKE_SYSTEM_PROCESSOR="arm"
        ;;
    aarch64-linux-*)
        CMAKE_SYSTEM_NAME="Linux"
        CMAKE_SYSTEM_PROCESSOR="arm64"
        ;;
    x86-linux-*)
        CMAKE_SYSTEM_NAME="Linux"
        CMAKE_SYSTEM_PROCESSOR="i686"
        ;;
    x86_64-linux-*)
        CMAKE_SYSTEM_NAME="Linux"
        CMAKE_SYSTEM_PROCESSOR="x86_64"
        ;;
    riscv64-linux-*)
        CMAKE_SYSTEM_NAME="Linux"
        CMAKE_SYSTEM_PROCESSOR="riscv64"
        ;;
    loongarch64-linux-*)
        CMAKE_SYSTEM_NAME="Linux"
        CMAKE_SYSTEM_PROCESSOR="loongarch64"
        ;;
    x86_64-windows-*)
        CMAKE_SYSTEM_NAME="Windows"
        CMAKE_SYSTEM_PROCESSOR="x86_64"
        ;;
    x86_64-macos*)
        CMAKE_SYSTEM_NAME="Darwin"
        CMAKE_SYSTEM_PROCESSOR="x86_64"
        ;;
    aarch64-macos*)
        CMAKE_SYSTEM_NAME="Darwin"
        CMAKE_SYSTEM_PROCESSOR="arm64"
        ;;
esac

# 函数：下载并解压 opencv 源码
download_opencv() {
    local source_dir="$1"
    local opencv_version="$2"
    local download_url="https://github.com/opencv/opencv.git"
    
    echo -e "${YELLOW}检查 opencv 源码目录...${NC}"
    
    # 检查源码目录是否存在
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}源码目录已存在: $source_dir${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}源码目录不存在，开始下载 opencv...${NC}"
    
    # 检查必要的工具
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误: 需要 git 来下载文件${NC}"
        exit 1
    fi
    
    # 创建临时下载目录
    
    echo -e "${BLUE}下载地址: $download_url${NC}"
    echo -e "${BLUE}下载到: $source_dir${NC}"
    
    # 下载文件
    git clone -b $opencv_version --depth=1 $download_url $source_dir
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败: $download_url${NC}"
        rm -rf "$archive_path"
        exit 1
    fi
    
    
    # 验证解压结果
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}opencv 源码准备完成: $source_dir${NC}"
    else
        echo -e "${RED}解压后未找到预期的源码目录: $source_dir${NC}"
        exit 1
    fi
}

# 下载并准备 opencv 源码
download_opencv "$OPENCV_SOURCE_DIR" "$OPENCV_VERSION"


# 检查Zig是否安装
if ! command -v zig &> /dev/null; then
    echo -e "${RED}错误: 未找到Zig。请安装Zig: https://ziglang.org/download/${NC}"
    exit 1
fi

# 检查CMake是否安装
if ! command -v cmake &> /dev/null; then
    echo -e "${RED}错误: 未找到CMake。请安装CMake: https://cmake.org/download/${NC}"
    exit 1
fi

# 检查OPENCV源码目录和CMakeLists.txt是否存在
if [ ! -d "$OPENCV_SOURCE_DIR" ]; then
    echo -e "${RED}错误: OPENCV源码目录不存在: $OPENCV_SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -f "$OPENCV_SOURCE_DIR/CMakeLists.txt" ]; then
    echo -e "${RED}错误: OPENCV CMakeLists.txt文件不存在: $OPENCV_SOURCE_DIR/CMakeLists.txt${NC}"
    exit 1
fi

# 大小优化配置
if [ "$OPTIMIZE_SIZE" = true ]; then
    # 大小优化标志
    ZIG_OPTIMIZE_FLAGS="-Os -DNDEBUG -ffunction-sections -fdata-sections"
    export LDFLAGS="-Wl,--gc-sections -Wl,--strip-all"
else
    ZIG_OPTIMIZE_FLAGS="-O2 -DNDEBUG"
    export LDFLAGS=""
fi

# 创建安装目录
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 创建OPENCV构建目录（每次都清理，避免 CMake 缓存污染）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 进入构建目录
cd "$BUILD_DIR"

# 根据目标平台配置编译器和工具链
if [[ "$TARGET" == *"-linux-android"* ]]; then
    # 检查 Android NDK
    export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME:-~/sdk/android_ndk/android-ndk-r21e}"
    if [ ! -d "$ANDROID_NDK_ROOT" ]; then
        echo -e "${RED}错误: Android NDK 未找到: $ANDROID_NDK_ROOT${NC}"
        echo -e "${RED}请设置 ANDROID_NDK_HOME 环境变量${NC}"
        exit 1
    fi
    HOST_TAG=linux-x86_64
    TOOLCHAIN=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG
    export PATH=$TOOLCHAIN/bin:$PATH
    ANDROID_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
    ANDROID_PLATFORM=android-21

    case "$TARGET" in
        aarch64-linux-android)
            ANDROID_ABI=arm64-v8a
            ;;
        arm-linux-android)
            ANDROID_ABI=armeabi-v7a
            ;;
        x86_64-linux-android)
            ANDROID_ABI=x86_64
            ;;
        x86-linux-android)
            ANDROID_ABI=x86
            ;;
        *)
            echo -e "${RED}未知的 Android 架构: $TARGET${NC}"
            exit 1
            ;;
    esac
    
    # toolchain 参数必须最前，其它参数和源码目录最后
    CMAKE_CMD="cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_TOOLCHAIN_FILE -DANDROID_ABI=$ANDROID_ABI -DANDROID_PLATFORM=$ANDROID_PLATFORM -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    
elif [[ "$TARGET" == *"-linux-harmonyos"* ]]; then
    # 检查 HarmonyOS SDK
    export HARMONYOS_SDK_ROOT="${HARMONYOS_SDK_HOME:-~/sdk/harmonyos/ohos-sdk/linux/native-linux-x64-4.1.9.4-Release/native}"
    if [ ! -d "$HARMONYOS_SDK_ROOT" ]; then
        echo -e "${RED}错误: HarmonyOS SDK 未找到: $HARMONYOS_SDK_ROOT${NC}"
        echo -e "${RED}请设置 HARMONYOS_SDK_HOME 环境变量${NC}"
        exit 1
    fi
    TOOLCHAIN=$HARMONYOS_SDK_ROOT/llvm
    export PATH=$TOOLCHAIN/bin:$PATH
    HARMONYOS_TOOLCHAIN_FILE="$HARMONYOS_SDK_ROOT/build/cmake/ohos.toolchain.cmake"

    case "$TARGET" in
        aarch64-linux-harmonyos)
            OHOS_ARCH=arm64-v8a
            ;;
        arm-linux-harmonyos)
            OHOS_ARCH=armeabi-v7a
            ;;
        x86_64-linux-harmonyos)
            OHOS_ARCH=x86_64
            ;;
        x86-linux-harmonyos)
            OHOS_ARCH=x86
            ;;
        *)
            echo -e "${RED}未知的 HarmonyOS 架构: $TARGET${NC}"
            exit 1
            ;;
    esac

    
    # toolchain 参数必须最前，其它参数和源码目录最后
    CMAKE_CMD="cmake -DCMAKE_TOOLCHAIN_FILE=$HARMONYOS_TOOLCHAIN_FILE -DOHOS_ARCH=$OHOS_ARCH -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
else
    
    # 使用 Zig 作为编译器
    ZIG_PATH=$(command -v zig)
    
    # 为 Zig 编译器设置正确的参数格式
    ZIG_CC_WRAPPER="$PROJECT_ROOT_DIR/zig_cc_wrapper.sh"
    ZIG_CXX_WRAPPER="$PROJECT_ROOT_DIR/zig_cxx_wrapper.sh"
    
    # 创建 Zig CC 包装器脚本，处理潜在的参数兼容性问题
    cat > "$ZIG_CC_WRAPPER" << EOF
#!/bin/bash
# Zig CC 包装器 - 确保参数兼容性
exec zig cc -target $TARGET $ZIG_OPTIMIZE_FLAGS "\$@"
EOF

    # 创建 Zig CXX 包装器脚本
    cat > "$ZIG_CXX_WRAPPER" << EOF
#!/bin/bash
# Zig C++ 包装器 - 确保参数兼容性
exec zig c++ -target $TARGET $ZIG_OPTIMIZE_FLAGS "\$@"
EOF
    
    # 设置执行权限
    chmod +x "$ZIG_CC_WRAPPER"
    chmod +x "$ZIG_CXX_WRAPPER"
    
    export CC="$ZIG_CC_WRAPPER"
    export CXX="$ZIG_CXX_WRAPPER"
    
    echo -e "${BLUE}Zig 编译器配置:${NC}"
    echo -e "${BLUE}  原始目标: $TARGET${NC}"
    echo -e "${BLUE}  Zig 目标: $TARGET${NC}"
    echo -e "${BLUE}  CMake 系统名: $CMAKE_SYSTEM_NAME${NC}"
    echo -e "${BLUE}  CMake 处理器: $CMAKE_SYSTEM_PROCESSOR${NC}"
    echo -e "${BLUE}  大小优化: $OPTIMIZE_SIZE${NC}"
    echo -e "${BLUE}  CC: $CC${NC}"
    echo -e "${BLUE}  CXX: $CXX${NC}"
    
    CMAKE_CMD="cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
fi

# 添加模块配置参数opencv4_cmake_options
# 读取 opencv4_cmake_options.txt 文件中的参数并追加到 CMAKE_CMD
OPTIONS_FILE="$PROJECT_ROOT_DIR/opencv4_cmake_options.txt"
if [ -f "$OPTIONS_FILE" ]; then
    echo -e "${YELLOW}读取 OpenCV 配置参数: $OPTIONS_FILE${NC}"
    while IFS= read -r line; do
        # 跳过空行和注释行
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            CMAKE_CMD="$CMAKE_CMD $line"
        fi
    done < "$OPTIONS_FILE"
    echo -e "${GREEN}已应用 OpenCV 配置参数${NC}"
else
    echo -e "${YELLOW}警告: 未找到配置文件 $OPTIONS_FILE，将使用默认配置${NC}"
fi


# 添加源码目录 - 指向opencv子目录
CMAKE_CMD="$CMAKE_CMD $OPENCV_SOURCE_DIR"

# 打印配置信息
echo -e "${BLUE}OPENCV 构建配置:${NC}"
echo -e "${BLUE}  目标架构: $TARGET${NC}"
echo -e "${BLUE}  OpenCV版本: $OPENCV_VERSION${NC}"
echo -e "${BLUE}  项目根目录: $PROJECT_ROOT_DIR${NC}"
echo -e "${BLUE}  源码目录: $OPENCV_SOURCE_DIR${NC}"
echo -e "${BLUE}  构建目录: $BUILD_DIR${NC}"
echo -e "${BLUE}  构建类型: $BUILD_TYPE${NC}"
echo -e "${BLUE}  安装目录: $INSTALL_DIR${NC}"

# 执行CMake配置
echo -e "${GREEN}执行配置: $CMAKE_CMD${NC}"
eval "$CMAKE_CMD"

if [ $? -ne 0 ]; then
    echo -e "${RED}CMake配置失败!${NC}"
    exit 1
fi

# 编译
echo -e "${GREEN}开始编译OPENCV...${NC}"
cmake --build . --config Release --parallel

if [ $? -ne 0 ]; then
    echo -e "${RED}编译OPENCV失败!${NC}"
    exit 1
fi

# 安装
echo -e "${GREEN}开始安装...${NC}"
cmake --install . --config Release

# 检查安装结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}安装成功!${NC}"
    # "修改 pkg-config 文件路径..."
    #find "${INSTALL_DIR}/lib/pkgconfig" -name "*.pc" -exec sed -i "s|^prefix=.*|prefix=/usr|g" {} \;    # 如果启用了大小优化，进行额外的压缩处理
    
    if [ "$OPTIMIZE_SIZE" = true ]; then
        echo -e "${YELLOW}执行额外的库文件压缩...${NC}"
        
        # 检查strip工具是否可用，优先使用平台特定的工具
        STRIP_TOOL="strip"
        
        if [[ "$TARGET" == *"-linux-android"* ]]; then
            # Android 使用 NDK 的 strip 工具
            if [ -n "$TOOLCHAIN" ] && [ -f "$TOOLCHAIN/bin/llvm-strip" ]; then
                STRIP_TOOL="$TOOLCHAIN/bin/llvm-strip"
            elif command -v "llvm-strip" &> /dev/null; then
                STRIP_TOOL="llvm-strip"
            fi
        elif [[ "$TARGET" == *"-linux-harmonyos"* ]]; then
            # HarmonyOS 使用 SDK 的 strip 工具
            if [ -n "$TOOLCHAIN" ] && [ -f "$TOOLCHAIN/bin/llvm-strip" ]; then
                STRIP_TOOL="$TOOLCHAIN/bin/llvm-strip"
            elif command -v "llvm-strip" &> /dev/null; then
                STRIP_TOOL="llvm-strip"
            fi
        else
            # 其他平台使用通用的 strip 工具
            if command -v "${TARGET%-*}-strip" &> /dev/null; then
                STRIP_TOOL="${TARGET%-*}-strip"
            elif command -v "llvm-strip" &> /dev/null; then
                STRIP_TOOL="llvm-strip"
            fi
        fi
        
        echo -e "${BLUE}使用 strip 工具: $STRIP_TOOL${NC}"
        
        # 压缩所有共享库
        if [ -d "$INSTALL_DIR/lib" ]; then
            find "$INSTALL_DIR/lib" -name "*.so*" -type f -exec $STRIP_TOOL --strip-unneeded {} \; 2>/dev/null || true
            find "$INSTALL_DIR/lib" -name "*.a" -type f -exec $STRIP_TOOL --strip-debug {} \; 2>/dev/null || true
            echo -e "${GREEN}库文件压缩完成!${NC}"
        fi
        
    fi
    
    echo -e "${GREEN}OPENCV库文件位于: $INSTALL_DIR/lib/${NC}"
    echo -e "${GREEN}OPENCV头文件位于: $INSTALL_DIR/include/${NC}"
    
    # 显示安装的文件和大小
    if [ -d "$INSTALL_DIR/lib" ]; then
        echo -e "${BLUE}安装的库文件:${NC}"
        find "$INSTALL_DIR/lib" -name "*.so*" -o -name "*.a" | head -10 | while read file; do
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo "  $file ($size)"
        done
    fi
    
    if [ -d "$INSTALL_DIR/include" ]; then
        echo -e "${BLUE}安装的头文件目录:${NC}"
        find "$INSTALL_DIR/include" -type d | head -5
    fi
    
    # 返回到项目根目录
    cd "$PROJECT_ROOT_DIR"
else
    echo -e "${RED}安装OPENCV失败!${NC}"
    exit 1
fi
