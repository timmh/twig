#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd $(dirname $0); pwd)
BASE_DIR=$(cd $SCRIPT_DIR/..; pwd)

mkdir -p $BASE_DIR/cache
mkdir -p $BASE_DIR/weights

# download weights
curl -L https://www.kaggle.com/api/v1/models/google/bird-vocalization-classifier/tensorFlow2/perch_v2/2/download | tar -xz -C $BASE_DIR/weights

# convert weights to tflite
python $SCRIPT_DIR/convert_to_tflite.py

# enhance labels
python $SCRIPT_DIR/create_enhanced_labels.py