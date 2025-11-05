#!/usr/bin/env bash
set -euo pipefail

PREFIX=""
QUERIES=""
DIST="l2"
K=1
BEAM=2
L_LIST="32,64,96,128,160,200"
OUTDIR="./results"
GT_IBIN=""   # optional; if provided, we compute recall@1
PYTHON_BIN="${PYTHON:-python3}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2;;
    --queries) QUERIES="$2"; shift 2;;
    --dist) DIST="$2"; shift 2;;
    --K) K="$2"; shift 2;;
    --beamwidth) BEAM="$2"; shift 2;;
    --L_list) L_LIST="$2"; shift 2;;
    --outdir) OUTDIR="$2"; shift 2;;
    --gt) GT_IBIN="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --prefix <index_prefix> --queries <query.fbin> [--dist l2] [--K 1] [--beamwidth 2] [--L_list '32,64,96,128'] [--outdir ./results] [--gt sift_gt.ibin]"
      exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "$PREFIX" || -z "$QUERIES" ]]; then
  echo "Missing --prefix or --queries"; exit 1
fi
mkdir -p "$OUTDIR"

BIN="./DiskANN/build/apps"
SEARCH_BIN="$BIN/search_disk_index"
if [[ ! -x "$SEARCH_BIN" ]]; then
  echo "DiskANN search tool not found in $BIN"; exit 1
fi

CSV="$OUTDIR/latency_recall.csv"
echo "L,avg_latency_ms,recall_at_1" > "$CSV"

IFS=',' read -r -a Ls <<< "$L_LIST"
for L in "${Ls[@]}"; do
  OUT="$OUTDIR/res_L${L}.ids"
  echo "search_L=$L ..."
  t0=$($PYTHON_BIN - <<'PY'
import time; print(time.time())
PY
)
  "$SEARCH_BIN" \
    --index_path_prefix "$PREFIX" \
    --query_file "$QUERIES" \
    --dist_fn "$DIST" \
    --K "$K" \
    --beamwidth "$BEAM" \
    --search_L "$L" \
    --result_path "$OUT"
  t1=$($PYTHON_BIN - <<'PY'
import time; print(time.time())
PY
)
  # number of queries
  NQ=$($PYTHON_BIN - <<PY
import struct, sys
with open("$QUERIES","rb") as f:
    n,d = struct.unpack("II", f.read(8))
print(n)
PY
)
  elapsed=$(python3 - <<PY
t0=float("$t0"); t1=float("$t1"); nq=int("$NQ")
print((t1 - t0) * 1000.0 / nq)
PY
)
  # recall@1 if GT provided
  if [[ -n "$GT_IBIN" ]]; then
    REC=$($PYTHON_BIN - <<PY
import struct, numpy as np
def read_ibin(p):
    with open(p,"rb") as f:
        n,k = struct.unpack("II", f.read(8))
        I = np.fromfile(f, dtype=np.uint32, count=n*k).reshape(n,k)
    return I
def read_ids(p, nq, k):
    return np.fromfile(p, dtype=np.uint32, count=nq*k).reshape(n,k)
# get nq
with open("$QUERIES","rb") as f:
    nq,_ = struct.unpack("II", f.read(8))
I = read_ids("$OUT", nq, $K)
GT = read_ibin("$GT_IBIN")
recall = (I[:,0].astype(np.int64) == GT[:,0]).mean()
print(f"{recall:.6f}")
PY
)
  else
    REC=""
  fi
  echo "$L,$elapsed,${REC}" | tee -a "$CSV"
done

echo "Wrote $CSV and per-L id files to $OUTDIR"
