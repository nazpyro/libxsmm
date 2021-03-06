#!/usr/bin/env bash
###############################################################################
# Copyright (c) Intel Corporation - All rights reserved.                      #
# This file is part of the LIBXSMM library.                                   #
#                                                                             #
# For information on the license, see the LICENSE file.                       #
# Further information: https://github.com/hfp/libxsmm/                        #
# SPDX-License-Identifier: BSD-3-Clause                                       #
###############################################################################
# Hans Pabst (Intel Corp.)
###############################################################################

PATTERNS="*.c *.cc *.cpp *.cxx *.h *.hpp *.hxx *.f *.F90 *.fh *.py *.sh *.env *.yml *.txt *.slurm"
BANNED_CHARS="\t"

PATBAN="s/[${BANNED_CHARS}]/"
PATEOL="s/\r$/"
PATSPC="s/[[:space:]][[:space:]]*$/"

HERE=$(cd "$(dirname "$0")"; pwd -P)
REPO=${HERE}/..
CODEFILE=${REPO}/.codefile
MKTEMP=${REPO}/.mktmp.sh
# separate multiple patterns with space
FMTDIRS=${2:-"samples src tests"}
FMTXPAT="/gxm/"
DIR=$1

FMTBIN=$(command -v clang-format)
FLAKE8=$(command -v flake8)
ICONV=$(command -v iconv)
DIFF=$(command -v diff)
GIT=$(command -v git)
SED=$(command -v sed)
CUT=$(command -v cut)
TR=$(command -v tr)
CP=$(command -v cp)
RM=$(command -v rm)

if [ "${ICONV}" ]; then
  CAT="${ICONV} -t ASCII"
else
  CAT=$(command -v cat)
fi

if [ "${CAT}" ] && [ -e "${CODEFILE}" ]; then
  PATTERNS="$(${CAT} "${CODEFILE}")"
fi

if [ "${FLAKE8}" ] && [ "0" = "$(${FLAKE8} 2>&1 >/dev/null; echo $?)" ] && \
   [ "0" != "$(${FLAKE8} ${HERE}/*.py 2>&1 >/dev/null; echo $?)" ];
then
  echo "Warning: some Python scripts do not pass flake8 check (${HERE})!"
fi

if [ ! "${FMTBIN}" ] || [ "$(${FMTBIN} --style=file -dump-config 2>&1 >/dev/null)" ]; then
  echo "Warning: missing compatible \"clang-format\" command!"
  FMTBIN=""
fi

if [ "${SED}" ] && [ "${CUT}" ] && [ "${TR}" ] && \
   [ "${GIT}" ] && [ "${CP}" ] && [ "${RM}" ] && \
   [ "${CAT}" ] && [ "${MKTEMP}" ];
then
  TMPF=$("${MKTEMP}" .libxsmm_XXXXXX.txt)
  # disable glob in Shell
  set -f
  # Search the content of the diffs matching the given file types
  for PATTERN in ${PATTERNS} *Makefile*; do
  for FILE in $(${GIT} ls-files ${PATTERN}); do
    if [[ "${DIR}" && (${FILE} != "${DIR}/"*) ]]; then continue; fi
    echo -n "${FILE}"
    #
    # Reformat code (fallback: check for banned characters).
    #
    REFORMAT=0
    if [[ "${FMTBIN}" && (-e ${REPO}/.clang-format) \
       && ((${FILE} = *".c"*) || (${FILE} = *".h"*)) ]];
    then
      if [ "" = "${FMTDIRS}" ]; then REFORMAT=1; fi
      for FMTDIR in ${FMTDIRS}; do
        if [[ ${FILE} = "${FMTDIR}/"* ]]; then
          REFORMAT=1; break
        fi
      done
      if [ "0" != "${REFORMAT}" ]; then
        for XPAT in ${FMTXPAT}; do
          if [[ ${FILE} = *"${XPAT}"* ]]; then
            REFORMAT=0; break
          fi
        done
      fi
    fi
    if [ "0" != "${REFORMAT}" ]; then
      if [ "0" = "$(${FMTBIN} --style=file ${FILE} > ${TMPF}; echo $?)" ] && \
         [ "1" = "$(${DIFF} ${FILE} ${TMPF} >/dev/null; echo $?)" ];
      then
        ${CP} ${TMPF} ${FILE}
        echo -n " : reformatted"
      else
        REFORMAT=0
      fi
    elif [[ ${FILE} != *"Makefile"* ]] && \
         [ "$(${SED} -n "${PATBAN}x/p" ${FILE} 2>/dev/null)" ];
    then
      echo -n " : has banned characters"
      REFORMAT=1
    elif [ "$(${SED} -n "s/\([^[:space:]]\)\t/\1 /gp" ${FILE})" ]; then
      ${SED} -e "s/\([^[:space:]]\)\t/\1 /g" ${FILE} > ${TMPF}
      ${CP} ${TMPF} ${FILE}
      echo -n " : removed tabs"
      REFORMAT=1
    fi
    #
    # Check for non-UNIX line-endings.
    #
    if [ "$(${SED} -n "${PATEOL}x/p" ${FILE} 2>/dev/null | ${TR} -d "\n")" ]; then
      echo -n " : has non-UNIX line endings"
      REFORMAT=1
    fi
    if [ "$(${SED} -n "${PATSPC}x/p" ${FILE})" ]; then
      ${SED} -e "${PATSPC}/" ${FILE} > ${TMPF}
      ${CP} ${TMPF} ${FILE}
      echo -n " : removed trailing spaces"
      REFORMAT=1
    fi
    #
    # Check and fix executable flag of file under source control.
    #
    FLAGS=$(${GIT} ls-files -s ${FILE} | ${CUT} -d' ' -f1)
    if [ "*.sh" = "${PATTERN}" ] || [ "*.py" = "${PATTERN}" ]; then
      if [ "$(${SED} -n '1!b;/#!/p' ${FILE})" ] && \
         [ "100755" != "${FLAGS}" ];
      then
        ${GIT} update-index --chmod=+x ${FILE}
        echo -n " : marked executable"
        REFORMAT=1
      fi
    elif [ "100644" != "${FLAGS}" ] && [ "120000" != "${FLAGS}" ]; then
      ${GIT} update-index --chmod=-x ${FILE}
      echo -n " : marked non-executable"
      REFORMAT=1
    fi
    if [ "0" != "${REFORMAT}" ]; then
      echo
    else
      echo " : OK"
    fi
  done
  done
  ${RM} -f ${TMPF} .libxsmm_??????.txt
  echo "Successfully Completed."
  exit 0
fi

echo "Error: missing prerequisites!"
exit 1

