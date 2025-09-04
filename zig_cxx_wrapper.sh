#!/bin/bash
# Zig C++ 包装器 - 确保参数兼容性
exec zig c++ -target aarch64-linux-gnu -Os -DNDEBUG -ffunction-sections -fdata-sections "$@"
