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

# Ingress Resource
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

