# Test NVIDIA Clara COVID19 Model

Pre-processing and deployment of [NVIDIA NGC (NVIDIA GPU Cloud) Clara COVID19 model](https://ngc.nvidia.com/catalog/containers/nvidia:clara:ai-covid-19).

The inference pipeline was developed by NVIDIA. It is based on a segmentation and classification model developed by NVIDIA researchers in conjunction with the NIH.


## Installing NVIDIA Clara

* [Official Guide](https://docs.nvidia.com/clara/deploy/ClaraInstallation.html)
* [Clara SDK](https://ngc.nvidia.com/catalog/resources/nvidia:clara:clara_bootstrap)
* [Model Scripts > Clara CLI](https://ngc.nvidia.com/catalog/resources/nvidia:clara:clara_cli)

After making sure Clara SDK are correctly installed, download the [latest version of cli.zip](https://ngc.nvidia.com/catalog/resources/nvidia:clara:clara_cli/files). Unfortunately for users working on a remote server, there seems no way to download it directly from terminal (e.g., wget). Using `ssh -X` could work though, I've not yet tested it (I've downloaded the package locally and scp'd on the remote server).


## Useful Commands

To launch and explore the docker container, run:
`docker run -it --entrypoint /bin/bash nvcr.io/nvidia/clara/ai-covid-19:0.6.0-2005.1`


## Documentation/Model Notes

From the main NGC page (linked above): 

> This example is a containerized AI inference application, developed for use as one of the operators in the Clara Deploy pipelines. This application uses the original image from a lung CT scan and a segmented lung image, both in NIfTI or MetaImage format, to infer the presence of COVID-19. The application is built on the Clara Deploy Python base container, which provides the interfaces with Clara Deploy SDK. Inference is performed on the NVIDIA Triton Inference Server (Triton), formerly known as TensorRT Inference Server (TRTIS).

About the [NVIDIA Triton Inference Server](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/):

> NVIDIA Triton Inference Server (formerly TensorRT Inference Server) provides a cloud inferencing solution optimized for NVIDIA GPUs. The server provides an inference service via an HTTP or GRPC endpoint, allowing remote clients to request inferencing for any model being managed by the server. For edge deployments, Triton Server is also available as a shared library with an API that allows the full functionality of the server to be included directly in an application.

Regarding the AI model:

> The application uses the classification_covid-19_v1 model, which was developed by NIH and NVIDIA for use in COVID-19 detection pipeline, but is yet to be published on ngc.nvidia.com. The input tensor of this model is of size 192x192x64 with a single channel. The original image from the lung CT scan is cropped using the data in the lung segmentation image, so that only one simple inference is needed.


## Troubleshooting

Trying to install the Clara Deploy SDK I had to:
* Install docker-composite;
* (try to) Upgrade NVIDIA's driver: `sudo apt update && sudo apt upgrade`;
* First step broke nvidia-smi somehow, which is needed to carry out the installation of Clara Deploy SDK. That required a purge of old NVIDIA drivers and was ultimately solved by [re-installing NVIDIA CUDA 10.2 (from NVIDIA CUDA 10.0 page, which is for some reason broken - as it installs 10.2 anyways)](https://developer.nvidia.com/cuda-10.0-download-archive);
* Finally, run `docker pull nvcr.io/nvidia/clara/ai-covid-19:0.6.0-2005.1`.

Trying to test the model using the `run_docker.sh` at [this page](https://ngc.nvidia.com/catalog/containers/nvidia:clara:ai-covid-19):
* (very) Similar problem at [this page](https://forums.developer.nvidia.com/t/clara-deploy-sdk-stuck-at-wait-until-trtis-is-ready/124488/2);


## Installation Notes
* CUDA 10.2 will break TF 1.14/1.15 installed with pip (built over 10.0);
