FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# 1. Define the arguments to accept them from devcontainer.json
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG http_proxy
ARG https_proxy
ARG no_proxy

# 2. Export them as environment variables
ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTPS_PROXY
ENV NO_PROXY=$NO_PROXY
ENV http_proxy=$http_proxy
ENV https_proxy=$https_proxy
ENV no_proxy=$no_proxy

# 3. Ensure sudo keeps these variables (crucial for features that use sudo)
RUN echo 'Defaults env_keep += "HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy"' >> /etc/sudoers

# 4. Prime the apt cache with proxy settings active
RUN apt-get update
