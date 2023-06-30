#!/bin/bash

WORK_DIR=$(mktemp -d)

git -C $WORK_DIR clone https://bitbucket.org/ustb/ustb/
git -C $WORK_DIR/ustb checkout develop

export USTB_REPO=$WORK_DIR/ustb
MATLAB_ROOT=$PWD/../
export MATLABPATH=$MATLAB_ROOT

matlab -batch run_tests_matlab

rm -rf $WORK_DIR
