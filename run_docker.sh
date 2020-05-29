#!/bin/bash

# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
TESTDATA_DIR=$(readlink -f "${SCRIPT_DIR}"/../test-data)

# Default app name. Change to acutally name, e.g. `nvcr.io/ea-nvidia-clara/clara/ai-lung:0.5.0-2004.5`
APP_NAME="nvcr.io/ea-nvidia-clara/clara/ai-lung:0.6.0-2005.1"
# Default model name, used by the default app. If blank, all available models will be loaded.
MODEL_NAME="classification_covid-19_v1"

INPUT_TYPE="mhd"

# Clara Deploy would launch the container when run in a pipeline with the following 
# environment variable to provide runtime information. This is for testing locally
export NVIDIA_CLARA_TRTISURI="localhost:8000"

# Specific version of the Triton Inference Server image used in testing
TRTIS_IMAGE="nvcr.io/nvidia/tensorrtserver:19.08-py3"

# Docker network used by the app and TRTIS Docker container.
NETWORK_NAME="container-demo"

# Create network
docker network create ${NETWORK_NAME}

# Run TRTIS(name: trtis), maping ./models/${MODEL_NAME} to /models/${MODEL_NAME}
# (localhost:8000 will be used)
RUN_TRITON="nvidia-docker run --name trtis --network ${NETWORK_NAME} -d --rm --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
    -p 8000:8000 \
    -v $(pwd)/models/${MODEL_NAME}:/models/${MODEL_NAME} ${TRTIS_IMAGE} \
    trtserver --model-store=/models"
# Run the command to start the inference server Docker
eval ${RUN_TRITON}
# Display the command
echo ${RUN_TRITON}

# Wait until TRTIS is ready
trtis_local_uri=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' trtis)
echo -n "Wait until TRTIS ${trtis_local_uri} is ready..."
while [ $(curl -s ${trtis_local_uri}:8000/api/status | grep -c SERVER_READY) -eq 0 ]; do
    sleep 1
    echo -n "."
done
echo "done"

export NVIDIA_CLARA_TRTISURI="${trtis_local_uri}:8000"

# Run ${APP_NAME} container.
# Launch the app container with the following environment variables internally
# to provide input/output path information.
docker run --name test_docker --network ${NETWORK_NAME} -it --rm \
    -v $(pwd)/input/${INPUT_TYPE}/:/input \
    -v $(pwd)/input/label_image/mhd/:/label_image \
    -v $(pwd)/output:/output \
    -v $(pwd)/logs:/logs \
    -e NVIDIA_CLARA_TRTISURI \
    -e DEBUG_VSCODE \
    -e DEBUG_VSCODE_PORT \
    -e NVIDIA_CLARA_NOSYNCLOCK=TRUE \
    ${APP_NAME}

echo "${APP_NAME} has finished."

# Stop TRTIS container
echo "Stopping Triton(TRTIS) inference server."
docker stop trtis > /dev/null

# Remove network
docker network remove ${NETWORK_NAME} > /dev/null
