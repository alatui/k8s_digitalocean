variable "do_token" {}


provider "digitalocean" {
  token = "${var.do_token}"
}


provider "kubernetes" {
  host = "${digitalocean_kubernetes_cluster.aylien-staging-cluster.endpoint}"

  client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.aylien-staging-cluster.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(digitalocean_kubernetes_cluster.aylien-staging-cluster.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.aylien-staging-cluster.kube_config.0.cluster_ca_certificate)}"
}

provider "helm" {
	service_account = "tiller"
	kubernetes {
		host = "${digitalocean_kubernetes_cluster.aylien-staging-cluster.endpoint}"

		client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.aylien-staging-cluster.kube_config.0.client_certificate)}"
  		client_key             = "${base64decode(digitalocean_kubernetes_cluster.aylien-staging-cluster.kube_config.0.client_key)}"
  		cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.aylien-staging-cluster.kube_config.0.cluster_ca_certificate)}"
	}
}


resource "digitalocean_kubernetes_cluster" "aylien-staging-cluster" {
  name    = "aylien-staging-cluster"
  region  = "nyc1"
  version = "1.14.2-do.0"
  tags    = ["staging"]

  node_pool {
    name       = "default-pool"
    size       = "s-2vcpu-2gb"
    node_count = 2
  }
}


resource "kubernetes_namespace" "paint-service" {
  metadata {
    name = "paint-service"
  }
}


resource "kubernetes_service_account" "tiller" {
  metadata {
  	name = "tiller"
  	namespace = "kube-system"
  }
}


resource "kubernetes_cluster_role_binding" "tiller" {
 	metadata {
 		name = "tiller"
	}
	role_ref {
		api_group = "rbac.authorization.k8s.io"
		kind = "ClusterRole"
		name = "cluster-admin"
	}
	subject {
		kind = "ServiceAccount"
		name = "tiller"
		namespace = "kube-system"
	}
}


data "helm_repository" "incubator" {
    name = "nginx-stable"
    url  = "https://helm.nginx.com/stable"
}


resource "helm_release" "nginx-ingress" {
    name      = "nginx-ingress"
    chart     = "nginx-stable/nginx-ingress"

    set {
        name  = "controller.replicaCount"
        value = 2
    }
}


variable "jenkins_adminUser" {}
variable "jenkins_adminPassword" {}
resource "helm_release" "jenkins4" {
    name      = "jenkins4"
    chart     = "stable/jenkins"

    set {
        name  = "master.adminUser"
        value = "${var.jenkins_adminUser}"
    }

    set {
        name = "master.adminPassword"
        value = "${var.jenkins_adminPassword}"
    }

    set {
        name = "master.ingress.enabled"
        value = "true"
    }

    set {
        name = "master.ingress.hostName"
        value = "jenkins.aylien.com"
    }

    set {
        name = "master.serviceType"
        value = "ClusterIP"
    }

    set {
        name = "master.servicePort"
        value = "80"
    }
}


resource "kubernetes_service_account" "jenkins" {
  metadata {
    name = "jenkins"
  }
}


resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name = "jenkins"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "jenkins"
  }
}

