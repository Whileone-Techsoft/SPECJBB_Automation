#!/bin/bash
# Copyright (c) 2018-2023 Ampere Computing. All rights reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# System level tunings
set -x
sudo ./sys22.sh; sleep 10
#
# System configs dump (disable this line if dumping not work)
./dump_sys.sh -n >dump_sys.log 2>&1
if [ -f machine_cfg.env ]; then cat machine_cfg.env; fi
if [ -f machine_cfg.log ]; then cat machine_cfg.log; fi
#
set -e
wpid=
function _finally {
  if [ $(ps ${wpid} >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ]; then kill -9 ${wpid}; fi
}
trap _finally EXIT

EXPT=EXP1
mkdir -p ${EXPT}
NUM_THREADS=8
GC_CONTRL=2
GC_BACKND=8
GC_TXTINJCTR=2
CPUBIND="1-${NUM_THREADS}"
#Xmx1=${NUM_THREADS}
#Xmx3=$(echo "scale=2; ${NUM_THREADS}*0.9" | bc)
#Xmx4=$(printf "%.0f" "$Xmx3")
#BackendXmx1=$((${NUM_THREADS}*4))
#BackendXmx2=$(echo "scale=2; ${BackendXmx1}*0.9" | bc)
#BackendXmx3=$(printf "%.0f" "$BackendXmx2")
Xmx1=2
Xmx4=1536
BackendXmx1=16
BackendXmx3=15
#export JAVA_HOME=java-versions/jdk1.8.0_401
#export PATH=java-versions/jdk1.8.0_401/bin:$PATH
# CTRL 0
stdbuf -o0 numactl --physcpubind=${CPUBIND} --membind=0 java -Xmx${Xmx1}g -Xms${Xmx1}g -Xmn${Xmx4}m -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_CONTRL} -XX:+PreserveFramePointer -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:CICompilerCount=2 -Dspecjbb.forkjoin.workers=${NUM_THREADS} -Dspecjbb.group.count=1 -Dspecjbb.controller.type=HBIR_RT -Dspecjbb.controller.port=24000 -jar specjbb2015.jar -m MULTICONTROLLER 2>&1 | tee -a ${EXPT}/jbb_runlog0_controller_0_${NUM_THREADS}_${GC_CONTRL}.log &
# Group 0.0 BE 0
stdbuf -o0 numactl --physcpubind=${CPUBIND} --membind=0 java -Xmx${BackendXmx1}g -Xms${BackendXmx1}g -Xmn${BackendXmx3}g -XX:MaxTenuringThreshold=15 -XX:SurvivorRatio=10 -XX:TargetSurvivorRatio=90 -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_BACKND} -XX:+PreserveFramePointer -XX:-UseBiasedLocking -XX:-UseAdaptiveSizePolicy -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:+PrintFlagsFinal -Dspecjbb.controller.port=24000 -jar specjbb2015.jar -m BACKEND -G=Group0 -J=beJVM0 >> ${EXPT}/jbb_runlog0_backend_0_${NUM_THREADS}_${GC_CONTRL}.log 2>&1 &
# Group 0.0 TXI 0
stdbuf -o0 numactl --physcpubind=${CPUBIND} --membind=0 java -Xmx${Xmx1}g -Xms${Xmx1}g -Xmn${Xmx4}m -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_TXTINJCTR} -XX:+PreserveFramePointer -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:CICompilerCount=2 -Dspecjbb.controller.port=24000 -jar specjbb2015.jar -m TXINJECTOR -G=Group0 -J=txiJVM0 >> ${EXPT}/jbb_runlog0_txinjector_0_${NUM_THREADS}_${GC_CONTRL}.log 2>&1 &
if [ "x$(basename $(pwd))" = "xjbb_test" ]; then
  echo "Not to wait for completion if running in jbb_test dir."
else
  echo "Wait for the completion."
  wpid=$(ps -eafww | grep -Fv -e grep -e numactl | grep -E "(MULTI|DIST)CONTROLLER" | awk '{print $2;}' | tail -n 1)
  if [[ ${wpid} =~ ^[0-9]+$  ]]; then
    tail --pid=${wpid} -f /dev/null -s 10
  fi
  echo "Wait 10s for cooling down."
  sleep 10
fi
#
# Check the result
sleep 10;./check.sh
