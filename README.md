# Enterprise EKS Platform

This repository contains a full-stack Infrastructure-as-Code (IaC) deployment for an Amazon EKS environment. It includes a complete data layer, GitOps with ArgoCD, and a full observability stack.

---

##  Project Phases

To deploy this infrastructure safely, you can follow the sequence below:

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

##  Phase 3: EKS Cluster & IAM Integration

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

##  Phase 4: Secure Access & Bastion Management

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


##  Phase 5: Data Layer (RDS & ElastiCache)

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

## Phase 6: External Secrets Operator (ESO) & IAM Security

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

---

### The Secret Flow

1. **AWS RDS** creates a master password and saves it in **AWS Secrets Manager**.
2. **Terraform** installs the **ESO Pod** into the cluster.
3. The **ESO Pod** uses its **IAM Role** to reach out to AWS.
4. The **ClusterSecretStore** points the pod to the correct AWS region.
5. The **ESO Pod** reads the password and creates a standard **Kubernetes Secret** that your App Pods can use.

---
