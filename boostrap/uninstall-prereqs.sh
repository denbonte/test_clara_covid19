#!/bin/bash

# Copyright (c) 2019-2020, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# Clara Deploy SDK


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SILENT=false

set -euo pipefail

newline() {
    echo " "
}

info() {
    echo "$(date -u '+%Y-%m-%d %H:%M:%S') [INFO]:" $@
}

fatal() {
    >&2 echo "$(date -u '+%Y-%m-%d %H:%M:%S') [FATAL]:" $@
    newline
    exit 1
}

cleanup() {
    info "Cleaning up ..."
    set +e

    # remove existing Clara release
    if command -v clara > /dev/null; then
        clara platform stop -y
        clara render stop
        clara dicom stop
        clara monitor stop
    else
        info "Clara binaries are not available. Skipping the termination of Clara services."
    fi

    local kube_opt
    if [ $SILENT == true ]; then
        kube_opt="Y"
    else
        echo "****************************************************************************"
        echo "*** WARNING: This will remove all Kubernetes settings and configuration. ***"
        echo "****************************************************************************"
        read -p "Are you sure you want to uninstall Kubernetes?(Y/N) " kube_opt
    fi
    if [[ $kube_opt =~ ^(Y|y)$ ]]; then
        if command -v kubectl > /dev/null; then
            sudo kubectl patch pdb elasticsearch-master-pdb -p '{"spec":{"maxUnavailable": "100%"}}'
            nodes=$(sudo kubectl get nodes -o=custom-columns=NAME:.metadata.name)
            for node in "${nodes[@]:5}"
            do
                sudo kubectl drain $node --delete-local-data --force --ignore-daemonsets
                sudo kubectl delete node $node
            done
        else
            info "Skipping draining/deleting current node using kubectl ..."
        fi
        if command -v kubeadm > /dev/null; then
            sudo kubeadm reset -f
        else
            info "Skipping resetting kubeadm ..."
        fi
        sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni "kube*" >/dev/null 2>&1
        sudo rm -fr ~/.kube
        sudo rm -rf /var/lib/cni/
        sudo rm -rf /var/lib/etcd
        sudo rm -rf /var/lib/kubelet/*
        sudo rm -rf /etc/cni/
        sudo rm -rf /usr/local/bin/helm
        sudo rm -rf ~/.helm
        sudo ip link set cni0 down
        sudo ip link set flannel.1 down
        sudo ip link set docker0 down

        for proc in kube-controller kube-scheduler kube-apiserver kubelet kube-proxy; do
            sudo pkill -9 $proc || true
        done
    fi

    local docker_opt
    if [ $SILENT == true ]; then
        docker_opt="Y"
    else
        echo "**********************************************************************"
        echo "*** WARNING: This will remove all Docker images and configuration. ***"
        echo "**********************************************************************"
        read -p "Are you sure you want to uninstall docker?(Y/N) " docker_opt
    fi
    if [[ $docker_opt =~ ^(Y|y)$ ]]; then
        sudo apt-get purge -y nvidia-docker2 nvidia-container-runtime nvidia-container-toolkit libnvidia-container-tools libnvidia-container1 >/dev/null 2>&1
        sudo apt-get purge -y docker-ce >/dev/null 2>&1
        if ! sudo rm -fr /var/lib/docker; then
            local message="$(sudo rm -fr /var/lib/docker 2>&1)"
            local i
            if echo $message | grep -q ": Device or resource busy"; then
                info "Failed to remove /var/lib/docker. Retrying after unmounting docker-related volumes ..."
                # Remove the possibility where the error message was caused by unmounted docker-related volumes
                for i in $(findmnt | grep '/docker/' | sed -e 's#[├─└│ ]\+\/#/#' | cut -d' ' -f1); do
                    echo sudo umount $i
                    sudo umount $i
                done
                sudo rm -fr /var/lib/docker
            fi
        fi
        sudo rm -fr /etc/systemd/system/docker.service.d
    fi
    sudo apt-get -y autoremove

    local docker_compose_opt
    if [ $SILENT == true ]; then
        docker_compose_opt="Y"
    else
        echo "****************************************************************************************"
        echo "*** WARNING: This will remove Docker Compose binary (/usr/local/bin/docker-compose). ***"
        echo "****************************************************************************************"
        read -p "Are you sure you want to uninstall docker-compose?(Y/N) " docker_compose_opt
    fi
    if [[ $docker_compose_opt =~ ^(Y|y)$ ]]; then
        sudo rm -f /usr/local/bin/docker-compose
    fi

    sudo rm -fr /clara-io

    set -e
    info "Done cleaning up"
}

uninstall_clara_cli () {
    info "Uninstalling Clara CLI"
    rm -f /usr/bin/clara
    rm -f /usr/bin/clara-*
    rm -rf ~/.clara/
    info "Clara CLI uninstalled successfully"
}

check_sudo() {
    info "Checking user privilege..."
    if [ "$EUID" -ne 0 ]
        then echo "Please run as root"
        exit
    fi
    # Set SUDO_USER to 'root' in case the user was logged in as 'root'
    SUDO_USER=${SUDO_USER:-root}
}

parse_args() {
    local OPTIND c
    while getopts ':s' option;
    do
        case "${option}" in
            s)
                SILENT=true
                ;;
            *)
                print_usage
                ;;
        esac
    done
    shift $((OPTIND-1))
}

print_usage() {
    newline
    newline
    echo Remove all installed components.
    newline
    echo "Usage: $0 -s"
    echo "   -s     Silently remove everything that was installed."
    newline
    newline
}

main() {
    parse_args $@
    info "Clara Deploy SDK System Prerequisites Removal"
    check_sudo
    newline
    cleanup
    uninstall_clara_cli
    info "Clara Deploy SDK Prerequisites removed successfully!"
}

main "$@"
