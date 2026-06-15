# Device Management Toolkit (formerly known as Open AMT Cloud Toolkit)

> **Notice:** This is the **v2 (legacy)** maintenance branch. New deployments should use [`main`](../../tree/main) (Console). v2 receives security and critical-bug patches only.

[![Discord](https://img.shields.io/discord/1063200098680582154?style=for-the-badge&label=Discord&logo=discord&logoColor=white&labelColor=%235865F2&link=https%3A%2F%2Fdiscord.gg%2FDKHeUNEWVH)](https://discord.gg/DKHeUNEWVH)

> Disclaimer: Production viable releases are tagged and listed under 'Releases'. All other check-ins should be considered 'in-development' and should not be used in production

Device Management Toolkit (formerly known as Open Active Management Technology Cloud Toolkit (Open AMT Cloud Toolkit)) offers open-source microservices and libraries to streamline Intel AMT integration, simplifying out-of-band management solutions for Intel vPro Platforms.

**For detailed documentation** about the Open AMT Cloud Toolkit, see the [docs].

## Clone

**Important!** Make sure you clone this repo with the `--recursive` flag since it uses git submodules.

To clone live, in-development code (main branch):

```bash
git clone --recursive https://github.com/device-management-toolkit/cloud-deployment.git
```

Alternatively, for steps to clone and Get Started with one of the tagged releases, [see our documentation][docs].

## Get Started

There are multiple options to quickly deploy the Open AMT Cloud Toolkit:

### Option 1: Local using Docker

The quickest and easiest option is to set up a local stack using Docker, view our [Documentation Site][docs] and click the Get Started tab for How-To steps and examples.

### Option 2: Cloud using Azure

For more experienced users, deploy the stack on Azure using the 'Deploy to Azure' button below.

> Note: This requires MPS, RPS, and Sample Web UI images to be built and accessible in a Container Image Registry such as Azure Container Registry (ACR), Docker Hub, or other options.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdevice-management-toolkit%2Fcloud-deployment%2Fv2.33.1%2FazureDeploy.json)

Optionally, deploy from AzureCLI using the following commands:

```bash
az group create --name openamt --location eastus
az deployment group create --resource-group openamt --template-file azureDeploy.json
```


Additional deployments, such as Kubernetes via Azure (AKS) or AWS (EKS), can be found in our [Documentation Site][docs].

## Develop in a Dev Container

This repo ships with a ready-to-use [VS Code Dev Container](.devcontainer/devcontainer.json) so you can clone, open, and start debugging without manual setup.

1. Install [Docker](https://docs.docker.com/get-docker/) and the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension for VS Code.
2. Open this repo in VS Code and choose **Reopen in Container** when prompted.
3. On first launch the container creates `.env` (if missing), generates JWT/Vault secrets, and patches `kong.yaml`, `cypress.config.ts`, and `docker-compose.yml`; on reopen it reuses the existing `.env` values for those patches. Go/Node toolchains plus `air`, `dlv`, and `go-licenses` are installed inside the container.
4. Forwarded ports: `4200` (UI), `3000`, `8081`, `8003`.

Proxy variables (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`) are forwarded from the host automatically. See [DEVELOPER_DEVCONTAINER.md](DEVELOPER_DEVCONTAINER.md) for full details.

## Additional Resources

- For detailed documentation and Getting Started, [visit the docs site][docs].

- Find a bug? Or have ideas for new features? [Open a new Issue](./issues).

- Discover a vulnerability or do you have a security concern? [See our Security policy](SECURITY.md) for our reporting process.

- Need additional support or want to get the latest news and events about Open AMT? Connect with the team directly through Discord.

  [![Discord Banner 1](https://discordapp.com/api/guilds/1063200098680582154/widget.png?style=banner2)](https://discord.gg/DKHeUNEWVH)

[docs]: https://device-management-toolkit.github.io/docs
