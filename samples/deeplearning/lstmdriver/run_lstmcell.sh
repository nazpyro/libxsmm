#!/usr/bin/env bash
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
  echo "Usage: $(basename $0) format=(nc_ck, nc_kcck) bin=(f32, bf16) iters type=(0-fwd, 1-bwd, 2-upd, 3-bwdupd) MB bn bc bk"
  FORMAT=nc_ck
  BIN=f32
  ITERS=${CHECK_DNN_ITERS}
  TYPE=0
  MB=${CHECK_DNN_MB}
  BN=32
  BC=32
  BK=32
else
  FORMAT=$1
  BIN=$2
  ITERS=$3
  TYPE=$4
  MB=$5
  BN=$6
  BC=$7
  BK=$8
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

./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 512 256 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 128 1024 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 512 512 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 1024 1024 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 2048 2048 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 768 1536 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 1024 512 1 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 256 256 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 512 512 5 ${BN} ${BC} ${BK}
./lstmdriver_${FORMAT}_${BIN} ${ITERS} ${TYPE} ${MB} 4096 4096 5 ${BN} ${BC} ${BK}

