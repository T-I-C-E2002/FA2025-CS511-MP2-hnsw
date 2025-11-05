#!/usr/bin/env bash
set -euo pipefail

DATA=""
PREFIX=""
DIST="l2"
R=64
LBUILD=128
PQ=0
BUILD_DRAM_GB=8
DATA_TYPE="float"     # <-- float | int8 | uint8 (SIFT .fbin == float)
DATA_DIM=""           # <-- auto-detected from .fbin if empty
PYTHON_BIN="${PYTHON:-python3}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data) DATA="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    --dist) DIST="$2"; shift 2;;
    --R) R="$2"; shift 2;;
    --Lbuild) LBUILD="$2"; shift 2;;
    --pq_bytes) PQ="$2"; shift 2;;
    --build_dram_gb|--build_DRAM_budget) BUILD_DRAM_GB="$2"; shift 2;;
    --data_type) DATA_TYPE="$2"; shift 2;;        # float/int8/uint8
    --data_dim) DATA_DIM="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --data <base.fbin> --prefix <index_prefix> [--dist l2] [--R 64] [--Lbuild 128] [--pq_bytes 0] [--build_dram_gb 8] [--data_type float] [--data_dim 128]"
      exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

[[ -n "$DATA" && -n "$PREFIX" ]] || { echo "Missing --data or --prefix"; exit 1; }

# Auto-detect dim from .fbin header if not provided
if [[ -z "${DATA_DIM}" ]]; then
  if [[ ! -f "$DATA" ]]; then
    echo "Data file not found: $DATA"; exit 1
  fi
  DATA_DIM="$($PYTHON_BIN - <<'PY'
import struct, sys
p = sys.argv[1]
with open(p,"rb") as f:
    n,d = struct.unpack("II", f.read(8))
print(d)
PY
"$DATA")"
fi

BIN="./DiskANN/build/apps"
BUILD_BIN="$BIN/build_ondisk_index"
[[ -x "$BUILD_BIN" ]] || BUILD_BIN="$BIN/build_disk_index"
[[ -x "$BUILD_BIN" ]] || { echo "DiskANN build tool not found in $BIN"; exit 1; }

echo "Building DiskANN on-disk index:"
echo "  data=$DATA  prefix=$PREFIX  dist=$DIST  R=$R  Lbuild=$LBUILD  pq_bytes=$PQ  build_DRAM_GB=$BUILD_DRAM_GB  data_type=$DATA_TYPE  data_dim=$DATA_DIM"

set -x
"$BUILD_BIN" \
  --data_path "$DATA" \
  --index_path_prefix "$PREFIX" \
  --dist_fn "$DIST" \
  --max_degree "$R" \
  --Lbuild "$LBUILD" \
  --build_PQ_bytes "$PQ" \
  --build_DRAM_budget "$BUILD_DRAM_GB" \
  --data_type "$DATA_TYPE" \
  --data_dim "$DATA_DIM"
set +x
echo "Done."
