# Project Documentation

## Following this guide you can execute the assignment successfully in your localhost.
## 1. Dockerization

### Steps:
1. Execute the command git clone of the repository:
```
    git clone https://github.com/andrevieiracloud/take-home-assignment-stack-io.git
    cd take-home-assignment-stack-io
    
```
1. Navigate to the `dockerize` directory:
    ```bash
    cd dockerize
    ```
2. Add the following `Dockerfile` code:
    ```dockerfile
    FROM golang:1.20

    WORKDIR /app

    COPY . .

    RUN go mod download

    RUN go build -o myapp webserver.go

    EXPOSE 8080

    CMD ["./myapp"]

    ```

## 2. Kubernetes Deployment

### Steps:
1. Navigate to the `kubernetes` directory:
    ```bash
    cd ../kubernetes
    ```
2. Start Minikube with Docker as the driver:
    ```bash
    minikube start --driver=docker --memory 16192 --cpus 8
    ```
3. Enable necessary Minikube addons:
    ```bash
    minikube addons enable ingress
    minikube addons enable registry
    ```
4. Create the namespace:
    ```bash
    apiVersion: v1
    kind: Namespace
    metadata:
    name: my-go-webserver
    ```
    > kubectl apply -f namespace.yaml
5. Build and push the Docker image:
    ```bash
    docker build -t localhost:5000/my-go-webserver:latest .
    docker push localhost:5000/my-go-webserver
    ```
6. Apply the application configuration:
    ```bash
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
    name: my-go-webserver
    namespace: my-go-webserver
    labels:
        app: my-go-webserver
        tier: backend
    spec:
    selector:
        matchLabels:
        app: my-go-webserver
        tier: backend
    replicas: 1
    template:
        metadata:
        annotations: {}
        labels:
            app: my-go-webserver
            tier: backend
        spec:
        initContainers:
        - name: init-sleep
            image: busybox
            command: ["sleep", "30"]
            resources:
            requests:
                memory: "10Mi"
                cpu: "10m"
            limits:
                memory: "50Mi"
                cpu: "50m"

        containers:
        - name: my-go-webserver
            image: localhost:5000/my-go-webserver:latest
            imagePullPolicy: Always
            resources:
            requests:
                memory: "50Mi"
                cpu: "50m"
            limits:
                memory: "200Mi"
                cpu: "200m"
            livenessProbe:
            httpGet:
                path: /
                port: 8080
            initialDelaySeconds: 210
            periodSeconds: 5
            timeoutSeconds: 2
            readinessProbe:
            httpGet:
                path: /
                port: 8080
            initialDelaySeconds: 80
            periodSeconds: 3
            ports:
            - name: http
            containerPort: 8080
            lifecycle:
            preStop:
                exec:
                command: ["sleep", "30"]
    ---
    apiVersion: v1
    kind: Service
    metadata:
    name: my-go-webserver
    namespace: my-go-webserver
    labels:
        app: my-go-webserver
    spec:
    type: ClusterIP
    ports:
    - name: http
        port: 8080
        targetPort: 8080
    selector:
        tier: backend
        app: my-go-webserver
    ---
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
    name: my-go-webserver
    namespace: my-go-webserver
    annotations:
        nginx.ingress.kubernetes.io/use-regex: "true"
    spec:
    ingressClassName: nginx
    rules:
    - host: app-stack.io
        http:
        paths:
        - path: /
            pathType: Prefix
            backend:
            service:
                name: my-go-webserver
                port:
                number: 8080
        
    ```
    > kubectl apply -f app.yaml
7. Check the status of the pods:
    ```bash
    kubectl -n my-go-webserver get pods
    ```
8. Describe the specific pod:
    ```bash
    kubectl -n my-go-webserver describe pod "podname"
    ```
9. View the logs of the pod:
    ```bash
    kubectl -n my-go-webserver logs -f "podname"
    ```
10. View all Kubernetes objects:
    ```bash
    kubectl -n my-go-webserver get all
    ```
11. Describe the service:
    ```bash
    kubectl -n my-go-webserver describe service my-go-webserver
    ```

## 3. Terraform Infrastructure

### Steps:
1. Navigate to the `terraform` directory:
    ```bash
    cd ../terraform
    ```
2. Add the following `main.tf` code:
    ```hcl
    terraform {
      required_providers {
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "2.7.0"
        }
      }
    }
    
    # Kubernetes Provider Configuration
    provider "kubernetes" {
      config_path = "~/.kube/config"
    }
    
    # Namespace Resource (created first)
    resource "kubernetes_namespace" "my_go_webserver_namespace" {
      metadata {
        name = "my-go-webserver"
      }
    }
    
    # Deployment Resource
    resource "kubernetes_deployment" "my_go_webserver" {
      depends_on = [kubernetes_namespace.my_go_webserver_namespace]  # Ensures namespace is created first
    
      metadata {
        name      = "my-go-webserver"
        namespace = kubernetes_namespace.my_go_webserver_namespace.metadata[0].name
        labels = {
          app  = "my-go-webserver"
          tier = "backend"
        }
      }
    
      spec {
        replicas = 1
    
        selector {
          match_labels = {
            app  = "my-go-webserver"
            tier = "backend"
          }
        }
    
        template {
          metadata {
            labels = {
              app  = "my-go-webserver"
              tier = "backend"
            }
          }
    
          spec {
            # Init Container
            init_container {
              name  = "init-sleep"
              image = "busybox"
    
              command = ["sleep", "30"]
    
              resources {
                limits = {
                  memory = "50Mi"
                  cpu    = "50m"
                }
                requests = {
                  memory = "10Mi"
                  cpu    = "10m"
                }
              }
            }
    
            # Main Container
            container {
              name  = "my-go-webserver"
              image = "localhost:5000/my-go-webserver:latest"
              image_pull_policy = "Always"
    
              resources {
                limits = {
                  memory = "200Mi"
                  cpu    = "200m"
                }
                requests = {
                  memory = "100Mi"
                  cpu    = "100m"
                }
              }
    
              port {
                container_port = 8080
              }
    
              liveness_probe {
                http_get {
                  path = "/"
                  port = 8080
                }
                initial_delay_seconds = 210
                period_seconds         = 5
                timeout_seconds        = 2
              }
    
              readiness_probe {
                http_get {
                  path = "/"
                  port = 8080
                }
                initial_delay_seconds = 80
                period_seconds         = 3
              }
    
              lifecycle {
                pre_stop {
                  exec {
                    command = ["sleep", "60"]
                  }
                }
              }
            }
          }
        }
      }
    }
    
    # Service Resource
    resource "kubernetes_service" "my_go_webserver" {
      depends_on = [kubernetes_namespace.my_go_webserver_namespace]  # Ensures namespace is created first
    
      metadata {
        name      = "my-go-webserver"
        namespace = kubernetes_namespace.my_go_webserver_namespace.metadata[0].name
        labels = {
          app = "my-go-webserver"
        }
      }
    
      spec {
        selector = {
          app  = "my-go-webserver"
          tier = "backend"
        }
    
        port {
          name       = "http"
          port       = 8080
          target_port = 8080
        }
    
        type = "ClusterIP"
      }
    }
    
    resource "kubernetes_ingress_v1" "my_go_webserver" {
      depends_on = [kubernetes_namespace.my_go_webserver_namespace]
    
      metadata {
        name      = "my-go-webserver"
        namespace = kubernetes_namespace.my_go_webserver_namespace.metadata[0].name
        annotations = {
          "nginx.ingress.kubernetes.io/use-regex" = "true"
        }
      }
    
      spec {
        rule {
          host = "app-stack.io"
          
          http {
            path {
              path     = "/"
              path_type = "Prefix"
    
              backend {
                service {
                  name = kubernetes_service.my_go_webserver.metadata[0].name
                  port {
                    number = 8080
                  }
                }
              }
            }
          }
        }
      }
    }
    ```
3. Initialize Terraform:
    ```bash
    terraform init
    ```
4. Validate the configuration:
    ```bash
    terraform validate
    ```
5. Generate and review an execution plan:
    ```bash
    terraform plan
    ```
6. Apply the changes:
    ```bash
    terraform apply
    ```
7. Terraform tfstate
   
    ```bash
        {
      "version": 4,
      "terraform_version": "1.9.6",
      "serial": 5,
      "lineage": "ad675eab-af23-0b86-30b9-a14b39fa9d06",
      "outputs": {},
      "resources": [
        {
          "mode": "managed",
          "type": "kubernetes_deployment",
          "name": "my_go_webserver",
          "provider": "provider[\"registry.terraform.io/hashicorp/kubernetes\"]",
          "instances": [
            {
              "schema_version": 1,
              "attributes": {
                "id": "my-go-webserver/my-go-webserver",
                "metadata": [
                  {
                    "annotations": null,
                    "generate_name": "",
                    "generation": 1,
                    "labels": {
                      "app": "my-go-webserver",
                      "tier": "backend"
                    },
                    "name": "my-go-webserver",
                    "namespace": "my-go-webserver",
                    "resource_version": "354681",
                    "uid": "5fb63709-820c-4716-b3e1-bc313a021ead"
                  }
                ],
                "spec": [
                  {
                    "min_ready_seconds": 0,
                    "paused": false,
                    "progress_deadline_seconds": 600,
                    "replicas": "1",
                    "revision_history_limit": 10,
                    "selector": [
                      {
                        "match_expressions": [],
                        "match_labels": {
                          "app": "my-go-webserver",
                          "tier": "backend"
                        }
                      }
                    ],
                    "strategy": [
                      {
                        "rolling_update": [
                          {
                            "max_surge": "25%",
                            "max_unavailable": "25%"
                          }
                        ],
                        "type": "RollingUpdate"
                      }
                    ],
                    "template": [
                      {
                        "metadata": [
                          {
                            "annotations": null,
                            "generate_name": "",
                            "generation": 0,
                            "labels": {
                              "app": "my-go-webserver",
                              "tier": "backend"
                            },
                            "name": "",
                            "namespace": "",
                            "resource_version": "",
                            "uid": ""
                          }
                        ],
                        "spec": [
                          {
                            "active_deadline_seconds": 0,
                            "affinity": [],
                            "automount_service_account_token": true,
                            "container": [
                              {
                                "args": null,
                                "command": null,
                                "env": [],
                                "env_from": [],
                                "image": "localhost:5000/my-go-webserver:latest",
                                "image_pull_policy": "Always",
                                "lifecycle": [
                                  {
                                    "post_start": [],
                                    "pre_stop": [
                                      {
                                        "exec": [
                                          {
                                            "command": [
                                              "sleep",
                                              "60"
                                            ]
                                          }
                                        ],
                                        "http_get": [],
                                        "tcp_socket": []
                                      }
                                    ]
                                  }
                                ],
                                "liveness_probe": [
                                  {
                                    "exec": [],
                                    "failure_threshold": 3,
                                    "http_get": [
                                      {
                                        "host": "",
                                        "http_header": [],
                                        "path": "/",
                                        "port": "8080",
                                        "scheme": "HTTP"
                                      }
                                    ],
                                    "initial_delay_seconds": 210,
                                    "period_seconds": 5,
                                    "success_threshold": 1,
                                    "tcp_socket": [],
                                    "timeout_seconds": 2
                                  }
                                ],
                                "name": "my-go-webserver",
                                "port": [
                                  {
                                    "container_port": 8080,
                                    "host_ip": "",
                                    "host_port": 0,
                                    "name": "",
                                    "protocol": "TCP"
                                  }
                                ],
                                "readiness_probe": [
                                  {
                                    "exec": [],
                                    "failure_threshold": 3,
                                    "http_get": [
                                      {
                                        "host": "",
                                        "http_header": [],
                                        "path": "/",
                                        "port": "8080",
                                        "scheme": "HTTP"
                                      }
                                    ],
                                    "initial_delay_seconds": 80,
                                    "period_seconds": 3,
                                    "success_threshold": 1,
                                    "tcp_socket": [],
                                    "timeout_seconds": 1
                                  }
                                ],
                                "resources": [
                                  {
                                    "limits": {
                                      "cpu": "200m",
                                      "memory": "200Mi"
                                    },
                                    "requests": {
                                      "cpu": "100m",
                                      "memory": "100Mi"
                                    }
                                  }
                                ],
                                "security_context": [],
                                "startup_probe": [],
                                "stdin": false,
                                "stdin_once": false,
                                "termination_message_path": "/dev/termination-log",
                                "termination_message_policy": "File",
                                "tty": false,
                                "volume_mount": [],
                                "working_dir": ""
                              }
                            ],
                            "dns_config": [],
                            "dns_policy": "ClusterFirst",
                            "enable_service_links": true,
                            "host_aliases": [],
                            "host_ipc": false,
                            "host_network": false,
                            "host_pid": false,
                            "hostname": "",
                            "image_pull_secrets": [],
                            "init_container": [
                              {
                                "args": null,
                                "command": [
                                  "sleep",
                                  "30"
                                ],
                                "env": [],
                                "env_from": [],
                                "image": "busybox",
                                "image_pull_policy": "Always",
                                "lifecycle": [],
                                "liveness_probe": [],
                                "name": "init-sleep",
                                "port": [],
                                "readiness_probe": [],
                                "resources": [
                                  {
                                    "limits": {
                                      "cpu": "50m",
                                      "memory": "50Mi"
                                    },
                                    "requests": {
                                      "cpu": "10m",
                                      "memory": "10Mi"
                                    }
                                  }
                                ],
                                "security_context": [],
                                "startup_probe": [],
                                "stdin": false,
                                "stdin_once": false,
                                "termination_message_path": "/dev/termination-log",
                                "termination_message_policy": "File",
                                "tty": false,
                                "volume_mount": [],
                                "working_dir": ""
                              }
                            ],
                            "node_name": "",
                            "node_selector": null,
                            "priority_class_name": "",
                            "readiness_gate": [],
                            "restart_policy": "Always",
                            "security_context": [],
                            "service_account_name": "",
                            "share_process_namespace": false,
                            "subdomain": "",
                            "termination_grace_period_seconds": 30,
                            "toleration": [],
                            "topology_spread_constraint": [],
                            "volume": []
                          }
                        ]
                      }
                    ]
                  }
                ],
                "timeouts": null,
                "wait_for_rollout": true
              },
              "sensitive_attributes": [],
              "private":    "eyJlMmJmYjczMC1lY2FhLTExZTYtOGY4OC0zNDM2M2JjN2M0YzAiOnsiY3JlYXRlIjo2MDAwMDAwMDAwMDAsImRlbGV0  ZSI6NjAwMDAwMDAwMDAwLCJ1cGRhdGUiOjYwMDAwMDAwMDAwMH0sInNjaGVtYV92ZXJzaW9uIjoiMSJ9",
              "dependencies": [
                "kubernetes_namespace.my_go_webserver_namespace"
              ]
            }
          ]
        },
        {
          "mode": "managed",
          "type": "kubernetes_ingress_v1",
          "name": "my_go_webserver",
          "provider": "provider[\"registry.terraform.io/hashicorp/kubernetes\"]",
          "instances": [
            {
              "schema_version": 0,
              "attributes": {
                "id": "my-go-webserver/my-go-webserver",
                "metadata": [
                  {
                    "annotations": {
                      "nginx.ingress.kubernetes.io/use-regex": "true"
                    },
                    "generate_name": "",
                    "generation": 1,
                    "labels": null,
                    "name": "my-go-webserver",
                    "namespace": "my-go-webserver",
                    "resource_version": "354496",
                    "uid": "2a844bef-6023-49af-9614-baef37fbdb4d"
                  }
                ],
                "spec": [
                  {
                    "default_backend": [],
                    "ingress_class_name": "nginx",
                    "rule": [
                      {
                        "host": "app-stack.io",
                        "http": [
                          {
                            "path": [
                              {
                                "backend": [
                                  {
                                    "resource": [],
                                    "service": [
                                      {
                                        "name": "my-go-webserver",
                                        "port": [
                                          {
                                            "name": 0,
                                            "number": 8080
                                          }
                                        ]
                                      }
                                    ]
                                  }
                                ],
                                "path": "/",
                                "path_type": "Prefix"
                              }
                            ]
                          }
                        ]
                      }
                    ],
                    "tls": []
                  }
                ],
                "status": [
                  {
                    "load_balancer": [
                      {
                        "ingress": []
                      }
                    ]
                  }
                ],
                "wait_for_load_balancer": null
              },
              "sensitive_attributes": [],
              "private": "bnVsbA==",
              "dependencies": [
                "kubernetes_namespace.my_go_webserver_namespace",
                "kubernetes_service.my_go_webserver"
              ]
            }
          ]
        },
        {
          "mode": "managed",
          "type": "kubernetes_namespace",
          "name": "my_go_webserver_namespace",
          "provider": "provider[\"registry.terraform.io/hashicorp/kubernetes\"]",
          "instances": [
            {
              "schema_version": 0,
              "attributes": {
                "id": "my-go-webserver",
                "metadata": [
                  {
                    "annotations": null,
                    "generate_name": "",
                    "generation": 0,
                    "labels": null,
                    "name": "my-go-webserver",
                    "resource_version": "354476",
                    "uid": "f8703cc2-7f2a-4803-9047-94eb563734a7"
                  }
                ],
                "timeouts": null
              },
              "sensitive_attributes": [],
              "private":    "eyJlMmJmYjczMC1lY2FhLTExZTYtOGY4OC0zNDM2M2JjN2M0YzAiOnsiZGVsZXRlIjozMDAwMDAwMDAwMDB9fQ=="
            }
          ]
        },
        {
          "mode": "managed",
          "type": "kubernetes_service",
          "name": "my_go_webserver",
          "provider": "provider[\"registry.terraform.io/hashicorp/kubernetes\"]",
          "instances": [
            {
              "schema_version": 1,
              "attributes": {
                "id": "my-go-webserver/my-go-webserver",
                "metadata": [
                  {
                    "annotations": null,
                    "generate_name": "",
                    "generation": 0,
                    "labels": {
                      "app": "my-go-webserver"
                    },
                    "name": "my-go-webserver",
                    "namespace": "my-go-webserver",
                    "resource_version": "354480",
                    "uid": "b183838c-fe78-4a6c-8c26-d31b55433acb"
                  }
                ],
                "spec": [
                  {
                    "cluster_ip": "10.109.43.224",
                    "external_ips": null,
                    "external_name": "",
                    "external_traffic_policy": "",
                    "health_check_node_port": 0,
                    "load_balancer_ip": "",
                    "load_balancer_source_ranges": null,
                    "port": [
                      {
                        "name": "http",
                        "node_port": 0,
                        "port": 8080,
                        "protocol": "TCP",
                        "target_port": "8080"
                      }
                    ],
                    "publish_not_ready_addresses": false,
                    "selector": {
                      "app": "my-go-webserver",
                      "tier": "backend"
                    },
                    "session_affinity": "None",
                    "type": "ClusterIP"
                  }
                ],
                "status": [
                  {
                    "load_balancer": [
                      {
                        "ingress": []
                      }
                    ]
                  }
                ],
                "timeouts": null,
                "wait_for_load_balancer": true
              },
              "sensitive_attributes": [],
              "private":    "eyJlMmJmYjczMC1lY2FhLTExZTYtOGY4OC0zNDM2M2JjN2M0YzAiOnsiY3JlYXRlIjo2MDAwMDAwMDAwMDB9LCJzY2hl  bWFfdmVyc2lvbiI6IjEifQ==",
              "dependencies": [
                "kubernetes_namespace.my_go_webserver_namespace"
              ]
            }
          ]
        }
      ],
      "check_results": null
    }

    ```

## 4. Linux Automation Script

### Steps:
1. Navigate to the `linux` directory:
    ```bash
    cd ../linux
    ```
2. Add the following `automation.sh` script:
    ```bash
    #!/bin/bash

    # Variables for control
    DOCKERFILE_PATH="../dockerize/Dockerfile"
    IMAGE_NAME="my-go-webserver"
    TAG=$(date +"%Y%m%d%H%M%S") # Defining Current TAG
    NEW_IMAGE="${IMAGE_NAME}:${TAG}"
    SCRIPT_YAML="./script.yaml"
    NEW_APP_YAML="./new-app.yaml"

    echo "Building Docker image..."
    cd ../dockerize
    docker build -t $NEW_IMAGE -f $DOCKERFILE_PATH .
    cd ../linux

    echo "Creating new-app.yaml..."
    sed "s|MY_NEW_IMAGE|$NEW_IMAGE|g" $SCRIPT_YAML > $NEW_APP_YAML

    echo "Diff for Comparing current state in minikube with new-app.yaml..."
    kubectl diff -f $NEW_APP_YAML

    ```
3. Make the script executable:
    ```bash
    chmod +x automation.sh
    ```
4. Run the automation script:
    ```bash
    ./automation.sh
    ```

5. Add the following YAML configurations:
    - `script.yaml`:
        ```yaml
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: my-go-webserver
          namespace: my-go-webserver
          labels:
            app: my-go-webserver
            tier: backend
        spec:
          selector:
            matchLabels:
              app: my-go-webserver
              tier: backend
          replicas: 1
          template:
            metadata:
              annotations: {}
              labels:
                app: my-go-webserver
                tier: backend
            spec:
              initContainers:
              - name: init-sleep
                image: busybox
                command: ["sleep", "30"]
                resources:
                  requests:
                    memory: "10Mi"
                    cpu: "10m"
                  limits:
                    memory: "50Mi"
                    cpu: "50m"

              containers:
              - name: my-go-webserver
                image: MY_NEW_IMAGE
                imagePullPolicy: Always
                resources:
                  requests:
                    memory: "100Mi"
                    cpu: "100m"
                  limits:
                    memory: "200Mi"
                    cpu: "200m"
                livenessProbe:
                  httpGet:
                    path: /
                    port: 8080
                  initialDelaySeconds: 210
                  periodSeconds: 5
                  timeoutSeconds: 2
                readinessProbe:
                  httpGet:
                    path: /
                    port: 8080
                  initialDelaySeconds: 80
                  periodSeconds: 3
                ports:
                - name: http
                  containerPort: 8080
                lifecycle:
                  preStop:
                    exec:
                      command: ["sleep", "30"]
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: my-go-webserver
          namespace: my-go-webserver
          labels:
            app: my-go-webserver
        spec:
          type: ClusterIP
          ports:
          - name: http
            port: 8080
            targetPort: 8080
          selector:
            tier: backend
            app: my-go-webserver
        ---
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: my-go-webserver
          namespace: my-go-webserver
          annotations:
            nginx.ingress.kubernetes.io/use-regex: "true"
        spec:
          ingressClassName: nginx
          rules:
          - host: app-stack.io
            http:
              paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: my-go-webserver
                    port:
                      number: 8080
        ---
        ```
    - `new-app.yaml`:
        ```yaml
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: my-go-webserver
          namespace: my-go-webserver
          labels:
            app: my-go-webserver
            tier: backend
        spec:
          selector:
            matchLabels:
              app: my-go-webserver
              tier: backend
          replicas: 1
          template:
            metadata:
              annotations: {}
              labels:
                app: my-go-webserver
                tier: backend
            spec:
              initContainers:
              - name: init-sleep
                image: busybox
                command: ["sleep", "30"]
                resources:
                  requests:
                    memory: "10Mi"
                    cpu: "10m"
                  limits:
                    memory: "50Mi"
                    cpu: "50m"

              containers:
              - name: my-go-webserver
                image: my-go-webserver:20240927150355
                imagePullPolicy: Always
                resources:
                  requests:
                    memory: "100Mi"
                    cpu: "100m"
                  limits:
                    memory: "200Mi"
                    cpu: "200m"
                livenessProbe:
                  httpGet:
                    path: /
                    port: 8080
                  initialDelaySeconds: 210
                  periodSeconds: 5
                  timeoutSeconds: 2
                readinessProbe:
                  httpGet:
                    path: /
                    port: 8080
                  initialDelaySeconds: 80
                  periodSeconds: 3
                ports:
                - name: http
                  containerPort: 8080
                lifecycle:
                  preStop:
                    exec:
                      command: ["sleep", "60"]
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: my-go-webserver
          namespace: my-go-webserver
          labels:
            app: my-go-webserver
        spec:
          type: ClusterIP
          ports:
          - name: http
            port: 8080
            targetPort: 8080
          selector:
            tier: backend
            app: my-go-webserver
        ---
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: my-go-webserver
          namespace: my-go-webserver
          annotations:
            nginx.ingress.kubernetes.io/use-regex: "true"
        spec:
          ingressClassName: nginx
          rules:
          - host: app-stack.io
            http:
              paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: my-go-webserver
                    port:
                      number: 8080
        ---
        ```
    - `diff.yaml`:
        > kubectl diff -f new-app.yaml
        ```yaml
        diff -u -N /tmp/LIVE-2387838853/apps.v1.Deployment.my-go-webserver.my-go-webserver /tmp/        MERGED-547696860/apps.v1.Deployment.my-go-webserver.my-go-webserver
        --- /tmp/LIVE-2387838853/apps.v1.Deployment.my-go-webserver.my-go-webserver     2024-09-27 18:59:20.        653660130 -0300
        +++ /tmp/MERGED-547696860/apps.v1.Deployment.my-go-webserver.my-go-webserver    2024-09-27 18:59:20.        655660152 -0300
        @@ -4,7 +4,7 @@
           annotations:
             deployment.kubernetes.io/revision: "1"
           creationTimestamp: "2024-09-27T21:56:45Z"
        -  generation: 1
        +  generation: 2
           labels:
             app: my-go-webserver
             tier: backend
        @@ -34,14 +34,14 @@
             spec:
               automountServiceAccountToken: true
               containers:
        -      - image: localhost:5000/my-go-webserver:latest
        +      - image: my-go-webserver:20240927185918
                 imagePullPolicy: Always
                 lifecycle:
                   preStop:
                     exec:
                       command:
                       - sleep
        -              - "60"
        +              - "30"
                 livenessProbe:
                   failureThreshold: 3
                   httpGet:
        @@ -55,6 +55,7 @@
                 name: my-go-webserver
                 ports:
                 - containerPort: 8080
        +          name: http
                   protocol: TCP
                 readinessProbe:
                   failureThreshold: 3
                ```
