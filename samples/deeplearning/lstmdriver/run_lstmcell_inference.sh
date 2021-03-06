#!/usr/bin/env sh
###############################################################################
# Copyright (c) Intel Corporation - All rights reserved.                      #
# This file is part of the LIBXSMM library.                                   #
#                                                                             #
# For information on the license, see the LICENSE file.                       #
# Further information: https://github.com/hfp/libxsmm/                        #
# SPDX-License-Identifier: BSD-3-Clause                                       #
###############################################################################
# Hans Pabst (Intel Corp.), Kunal Banerjee (Intel Corp.)
###############################################################################
set -eo pipefail

UNAME=$(command -v uname)
SORT=$(command -v sort)
GREP=$(command -v grep)
CUT=$(command -v cut)
WC=$(command -v wc)
TR=$(command -v tr)

if [ "" = "${CHECK}" ] || [ "0" = "${CHECK}" ]; then
  if [ "" = "${CHECK_DNN_MB}" ]; then CHECK_DNN_MB=64; fi
  if [ "" = "${CHECK_DNN_ITERS}" ]; then CHECK_DNN_ITERS=1000; fi
else # check
  if [ "" = "${CHECK_DNN_MB}" ]; then CHECK_DNN_MB=64; fi
  if [ "" = "${CHECK_DNN_ITERS}" ]; then CHECK_DNN_ITERS=1; fi
fi

if [ $# -ne 8 ]
then
  echo "Usage: $(basename $0) format=(nc_ck, nc_kcck) bin=(f32, bf16) iters type=(0-fwd, 1-bwd, 2-upd, 3-bwdupd)"
  FORMAT=nc_ck
  BIN=f32
  ITERS=${CHECK_DNN_ITERS}
  TYPE=0
else
  FORMAT=$1
  BIN=$2
  ITERS=$3
  TYPE=$4
fi

if [ "" != "${GREP}" ] && [ "" != "${CUT}" ] && [ "" != "${SORT}" ] && [ "" != "${WC}" ] && [ -e /proc/cpuinfo ]; then
  export NS=$(${GREP} "physical id" /proc/cpuinfo | ${SORT} -u | ${WC} -l | ${TR} -d " ")
  export NC=$((NS*$(${GREP} -m1 "cpu cores" /proc/cpuinfo | ${TR} -d " " | ${CUT} -d: -f2)))
  export NT=$(${GREP} "core id" /proc/cpuinfo | ${WC} -l | ${TR} -d " ")
elif [ "" != "${UNAME}" ] && [ "" != "${CUT}" ] && [ "Darwin" = "$(${UNAME})" ]; then
  export NS=$(sysctl hw.packages | ${CUT} -d: -f2 | tr -d " ")
  export NC=$(sysctl hw.physicalcpu | ${CUT} -d: -f2 | tr -d " ")
  export NT=$(sysctl hw.logicalcpu | ${CUT} -d: -f2 | tr -d " ")
fi
if [ "" != "${NC}" ] && [ "" != "${NT}" ]; then
  export HT=$((NT/(NC)))
else
  export NS=1 NC=1 NT=1 HT=1
fi
if [ "" != "${GREP}" ] && [ "" != "${CUT}" ] && [ "" != "$(command -v numactl)" ]; then
  export NN=$(numactl -H | ${GREP} available: | ${CUT} -d' ' -f2)
else
  export NN=${NS}
fi

if [ "" = "${OMP_NUM_THREADS}" ] || [ "0" = "${OMP_NUM_THREADS}" ]; then
  if [ "" = "${KMP_AFFINITY}" ]; then
    export KMP_AFFINITY=compact,granularity=fine KMP_HW_SUBSET=1T
  fi
  export OMP_NUM_THREADS=$((NC))
fi

if [ "" = "${MB}" ] || [ "0" = "${MB}" ]; then
  MB=${OMP_NUM_THREADS}
fi

if [ "" = "${LIBXSMM_TARGET_HIDDEN}" ] || [ "0" = "${LIBXSMM_TARGET_HIDDEN}" ]; then
  echo "OMP_NUM_THREADS=${OMP_NUM_THREADS} NUMACTL=\"${NUMACTL}\""
  echo
fi

##### using the optimal block size as mentioned in emails
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 10 1024 512 1 10 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 10 1024 512 1 10 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 101  1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 10 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 20 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 30 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 40 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 50 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 60 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 256 256 70 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 101 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 10 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 20 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 30 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 40 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 50 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 60 1 32 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 1 512 512 70 1 32 64

./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 640 1024 512 1 64 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 640 1024 512 1 64 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 101 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 10 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 20 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 30 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 40 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 50 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 60 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 256 256 70 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 101 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 10 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 20 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 30 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 40 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 50 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 60 4 64 64
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} 64 512 512 70 4 64 64

