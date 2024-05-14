#!/bin/bash
set -x

for i in {6..8}; do
	./run.sh 8 $i $i $i
	sleep 5
done

./run.sh 8 2 8 2
sleep 5
./run.sh 8 1 8 1
sleep 5
./run.sh 8 2 16 2
