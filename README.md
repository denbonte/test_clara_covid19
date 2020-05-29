# Test NVIDIA Clara COVID19 Model

Pre-processing and deployment of [NVIDIA Clara COVID19 model](https://ngc.nvidia.com/catalog/containers/nvidia:clara:ai-covid-19).

The inference pipeline was developed by NVIDIA. It is based on a segmentation and classification model developed by NVIDIA researchers in conjunction with the NIH.


## Troubleshooting

Trying to install the Clara Deploy SDK I had to:
* Install docker-composite;
* (try to) Upgrade NVIDIA's driver: `sudo apt update && sudo apt upgrade`;
* First step broke nvidia-smi somehow, which is needed to carry out the installation of Clara Deploy SDK. That required a purge of old NVIDIA drivers and was ultimately solved by [re-installing NVIDIA CUDA 10.2 (from NVIDIA CUDA 10.0 page, which is for some reason broken - as it installs 10.2 anyways)](https://developer.nvidia.com/cuda-10.0-download-archive);
* Finally, run `docker pull nvcr.io/nvidia/clara/ai-covid-19:0.6.0-2005.1`.

## Installation Notes
* CUDA 10.2 will break TF 1.14/1.15 installed with pip (built over 10.0);
