# Enterprise EKS Platform

This repository contains a full-stack Infrastructure-as-Code (IaC) deployment for an Amazon EKS environment featuring an automated PLG Stack (Prometheus, Loki, Grafana) for observability, RDS MySQL for persistent data, and ElastiCache (Valkey) for high-speed caching—all orchestrated via ArgoCD GitOps.

---

##  Project Phases

To deploy this infrastructure safely, you can follow the sequence below:

| Phase | Component | Key Technology | Purpose |
| --- | --- | --- | --- |
| [Phase 1](https://www.google.com/search?q=%23phase-1-remote-state-bootstrap) | **Bootstrap** | S3 & DynamoDB | Securely store and lock Terraform state files. |
| [Phase 2](https://www.google.com/search?q=%23phase-2-backend-providers--variables) | **Foundation** | Terraform Providers | Configure AWS, Kubernetes, and Helm authentication. |
| [Phase 3](https://www.google.com/search?q=%23phase-3-networking) | **Networking** | VPC & Subnets | Establish a 4-tier isolated network (Public/Private/DB/Cache). |
| [Phase 4](https://www.google.com/search?q=%23phase-4-eks-cluster--iam-integration) | **Compute** | Amazon EKS 1.33 | Provision the control plane and managed node groups. |
| [Phase 5](https://www.google.com/search?q=%23phase-5-secure-access--bastion-management) | **Access** | Bastion Host | Secure SSH entry-point into the private network nodes. |
| [Phase 6](https://www.google.com/search?q=%23phase-6-data-layer-rds--elasticache) | **Storage** | RDS & Valkey | Deploy managed database and distributed caching layers. |
| [Phase 7](https://www.google.com/search?q=%23phase-7-external-secrets-operator-eso--iam-security) | **Security** | ESO & Secrets Mgr | Automate secure credential injection into K8s pods. |
| [Phase 8](https://www.google.com/search?q=%23phase-8-full-stack-observability-loki-prometheus--grafana) | **Observability** | PLG Stack | Centralized logging (S3) and metric dashboards. |
| [Phase 9](https://www.google.com/search?q=%23phase-9-argocd--automated-gitops) | **Continuous Delivery** | ArgoCD | Sync GitHub repositories directly to the cluster. |

---

### Phase 1: Remote State Bootstrap
Before the main infrastructure can be managed, we must create a secure place to store the Terraform State. 
* Go to: `00_eks-bootstrap/`
* Purpose: Create an S3 bucket and DynamoDB table for state locking.
* Follow the README inside that directory.

---

###  Phase 2: Backend, Providers & Variables

This section covers the core configuration that allows Terraform to talk to AWS and manage the Kubernetes cluster resources.

<details>
<summary><b>Detailed Breakdown: 01_s3_backend.tf</b></summary>

This file tells Terraform **where** to save the state of your infrastructure.

* `bucket = "eks-project-terraform-state-0001"`: The S3 bucket where the `.tfstate` file is stored.
* `key = "eks/eks.tfstate"`: The folder path inside the bucket. This keeps the EKS state separate from the bootstrap state.
* `region = "ap-south-1"`: The AWS region (Mumbai) where the bucket resides.
* `dynamodb_table = "eks-project-terraform-locks-0001"`: The table used to "lock" the state. If you are running an update, no one else can change the infra until you're done.
* `encrypt = true`: Ensures the state file is encrypted at rest, protecting sensitive data like database passwords.

</details>

<details>
<summary><b>Detailed Breakdown: 02_provider.tf</b></summary>

This file handles the Authentication Chaining. It allows Terraform to talk to AWS first, then use AWS credentials to talk to Kubernetes.

* `required_providers`: Specific versions of plugins (AWS, Kubernetes, Helm, Kubectl) to ensure the code doesn't break when new versions are released.
* `provider "aws"`: Sets the global region for all AWS resources.
* `provider "kubernetes" / "helm" / "kubectl"`:
* `host`: The API endpoint of your EKS cluster (retrieved dynamically from the EKS module).
* `cluster_ca_certificate`: The security certificate needed to trust the EKS cluster.
* `exec { ... }`: It runs `aws eks get-token` in the background. It means you don't need a `kubeconfig` file on your machine; Terraform generates a temporary token to log in automatically.


</details>

<details>
<summary><b>Detailed Breakdown: 03_variables.tf</b></summary>

This is the "Configuration Dashboard."

* Project Identity:
* `aws_region` (`ap-south-1`): The primary region for all infrastructure.
* `project_name` (`eks-infra`): Used as a prefix to name all your AWS resources.
* `project_environment` (`Development`): Tag used to identify the lifecycle of the resources.
* Network Configuration:
* `vpc_cidr_block` (`10.0.0.0/16`): The IP range for the entire virtual network.
* `route53_hosted_zone_arn`: The ARN of your DNS zone for creating record sets.
* Compute Specs:
* `eks_node_instance_type` (`t3.medium`): Defines the CPU/RAM of your worker nodes.
* `eks_node_ami_type` (`AL2023`): The Amazon Linux version for the worker nodes.
* `eks_node_disk_size` (`20GB`): The storage capacity attached to each node.
* GitOps & URLs:
* `app_repo_url`: The GitHub link where your application code lives.
* `app_repo_path`: The folder inside the repo containing the k8s manifests.
* `app_namespace`: The namespace where the application pods will be deployed.
* `app_host / grafana_url / argocd_url`: The specific domains mapped to your Load Balancer.
* Security & Certificates:
* `my_ip_cidr`: This locks down the Bastion host and EKS API so 'only your computer' can access them.
* `certificate_arn`: The SSL certificate from ACM to enable secure HTTPS traffic.
* `alb_group_name`: The identifier for the shared Application Load Balancer.

</details>

---

###  Phase 3: Networking

This section explains the VPC architecture. This uses a 4-tier subnet setup to ensure that your application, database, and cache layers are completely isolated from the public internet.

<details>
<summary><b>Detailed Breakdown: 04_vpc.tf</b></summary>

This file uses the official AWS VPC module to build the network backbone.

* Core Network:
* `name`: Sets the VPC name using the project variable.
* `cidr`: The primary IP range (10.0.0.0/16) for all subnets.
* `azs`: Distributes the network across three Availability Zones (1a, 1b, 1c) for high availability.
* Subnet Strategy:
* `public_subnets`: Used for the NAT Gateway and the Application Load Balancer (ALB).
* `private_subnets`: This is where the EKS Worker Nodes live. They have no direct internet access.
* `database_subnets`: Dedicated isolated subnets for your RDS MySQL instance.
* `elasticache_subnets`: Dedicated isolated subnets for your Valkey/Redis cache.
* Internet Access (NAT):
* `enable_nat_gateway`: Allows private nodes to download updates from the internet.
* `single_nat_gateway`: Uses one NAT gateway for all AZs to save costs during development.
* Kubernetes Integration Tags:
* `kubernetes.io/role/elb` (Public): Tells the AWS Load Balancer Controller to use these subnets for Internet-facing ALBs.
* `kubernetes.io/role/internal-elb` (Private): Tells the controller to use these subnets for internal load balancers.
* `kubernetes.io/cluster/...`: A required tag that allows EKS to "own" and manage the networking resources in this VPC.

</details>

<details>
<summary><b>Detailed Breakdown: 05_vpc_outputs.tf</b></summary>

This file shows outputs for VPC and its subnets.

* `vpc_id`: Exports the unique ID of the VPC so security groups can be created inside it.
* `public_subnet_id`: Provides the list of public subnet IDs for the Bastion host and ALBs.
* `private_subnet_id`: Provides the list of private subnet IDs where the EKS nodes will be provisioned.

</details>

---

###  Phase 4: EKS Cluster & IAM Integration

This section covers the creation of the Kubernetes Control Plane, the specialized networking add-ons, and the IAM Roles for Service Accounts (IRSA) that bridge K8s to AWS.

<details>
<summary><b>Detailed Breakdown: 06_key_pair.tf</b></summary>

This file handles the SSH authentication for your worker nodes and bastion host.

* SSH Configuration:
* `key_name`: The identifier used by AWS to refer to this key (`eks-infra-ssh-key`).
* `public_key`: The `file()` function reads the actual key string from your local `./files/eks-key.pub`.
* `tags`: Project and Environment tags are applied to the key for billing and management.

</details>

<details>
<summary><b>Detailed Breakdown: 07_eks.tf</b></summary>

This is the main cluster configuration file. It manages the cluster, nodes, and core add-ons.

* Cluster Control Plane:
* `source`: Uses the industry-standard Terraform AWS EKS module.
* `kubernetes_version`: Set to "1.33" to use the latest stable features.
* `enable_irsa`: Creates an OpenID Connect (OIDC) provider. This is what allows Kubernetes Service Accounts to assume AWS IAM roles.
* `enable_cluster_creator_admin_permissions`: Automatically gives the person who ran `terraform apply` full admin rights to the cluster.
* Networking Add-ons:
* `coredns`: Handles internal service discovery (DNS) inside the cluster.
* `eks-pod-identity-agent`: The modern way to handle IAM permissions for pods.
* `kube-proxy`: Manages network rules on nodes to allow network communication to your pods.
* `vpc-cni`: The networking plugin.
* `ENABLE_PREFIX_DELEGATION`: Set to "true". This allows each node to handle more IP addresses, preventing "IP exhaustion" in small subnets.
* `WARM_PREFIX_TARGET`: Keeps 1 IP prefix ready to speed up pod startup times.
* Infrastructure Placement:
* `vpc_id`: Specifies the VPC built in Phase 2.
* `subnet_ids`: Places worker nodes in **Private Subnets** so they aren't exposed to the internet.
* `control_plane_subnet_ids`: Places the cluster API endpoints in the same private subnets.
* Managed Node Groups (The Workers):
* `ami_type`: Uses `AL2023`, the latest Amazon Linux optimized for EKS.
* `instance_types`: Configures the CPU/RAM (e.g., `t3.medium`).
* `key_name`: Attaches the SSH key created in File 06 to the nodes.
* `http_tokens = "required"`: Enforces IMDSv2. This stops attackers from stealing IAM role credentials from the node metadata.
* `scaling_config`: Sets the boundaries (1 to 2 nodes) to manage costs while allowing for high availability.
* IAM Integration (IRSA Modules):
* `ebs_csi_driver_irsa`: Creates the IAM role with `attach_ebs_csi_policy = true` so pods can mount EBS disks.
* `lb_controller_irsa`: Creates a role with `attach_load_balancer_controller_policy = true` to manage ALBs.
* `external_dns_irsa`: Creates a role to allow the cluster to update Route53 DNS records automatically.
* `oidc_providers`: Links these IAM roles to the EKS cluster OIDC URL so only your cluster can use them.
* Blueprints Add-ons (The Software):
* `aws-ebs-csi-driver`: Installs the driver that actually creates EBS volumes for your databases.
* `enable_aws_load_balancer_controller`: Installs the controller that creates the AWS Application Load Balancer.
* `enable_metrics_server`: Installs the service that allows `kubectl top nodes` and horizontal scaling.
* `enable_external_dns`: Installs the service that syncs your K8s Ingress hostnames to Route53.
* Security & Connectivity:
* `kubernetes_storage_class_v1`: Defines `gp3` (SSD) as the default storage. `WaitForFirstConsumer` ensures the disk is created in the same AZ where the pod is running.
* `bastion_to_api`: An Ingress rule allowing the Bastion Security Group to talk to the Cluster API (Port 443).
* `bastion_to_node_ssh`: An Ingress rule allowing the Bastion to SSH into worker nodes (Port 22).

</details>

---

###  Phase 5: Secure Access & Bastion Management

<details>
<summary><b>Detailed Breakdown: 08_bastion_host_security_group.tf</b></summary>

This file defines the firewall rules for the Bastion Host.

* Ingress Rules:
* `from_port = 22` / `to_port = 22`: Enables SSH access.
* `cidr_blocks = [var.my_ip_cidr]`: **Security Lockdown.** Only your specific public IP can attempt to connect. All other traffic is dropped.
* Egress Rules:
* `from_port = 0` / `protocol = "-1"`: Allows all outbound traffic so the Bastion can download tools (kubectl, helm) and talk to the AWS API.

</details>

<details>
<summary><b>Detailed Breakdown: 09_iam_bastion.tf</b></summary>

This file creates the "Identity" for the Bastion host so it can talk to AWS services.

* IAM Policy (`bastion_eks_access`):
* `eks:DescribeCluster`: Allows the Bastion to pull cluster details.
* `sts:GetCallerIdentity`: Required for the AWS CLI to verify which user/role is running commands.
* IAM Role & Profile:
* `aws_iam_role`: The actual identity the EC2 instance "assumes."
* `aws_iam_instance_profile`: The container that attaches the IAM Role to the EC2 hardware.

</details>

<details>
<summary><b>Detailed Breakdown: 10_bastion_host_setup.tf</b></summary>

This file provisions the actual EC2 instance and prepares it for work.

* AMI Selection:
* `data "aws_ami"`: Dynamically finds the latest Amazon Linux 2023 image.
* Instance Configuration:
* `instance_type = "t2.micro"`: Keeps costs low (Free Tier eligible).
* `subnet_id`: Places the Bastion in the **Public Subnet** so it is reachable via the internet.
* `associate_public_ip_address`: Assigns a public IP so you can SSH into it.
* `user_data`: Runs the `./files/bastion_setup.sh` script on startup to automatically install `kubectl`, `helm`, and `aws-cli`.
* Storage:
* `volume_size = 5`: A small 5GB disk for logs and tools.
* `encrypted = true`: Ensures any sensitive scripts on the disk are protected.

</details>

<details>
<summary><b>Detailed Breakdown: 11_eks_bastion_access.tf</b></summary>

This file bridges the gap between the Bastion Host and the Kubernetes API.

* EKS Access Entry:
* `principal_arn`: Registers the Bastion's IAM Role as a recognized user in the EKS cluster.
* `type = "STANDARD"`: The modern EKS way to manage access without editing the `aws-auth` ConfigMap.
* Policy Association:
* `policy_arn = "...AmazonEKSClusterAdminPolicy"`: Grants the Bastion full **Administrator** rights inside Kubernetes.
* `access_scope`: Set to `cluster`, meaning the Bastion can manage all namespaces and resources.

</details>

---


###  Phase 6: Data Layer (RDS & ElastiCache)

<details>
<summary><b>Detailed Breakdown: 12_rds_eca_securitygroup.tf</b></summary>

This file defines the networking "gatekeepers" for your data. It ensures that only authorized traffic can reach your databases.

* RDS Security Group (`rds_sg`):
* `name`: Identifies the group as the MySQL firewall.
* `vpc_id`: Anchors the firewall to the project VPC.
* `rds_from_eks`: A specific ingress rule allowing traffic on **Port 3306** (MySQL) only from the EKS Worker Nodes.
* `rds_from_bastion`: A specific ingress rule allowing traffic on **Port 3306** from the Bastion host, enabling you to run database migrations or manual queries.
* ElastiCache Security Group (`redis_sg`):
* `name`: Identifies the group as the Redis/Valkey firewall.
* `redis_from_eks`: A specific ingress rule allowing traffic on **Port 6379** (Redis default) only from the EKS Worker Nodes.
* `redis_from_bastion`: Allows you to test cache connectivity from the Bastion host on **Port 6379**.

</details>

<details>
<summary><b>Detailed Breakdown: 13_rds.tf</b></summary>

This file provisions the managed MySQL database.

* Engine Configuration:
* `engine = "mysql"`: Uses the community MySQL engine.
* `engine_version = "8.0"`: Standardizes on version 8.0 for modern feature support.
* `instance_class = "db.t4g.micro"`: Uses AWS Graviton2 processors for the best price-to-performance ratio in the free/low-cost tier.
* Storage & Settings:
* `allocated_storage = 20`: Sets the initial disk size to 20GB.
* `db_name = "company"`: Automatically creates the initial database schema name.
* `username = "appadmin"`: Sets the master username.
* `manage_master_user_password`: Tells AWS to generate a secure password and manage it (can be retrieved via Secrets Manager).
* Networking & Safety:
* `db_subnet_group_name`: Places the DB into the dedicated isolated database subnets created in Phase 2.
* `publicly_accessible = false`: **Security Requirement.** Ensures the database has no public IP and cannot be reached from the internet.
* `skip_final_snapshot = true`: Disables the final backup during `terraform destroy` to speed up the teardown process (use only for Dev).
* `deletion_protection = false`: Allows Terraform to delete the DB during cleanup without manual intervention.

</details>

<details>
<summary><b>Detailed Breakdown: 14_eca.tf</b></summary>

This file provisions the Valkey (Redis-compatible) caching layer.

* Cache Engine:
* `engine = "valkey"`: Uses the high-performance, open-source Valkey engine (Redis alternative).
* `engine_version = "8.2"`: Sets the specific engine version.
* `node_type = "cache.t4g.micro"`: Cost-effective Graviton instance for caching.
* Cluster & Scalability:
* `cluster_mode_enabled`: Enables the cluster architecture for better performance.
* `num_node_groups = 1`: Creates a single shard for the data.
* `replicas_per_node_group = 0`: Disables replicas to save costs during development (single-node setup).
* Network & Security:
* `subnet_group_name`: Places the cache nodes in the private ElastiCache subnets.
* `create_security_group = false`: We use the manual security group created in File 12 to have better control over ingress rules.
* `apply_immediately`: Ensures that configuration changes are applied instantly rather than waiting for a maintenance window.

</details>

---

### Phase 7: External Secrets Operator (ESO) & IAM Security

This phase is critical for security. It ensures that the database credentials created by AWS are pulled into Kubernetes automatically and securely without any human ever seeing the password.

<details>
<summary><b>Detailed Breakdown: 15_eso_iam.tf</b></summary>

This file creates the "Security Bridge" between the Kubernetes Pod and the AWS Secrets Manager service.

* **module "external_secrets_irsa"**:
* `source`: Uses the official IAM module for EKS Service Accounts.
* `role_name`: Assigns a clear name to the IAM role in the AWS Console.
* `depends_on`: Ensures the EKS cluster exists before trying to create an OIDC link to it.
* `oidc_providers`: This is the trust relationship. It tells AWS "I trust the OIDC identity issued by this specific EKS cluster."
* `namespace_service_accounts`: This is a security lock. It ensures **only** the Service Account named `external-secrets-sa` in the `external-secrets` namespace can use this IAM role.
* `role_policy_arns`: Attaches the custom permission policy we define below.
* **resource "aws_iam_policy" "external_secrets_policy"**:
* `name`: The display name of the permission set in AWS.
* `Action`: Specifies exactly what the operator can do: `GetSecretValue` (read the password) and `DescribeSecret` (get metadata).
* `Effect = "Allow"`: Grants these permissions.
* `Resource`: This is the most important security line. It restricts the operator to ONLY read the secret belonging to your RDS instance (`module.db.db_instance_master_user_secret_arn`). It cannot read any other secrets in your account.

</details>

<details>
<summary><b>Detailed Breakdown: 16_eso_helm.tf</b></summary>

This file installs the operator software and configures the Cluster-level connection to AWS.

* **resource "helm_release" "external_secrets"**:
* `repository`: The official source URL for the External Secrets Helm charts.
* `chart`: The name of the package to install.
* `version`: Pins the software version to `0.16.1` to prevent unexpected updates.
* `create_namespace`: Tells Helm to create the `external-secrets` namespace if it doesn't exist.
* `depends_on`: Ensures the EKS nodes and Blueprints (like the Load Balancer Controller) are ready before installing this.
* `set { installCRDs = "true" }`: Installs the "Custom Resource Definitions." This teaches Kubernetes new commands like `ClusterSecretStore`.
* `set { serviceAccount.annotations... }`: This is the link. It adds the IAM Role ARN to the Kubernetes Service Account so the pod can authenticate with AWS.
* **resource "kubectl_manifest" "cluster_secret_store"**:
* `depends_on`: This must wait for the Helm chart to finish installing the CRDs, otherwise the command will fail.
* `yaml_body`: This is the actual configuration that tells the operator how to behave.
* `kind: ClusterSecretStore`: Creates a global secret provider that can be used by any namespace in the cluster.
* `spec.provider.aws`: Tells the operator to talk to **AWS Secrets Manager**.
* `region`: Uses your variable to look for secrets in the `ap-south-1` region.
* `auth.jwt.serviceAccountRef`: Tells the operator: "When you try to log into AWS, use the permissions attached to the `external-secrets-sa`."

</details>

#### The Secret Flow

1. **AWS RDS** creates a master password and saves it in **AWS Secrets Manager**.
2. **Terraform** installs the **ESO Pod** into the cluster.
3. The **ESO Pod** uses its **IAM Role** to reach out to AWS.
4. The **ClusterSecretStore** points the pod to the correct AWS region.
5. The **ESO Pod** reads the password and creates a standard **Kubernetes Secret** that your App Pods can use.

---

###  Phase 8: Full-Stack Observability (Loki, Prometheus & Grafana)

This phase builds a professional-grade monitoring and logging pipeline. Instead of storing logs on expensive and volatile EBS disks, we offload everything to **AWS S3** for long-term durability and cost-efficiency. This ensures that even if your nodes are deleted, your logs remain safe and searchable.


<details>
<summary><b>Detailed Breakdown: 17_monitoring_s3.tf</b></summary>

This file creates the "Hard Drive" in the cloud where Loki will store its data.

* **aws_s3_bucket "loki_logs"**:
* `bucket`: Dynamically names the bucket using your project prefix (e.g., `eks-infra-loki-logs`).
* `force_destroy = true`: Allows the bucket to be deleted during `terraform destroy` even if it contains log files.
* **module "loki_irsa"**:
* `source`: Creates an IAM Role for Service Accounts (IRSA).
* `role_name`: The name of the role as it appears in the AWS Console.
* `namespace_service_accounts`: This is the security glue. It says "Only the pod using the service account `monitoring-stack-loki` in the `monitoring` namespace can use this role."
* **resource "aws_iam_policy" "loki_s3_policy"**:
* `s3:ListBucket`: Allows Loki to see the "folders" and files inside the bucket.
* `s3:GetObject`: Allows Loki to read logs when you search for them in Grafana.
* `s3:PutObject`: Allows Loki to write new logs coming in from the cluster.
* `s3:DeleteObject`: Allows Loki to clean up old logs based on your retention policy.

</details>

<details>
<summary><b>Detailed Breakdown: 18_monitoring_helm.tf</b></summary>

This file handles the deployment and complex logic of the monitoring software.

* **resource "kubernetes_namespace_v1" "monitoring"**:
* Creates an isolated logical boundary in Kubernetes specifically for monitoring tools.
* **resource "helm_release" "monitoring_stack"**:
* `recreate_pods = true`: Forces pods to restart if you change the configuration, ensuring no old settings linger.
* `templatefile(...)`: This is where the magic happens. It takes the `values-s3.yaml.tpl` file and injects your real AWS bucket names and IAM Role ARNs into the configuration.
* `grafana.ini`: Configures the Grafana web server.
* `domain / root_url`: Sets the URL (`grafana.sreevasmk.in`) and ensures that when you click a link in Grafana, it uses the secure HTTPS domain.
* `serve_from_sub_path`: Required for the Application Load Balancer to route traffic to Grafana correctly.

</details>

<details>
<summary><b>Detailed Breakdown: 19_grafana_ingress.tf</b></summary>

This file makes Grafana accessible via the internet through an AWS Application Load Balancer.

* **metadata.annotations**:
* `ingress.class = "alb"`: Triggers the AWS LB Controller to provision a physical Load Balancer.
* `group.name`: This is a cost-saver. It merges this Ingress with your App and ArgoCD into one single ALB.
* `certificate-arn`: Attaches your SSL certificate for HTTPS encryption.
* `ssl-redirect`: Automatically redirects any user on port 80 (HTTP) to 443 (HTTPS).
* `healthcheck-path = "/api/health"`: Tells the ALB how to check if Grafana is actually running.

</details>

<details>
<summary><b>Detailed Breakdown: values-s3.yaml.tpl</b></summary>

This is the most important configuration file. Here is exactly what the code does:

* **Loki (The Log Database)**:
* `image.tag: 2.9.0`: Pins the version of Loki to ensure stability.
* `serviceAccount.annotations`: This injects the `${loki_iam_role_arn}`. Without this line, Loki cannot talk to S3 and will crash.
* `persistence.enabled: false`: We disable "Persistent Volumes" because we don't want to use expensive AWS EBS disks; we use S3 instead.
* `config.common.storage.s3`: Tells Loki the exact bucket name and AWS region to store logs.
* `schema_config`: Configures how logs are indexed.
* `store: boltdb-shipper`: The modern way to handle indexes.
* `object_store: s3`: Tells Loki that the actual log "blobs" should live in S3.
* `schema: v13`: The latest data structure for Loki logs.
* `retention_period: 24h`: Every 24 hours, Loki will delete old logs from S3 to keep your AWS bill low.
* **Promtail (The Log Collector)**:
* `enabled: true`: Promtail runs as a "DaemonSet" (one pod on every node).
* `clients.url`: Tells Promtail to send all the logs it finds to the Loki service at port 3100.
* `scrape_configs`:
* `role: pod`: Promtail looks at every single Pod running on the node.
* `relabel_configs`: It takes the Pod's name and Namespace and turns them into "labels" in Grafana so you can filter logs by "App" or "Namespace."
* **Prometheus (The Metrics Engine)**:
* `enabled: true`: Starts the metrics collection.
* `extraScrapeConfigs`: This is a huge section that tells Prometheus to "auto-discover" everything in the cluster.
* `job_name: kubernetes-pods-all`: Finds every pod and asks for its CPU/RAM usage.
* `job_name: kubernetes-nodes-all`: Checks the health of the physical EC2 instances.
* **Node Exporter**:
* `tolerations`: These lines allow the monitoring agent to run on "special" nodes that might have taints (like the control plane), ensuring 100% coverage of your cluster.

</details>

<details>
<summary><b>Line-by-Line Breakdown: monitoring-configmap.yml</b></summary>

This file configures Grafana's "Phonebook" so it knows where to find data.

* **metadata.labels**:
* `grafana_datasource: "1"`: This label is critical. Grafana has a "sidecar" container that searches the cluster for any ConfigMap with this label and automatically adds it as a source.
* **data.datasources.yaml**:
* `name: Prometheus`: The name that appears in the Grafana dropdown.
* `url: http://monitoring-stack-prometheus-server:9090`: The internal network address of Prometheus.
* `name: Loki`: The name for the log source.
* `url: http://monitoring-stack-loki:3100`: The internal network address of Loki.

</details>

---

###  Phase 9: ArgoCD & Automated GitOps

<details>
<summary><b>Detailed Breakdown: 20_argocd.tf</b></summary>

This file installs the ArgoCD engine itself.

* **kubernetes_namespace "argocd"**:
* Creates a dedicated, isolated home for the ArgoCD system.
* `depends_on`: Ensures the EKS cluster and nodes are fully active before trying to install software.


* **helm_release "argocd"**:
* `repository`: Pulls from the official `argo-helm` charts.
* `set { configs.cm.url }`: Tells ArgoCD its own public address (`argocd.sreevasmk.in`) so it can generate correct internal links.
* `set { configs.params.server.insecure = "true" }`: This allows the AWS Load Balancer to talk to ArgoCD over plain HTTP/HTTPS without complicated internal certificate handshakes, as the ALB handles the external SSL.


</details>

<details>
<summary><b>Detailed Breakdown: 21_argocd_application.tf</b></summary>

This is the "Brain" of your application deployment. It connects the infrastructure you built (RDS, Valkey) to your application code.

* **kubernetes_namespace_v1 "app_ns"**:
* Creates the namespace where your actual Flask app will run.
* **Pod Security Labels**: These are modern K8s security standards.
* `enforce: baseline`: Prevents pods from running with dangerous "root" privileges.
* `warn: restricted`: Warns the developer if they are not following the strictest security best practices.


* **kubectl_manifest "employees_app"**:
* This is an **ArgoCD Application Custom Resource**. It defines the "What, Where, and How."
* `source`: Points to your GitHub repo (`repoURL`) and the specific folder where your Helm charts live (`path`).
* **Helm Parameters (Injecting Infrastructure into Apps)**:
* `flask.secrets.DB_HOST`: Injects the real RDS endpoint address created in Phase 5.
* `flask.secrets.REDIS_HOST`: Injects the Valkey endpoint. The `split` function is used to remove the port number from the URL string.
* `flask.secrets.remoteRef.key`: Passes the **AWS Secrets Manager ARN**. The External Secrets Operator (Phase 6) will use this to grab the DB password.


* `syncPolicy`:
* `automated.prune`: If you delete a resource from Git, ArgoCD will automatically delete it from K8s.
* `automated.selfHeal`: If someone manually changes something in K8s, ArgoCD will overwrite it back to the Git state.


</details>

<details>
<summary><b>Detailed Breakdown: 22_argocd_ingress.tf</b></summary>

This file exposes the ArgoCD UI to you so you can monitor your deployments in a browser.

* **metadata.annotations**:
* `ingress.class = "alb"`: Triggers the AWS ALB creation.
* `group.name`: **CRITICAL.** This joins ArgoCD, Grafana, and your Flask app under **one single Load Balancer**. This saves you roughly **$40/month** in AWS costs by sharing one ALB across three services.
* `backend-protocol = "HTTPS"`: Since ArgoCD is highly secure, it expects internal traffic to be encrypted.
* `healthcheck-path = "/healthz"`: The specific URL the ALB pings to make sure ArgoCD is healthy.


* **spec.rule**:
* `host`: Listens for `argocd.sreevasmk.in`.
* `backend.service.port.number = 443`: Forwards the traffic to ArgoCD's secure internal port.



</details>

---
