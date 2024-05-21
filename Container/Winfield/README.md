# Development tools container

This project is for building development container pre-installed with tools and to avoid dependency management of these tools on a disconnected environment.

1. Change to the directory with the `dockerfile` in your command line.
1. Build the container image:
    ```
    docker build -f dockerfile -t <image name>:<image version> .
    ```
1. Follow the instructions in the `WINFIELD_SETUP_README.txt`, which can also be found at the root directory of the container.