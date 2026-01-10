# Enterprise EKS Platform

This repository contains a full-stack Infrastructure-as-Code (IaC) deployment for an Amazon EKS environment. It includes a complete data layer, GitOps with ArgoCD, and a full observability stack.


##  Project Phases

To deploy this infrastructure safely, you can follow the sequence below:

### Phase 1: Remote State Bootstrap
Before the main infrastructure can be managed, we must create a secure place to store the Terraform State. 
* **Go to:** `00_eks-bootstrap/`
* **Purpose:** Create an S3 bucket and DynamoDB table for state locking.
* **Follow the README inside that directory.**

I understand, bro. If we are using `<details>`, we should make it a complete reference guide so you don't have to explain the code to anyone—the README does it for you, line-by-line.

Here is the deep-dive explanation for those 3 files.

---

###  Phase 2: Backend, Providers & Variables

This section covers the core configuration that allows Terraform to talk to AWS and manage the Kubernetes cluster resources.

<details>
<summary><b>Detailed Breakdown: 01_s3_backend.tf</b></summary>

This file tells Terraform **where** to save the state of your infrastructure.

* **`bucket = "eks-project-terraform-state-0001"`**: The S3 bucket where the `.tfstate` file is stored.
* **`key = "eks/eks.tfstate"`**: The folder path inside the bucket. This keeps the EKS state separate from the bootstrap state.
* **`region = "ap-south-1"`**: The AWS region (Mumbai) where the bucket resides.
* **`dynamodb_table = "eks-project-terraform-locks-0001"`**: The table used to "lock" the state. If you are running an update, no one else can change the infra until you're done.
* **`encrypt = true`**: Ensures the state file is encrypted at rest, protecting sensitive data like database passwords.

</details>

<details>
<summary><b>Detailed Breakdown: 02_provider.tf</b></summary>

This file handles the **Authentication Chaining**. It allows Terraform to talk to AWS first, then use AWS credentials to talk to Kubernetes.

* **`required_providers`**: Specific versions of plugins (AWS, Kubernetes, Helm, Kubectl) to ensure the code doesn't break when new versions are released.
* **`provider "aws"`**: Sets the global region for all AWS resources.
* **`provider "kubernetes" / "helm" / "kubectl"`**:
* **`host`**: The API endpoint of your EKS cluster (retrieved dynamically from the EKS module).
* **`cluster_ca_certificate`**: The security certificate needed to trust the EKS cluster.
* **`exec { ... }`**: This is the most important part. It runs `aws eks get-token` in the background. It means you don't need a `kubeconfig` file on your machine; Terraform generates a temporary token to log in automatically.


</details>

<details>
<summary><b>Detailed Breakdown: 03_variables.tf</b></summary>

This is the "Configuration Dashboard." Instead of hunting through 22 files to change a setting, you change it here.

* **Project Identity**: `project_name` and `project_environment` are used to tag every resource for cost tracking.
* **Compute Specs**:
* `eks_node_instance_type` (`t3.medium`): Defines the CPU/RAM of your workers.
* `eks_node_disk_size` (`20GB`): The storage attached to each node.


* **Security**:
* `my_ip_cidr`:  This locks down the Bastion host and EKS API so *only your computer* can access them.


* **GitOps & URLs**:
* `app_repo_url`: The GitHub link where your application code lives.
* `app_host / grafana_url / argocd_url`: The specific domains (e.g., `app.sreevasmk.in`) that the Load Balancer will listen for.


* **Certificates**:
* `certificate_arn`: The SSL certificate from AWS Certificate Manager (ACM) to enable HTTPS (`https://`).


</details>

---
