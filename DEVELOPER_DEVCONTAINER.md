# Cloud Deployment Developer Guide

This guide describes how to develop and debug the Open AMT Cloud Toolkit components using the provided VS Code Dev Container environment.

## Architecture Overview

The development environment uses a **Hybrid** approach:
1.  **Code & Services**: Your application code (MPS, RPS, Router, WebUI) runs *inside* the Dev Container as standard processes. This gives you full IDE support (IntelliSense, Debuggers).
2.  **Infrastructure**: External dependencies (Postgres, Vault, Kong, etc.) run as *Docker containers* alongside the Dev Container, using the host's Docker daemon (Docker-outside-of-Docker).

```mermaid
flowchart TD
    %% Styles
    classDef host fill:#f5f5f5,stroke:#333,stroke-width:2px,color:#000;
    classDef docker fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#000;
    classDef devcontainer fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,stroke-dasharray: 5 5,color:#000;
    classDef infra fill:#fff3e0,stroke:#ef6c00,stroke-width:2px,color:#000;
    classDef service fill:#ffffff,stroke:#333,stroke-width:1px,color:#000;
    classDef database fill:#ffffff,stroke:#333,stroke-width:1px,shape:cylinder,color:#000;

    subgraph Host ["Host Machine (Windows/Linux/Mac)"]
        Browser["Web Browser (Chrome/Edge)"]:::service
        VSCode["VS Code"]:::service
        
        subgraph DockerEngine ["Docker Engine"]
            DockerDaemon[[Docker Daemon]]:::service
            
            subgraph DevContainer ["Dev Container (VS Code Remote)"]
                direction TB
                MPS["MPS Service (Node.js) <br/> :3000"]:::service
                RPS["RPS Service (Node.js) <br/> :8081"]:::service
                Router["MPS Router (Go) <br/> :8003"]:::service
                WebUI["Sample Web UI (Angular) <br/> :4200"]:::service
                
                Debugger["VS Code Debugger"]:::service
                Debugger -.-> MPS
                Debugger -.-> RPS
                Debugger -.-> Router
                Debugger -.-> WebUI
            end
            
            subgraph Infra ["Infrastructure (Docker Compose)"]
                DB[("Postgres DB <br/> :5432")]:::database
                Vault[("Vault <br/> :8200")]:::database
                Kong["Kong Gateway"]:::service
                Consul["Consul"]:::service
                Mosquitto["Mosquitto MQTT"]:::service
            end
            
            %% Connections
            DevContainer -- "Docker Socket" --> DockerDaemon
            MPS --> DB
            MPS --> Vault
            RPS --> DB
            RPS --> Vault
            WebUI -- "HTTP" --> MPS
            
            %% Networking
            DevContainer <== "Shared Network (openamtnetwork)" ==> Infra
        end
    end
    
    VSCode -- "Remote Connection" --> DevContainer
    Browser -- "Forwarded Port 4200" --> WebUI

    %% Apply Formatting
    class Host host
    class DockerEngine docker
    class DevContainer devcontainer
    class Infra infra
```

## Getting Started

### Prerequisites
*   Docker Desktop (or Docker Engine on Linux)
*   VS Code with **Dev Containers** extension installed.

### Initial Setup
1.  Open this folder in VS Code.
2.  When prompted, click **Reopen in Container**. (Or run command: `Dev Containers: Reopen in Container`).

## Running the Environment

### 1. Start Infrastructure
Before running the services, you need the database and other tools up.
*   Open the Command Palette (`Ctrl+Shift+P`).
*   Run **Tasks: Run Task** -> **Start Infrastructure**.
    *   *This spins up Postgres, Vault, Kong, etc.*

### 2. Connect Network
Ensure your Dev Container can talk to the infrastructure containers.
*   Run **Tasks: Run Task** -> **Connect DevContainer to Network**.

### 3. Start Web UI (Optional)
If you are working on the frontend:
*   Run **Tasks: Run Task** -> **Serve WebUI (Angular)**.
*   Wait for compilation to finish.

### 4. Debug Services
*   Go to the **Run and Debug** view (`Ctrl+Shift+D`).
*   Select **"Debug All Services"**.
*   Press **F5**.
    *   This will launch MPS, RPS, and the Router in debug mode.
    *   If Web UI task is running, it will also launch a Chrome window attached to the frontend.

## Configuration Files

*   **.devcontainer/devcontainer.json**: Defines the environment (tools, extensions, port forwarding).
*   **.vscode/launch.json**: Debugger configurations for Node.js (MPS/RPS), Go (Router), and Chrome (WebUI).
*   **.vscode/tasks.json**: Helper scripts to manage Docker containers and build processes.

## Troubleshooting

*   **Database connection failed**: Ensure you ran the "Start Infrastructure" task and the "Connect DevContainer to Network" task. The services look for a host named `db`.
*   **Web UI not accessible**: Make sure the ports are forwarded in the **Ports** view (Ctrl+J -> Ports). Port 4200 should be pointing to localhost:4200.
