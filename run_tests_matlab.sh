#!/bin/bash

WORK_DIR=$(mktemp -d)

git -C $WORK_DIR clone https://bitbucket.org/ustb/ustb/
git -C $WORK_DIR/ustb checkout develop

export USTB_REPO=$WORK_DIR/ustb
MATLAB_ROOT=$PWD/../
export MATLABPATH=$MATLAB_ROOT

echo "Hello from the server!"

rm -rf $WORK_DIR
