# Set provider and use correct subscription =======================================================================================================
provider "azurerm" {
  features {}
  subscription_id = "642dd095-927a-4bdf-9152-d4f6609d0207"
}


provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
}

# Networking and groups ==========================================================================================================================
# Joine resource group agents
data "azurerm_resource_group" "main" {
  name = "Dataplatform-Group-Monitoring"
}


# Define Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-mon-innovationlab"
  location = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

#Define security group ===============================================================================================================================
resource "azurerm_network_security_group" "AKSsg" {
  name                = "SecurityGroupGeneral"
  location = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}
#Define security rules
resource "azurerm_network_security_rule" "AgentToFleet" {
      name                        = "AgentToFleet"
      priority                    = 100
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "8220"
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      resource_group_name         = data.azurerm_resource_group.main.name
      network_security_group_name = azurerm_network_security_group.AKSsg.name
}
resource "azurerm_network_security_rule" "AgentToElastic" {
      name                        = "AgentToElastic"
      priority                    = 101
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "9200"
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      resource_group_name         = data.azurerm_resource_group.main.name
      network_security_group_name = azurerm_network_security_group.AKSsg.name
}
resource "azurerm_network_security_rule" "AgentToLogtash" {
      name                        = "AgentToLogtash"
      priority                    = 102
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "5044"
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      resource_group_name         = data.azurerm_resource_group.main.name
      network_security_group_name = azurerm_network_security_group.AKSsg.name
}
resource "azurerm_network_security_rule" "AgentToKibanaWhenFleet" {
      name                        = "AgentToKibanaWhenFleet"
      priority                    = 103
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "5601"
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      resource_group_name         = data.azurerm_resource_group.main.name
      network_security_group_name = azurerm_network_security_group.AKSsg.name
}
resource "azurerm_network_security_rule" "FleetToElastic" {
      name                        = "FleetToElastic"
      priority                    = 104
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "9200"
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      resource_group_name         = data.azurerm_resource_group.main.name
      network_security_group_name = azurerm_network_security_group.AKSsg.name
}
resource "azurerm_network_security_rule" "ssh_sr" {
      name                        = "ssh"
      priority                    = 105
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "22"
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      resource_group_name         = data.azurerm_resource_group.main.name
      network_security_group_name = azurerm_network_security_group.AKSsg.name
}

# Define Subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Define Subnet for Agents
resource "azurerm_subnet" "agent_subnet" {
  name                 = "agent-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
#Associate subnet with Security Group
resource "azurerm_subnet_network_security_group_association" "aks_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.AKSsg.id
}
#Associate subnet with Security Group
resource "azurerm_subnet_network_security_group_association" "agents_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.agent_subnet.id
  network_security_group_id = azurerm_network_security_group.AKSsg.id
}

# Create a public IP address fleetVM
resource "azurerm_public_ip" "fleet_public_ip" {
  name = "FleetPubIP"
  resource_group_name = data.azurerm_resource_group.main.name
  location = "West Europe"
  allocation_method = "Static"
}

# Create a public IP address agentVM
resource "azurerm_public_ip" "agent_public_ip" {
  name = "AgentPubIP"
  resource_group_name = data.azurerm_resource_group.main.name
  location = "West Europe"
  allocation_method = "Static"
}

# Create AKS Cluster in Azure =====================================================================================================================
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "aks-cluster"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "k8s"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
    vnet_subnet_id  = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

   network_profile {
    network_plugin    = "azure"
    dns_service_ip    = "10.1.0.10"  # Non-overlapping range
    service_cidr      = "10.1.0.0/16"  # Non-overlapping range
    load_balancer_sku = "standard"
  }
}

# Setup SSH =======================================================================================================================================
resource "local_file" "create_ssh_folder" {
  filename = "./ssh/.placeholder"
  content  = ""
}

# Generate SSH Key for Fleet VM
resource "tls_private_key" "fleet_vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "fleet_vm_private_key" {
  depends_on = [local_file.create_ssh_folder]
  filename   = "./ssh/fleet_vm_id_rsa"
  content    = tls_private_key.fleet_vm_key.private_key_pem
  file_permission = "0600"
}

resource "local_file" "fleet_vm_public_key" {
  depends_on = [local_file.create_ssh_folder]
  filename   = "./ssh/fleet_vm_id_rsa.pub"
  content    = tls_private_key.fleet_vm_key.public_key_openssh
}

# Generate SSH Key for Agent VM
resource "tls_private_key" "agent_vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "agent_vm_private_key" {
  depends_on = [local_file.create_ssh_folder]
  filename   = "./ssh/agent_vm_id_rsa"
  content    = tls_private_key.agent_vm_key.private_key_pem
  file_permission = "0600"
}

resource "local_file" "agent_vm_public_key" {
  depends_on = [local_file.create_ssh_folder]
  filename   = "./ssh/agent_vm_id_rsa.pub"
  content    = tls_private_key.agent_vm_key.public_key_openssh
}

# Setup Agent & Fleet VM + network interfaces =======================================================================================================
# Network Interface for the AKS VM
resource "azurerm_network_interface" "fleet_vm_nic" {
  name                = "fleet-vm-nic"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fleet_public_ip.id
  }
}

# AKS VM
resource "azurerm_linux_virtual_machine" "fleet_vm" {
  name                = "fleet-vm"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.fleet_vm_key.public_key_openssh
  }
  network_interface_ids = [azurerm_network_interface.fleet_vm_nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }
}

# Network Interface for the Agent VM
resource "azurerm_network_interface" "agent_vm_nic" {
  name                = "agent-vm-nic"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.agent_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent_public_ip.id
  }
}

# Agent VM
resource "azurerm_linux_virtual_machine" "agent_vm" {
  name                = "agent-vm"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.agent_vm_key.public_key_openssh
  }
  network_interface_ids = [azurerm_network_interface.agent_vm_nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }
}

# Deploy Elasticsearch, Kibana and Logstash on the Kubernetes cluster =======================================================================================================
# Create ConfigMap for Elasticsearch configuration
// resource "kubernetes_config_map" "elasticsearch_config" {
//   metadata {
//     name      = "elasticsearch-config"
//     namespace = "default"
//   }
//   data = {
//     "elasticsearch.yml" = <<-EOT
//       cluster.name: "elk-cluster"
//       network.host: 0.0.0.0
//       discovery.type: single-node
//       xpack.security.enabled: true
//       xpack.security.enrollment.enabled: true
//       xpack.security.http.ssl.enabled: false
//       xpack.security.transport.ssl.enabled: false
//       xpack.security.audit.enabled: true
//       xpack.monitoring.templates.enabled: true
//       xpack.monitoring.collection.enabled: true
//       path.data: /usr/share/elasticsearch/data
//       path.logs: /usr/share/elasticsearch/logs
//     EOT
//   }
// }

resource "kubernetes_deployment" "elasticsearch" {
  metadata {
    name = "elasticsearch"
    namespace = "default"
    labels = {
      app = "elasticsearch"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "elasticsearch"
      }
    }

    template {
      metadata {
        labels = {
          app = "elasticsearch"
        }
      }

      spec {
        container {
          name  = "elasticsearch"
          image = "docker.elastic.co/elasticsearch/elasticsearch:8.16.1"

          port {
            container_port = 9200
          }

          env {
            name  = "discovery.type"
            value = "single-node"
          }

          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms1g -Xmx1g"
          }

          volume_mount {
            name       = "elasticsearch-config"
            mount_path = "/usr/share/elasticsearch/config/elasticsearch.yml"
            sub_path   = "elasticsearch.yml"
          }

          volume_mount {
            name       = "elasticsearch-data"
            mount_path = "/usr/share/elasticsearch/data"
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }
        }

        volume {
          name = "elasticsearch-config"
        }

        volume {
          name = "elasticsearch-data"
          empty_dir {}
        }
      }
    }
  }
}


resource "kubernetes_deployment" "kibana" {
  metadata {
    name      = "kibana"
    namespace = "default"
    labels = {
      app = "kibana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kibana"
      }
    }

    template {
      metadata {
        labels = {
          app = "kibana"
        }
      }

      spec {
        container {
          name  = "kibana"
          image = "docker.elastic.co/kibana/kibana:8.16.1"

          port {
            container_port = 5601
          }

          env {
            name  = "ELASTICSEARCH_URL"
            value = "http://elasticsearch.default.svc.cluster.local:9200"
          }
          
          # Enable enrollment security
          env {
            name  = "xpack.security.enrollment.enabled"
            value = "true"
          }
        }
      }
    }
  }
}

# Create ConfigMap for Logstash main settings
resource "kubernetes_config_map" "logstash_main_config" {
  metadata {
    name      = "logstash-main-config"
    namespace = "default"
  }

  data = {
    "logstash.yml" = <<-EOT
      http.host: "0.0.0.0"
      xpack.monitoring.enabled: true
      path.config: /usr/share/logstash/pipeline
      log.level: info
    EOT
  }
}

# Create ConfigMap for Logstash pipeline configuration
resource "kubernetes_config_map" "logstash_config" {
  metadata {
    name      = "logstash-pipeline-config"
    namespace = "default"
  }

  data = {
    "logstash.conf" = <<-EOT
      input {
        beats {
          port => 5044
        }
      }

      filter {
        # Example: Parse Apache logs
        if [type] == "apache" {
          grok {
            match => { "message" => "%%{COMBINEDAPACHELOG}" }
          }
          date {
            match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
          }
        }
        
        # Example: Parse JSON logs
        if [type] == "json" {
          json {
            source => "message"
          }
        }
      }

      output {
        elasticsearch {
          hosts => ["https://elasticsearch.default.svc.cluster.local:9200"]
          user => "elastic"
          ssl => true
          ssl_certificate_verification => false
          index => "logstash-%%{+YYYY.MM.dd}"
        }
      }
    EOT
  }
}

resource "kubernetes_deployment" "logstash" {
  metadata {
    name      = "logstash"
    namespace = "default"
    labels = {
      app = "logstash"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "logstash"
      }
    }

    template {
      metadata {
        labels = {
          app = "logstash"
        }
      }

      spec {
        container {
          name  = "logstash"
          image = "docker.elastic.co/logstash/logstash:8.16.1"

          port {
            container_port = 5044
          }

          env {
            name  = "ELASTICSEARCH_HOSTS"
            value = "https://elasticsearch.default.svc.cluster.local:9200"
          }

          env {
            name  = "ELASTICSEARCH_USER"
            value = "elastic"
          }

          env {
            name  = "ELASTICSEARCH_PASSWORD"
            value = data.external.elastic_password.result.result
          }

          volume_mount {
            name       = "logstash-pipeline"
            mount_path = "/usr/share/logstash/pipeline"
          }

          volume_mount {
            name       = "logstash-main-config"
            mount_path = "/usr/share/logstash/config/logstash.yml"
            sub_path   = "logstash.yml"
          }
        }

        volume {
          name = "logstash-pipeline"
          config_map {
            name = kubernetes_config_map.logstash_config.metadata[0].name
          }
        }

        volume {
          name = "logstash-main-config"
          config_map {
            name = kubernetes_config_map.logstash_main_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.logstash_config,
    kubernetes_config_map.logstash_main_config,
    data.external.elastic_password
  ]
}

# Use loadbalancer to expose Elasticsearch, Kibana and Logstash with their respective ports ====================================================================================================
resource "kubernetes_service" "elasticsearch" {
  metadata {
    name      = "elasticsearch"
    namespace = "default"
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "elasticsearch"
    }

    port {
      port        = 9200
      target_port = 9200
    }
  }
}

resource "kubernetes_service" "kibana" {
  metadata {
    name      = "kibana"
    namespace = "default"
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "kibana"
    }

    port {
      port        = 5601
      target_port = 5601
    }
  }
}

resource "null_resource" "set_subscription" {
  provisioner "local-exec" {
    command = "az account set --subscription 642dd095-927a-4bdf-9152-d4f6609d0207"
  }
}

resource "null_resource" "aks_get_credentials" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${data.azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks_cluster.name} --overwrite-existing"
  }
  depends_on = [azurerm_kubernetes_cluster.aks_cluster]
}

resource "null_resource" "wait_for_elasticsearch_pod" {
  provisioner "local-exec" {
    command = <<EOT
    kubectl wait --for=condition=ready pod -n default -l app=elasticsearch --timeout=1200s
    EOT
  }
  depends_on = [kubernetes_deployment.elasticsearch]
}

resource "null_resource" "wait_for_kibana_pod" {
  provisioner "local-exec" {
    command = <<EOT
    kubectl wait --for=condition=ready pod -n default -l app=kibana --timeout=1200s
    EOT
  }
  depends_on = [kubernetes_deployment.kibana]
}

data "external" "enrollment_token" {
  program = ["bash", "${path.module}/elastic-enrollment-token.sh"]
  depends_on = [null_resource.wait_for_elasticsearch_pod]
}

data "external" "verification_code" {
  program = ["bash", "${path.module}/kibana-verification-code.sh"]
  depends_on = [null_resource.wait_for_kibana_pod]
}

output "enrollment_token" {
  value = data.external.enrollment_token.result
}

output "verification_code" {
  value = data.external.verification_code.result
}
