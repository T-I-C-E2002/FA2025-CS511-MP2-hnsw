#!/usr/bin/env bash
set -euo pipefail

# Install prerequisites
sudo apt-get update -qq
sudo apt-get install -y -qq git cmake build-essential libaio-dev libnuma-dev

# Clone & build
if [ ! -d "DiskANN" ]; then
  git clone --depth=1 https://github.com/microsoft/DiskANN.git
fi
cmake -S DiskANN -B DiskANN/build -DCMAKE_BUILD_TYPE=Release
cmake --build DiskANN/build -j

echo "Built DiskANN tools in DiskANN/build/tools"
ls -1 DiskANN/build/tools
