#!/bin/bash

WORK_DIR=$(mktemp -d)

git -C $WORK_DIR clone https://github.com/unioslo/USTB
git -C $WORK_DIR/ustb checkout develop

export USTB_REPO=$WORK_DIR/ustb
MATLAB_ROOT=$PWD/../
export MATLABPATH=$MATLAB_ROOT

if [ -z "$SONAIR_TOKEN" ]; then
    echo ""
    echo "**Warning SONAIR_TOKEN is not set - tests involving reading data from database will fail **"
    echo ""
fi

echo "Hello from the server!"

rm -rf $WORK_DIR
