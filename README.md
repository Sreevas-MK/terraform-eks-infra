---

##  Remote State Bootstrap

Before the main EKS infrastructure can be deployed, we must establish a **Remote Backend**. This ensures that the Terraform state is stored securely in the cloud and supports state locking to prevent concurrent modifications.

<details>
<summary><b>Click to view Bootstrap Technical Details</b></summary>

### Components

Located in the `00_eks-bootstrap/` directory, this sub-project creates:

* **S3 Bucket (`s3-bucket.tf`):** Provides durable storage for the `terraform.tfstate` file.
* **DynamoDB Table (`dynamodb.tf`):** Implements a locking mechanism using a `LockID` primary key. This prevents two developers (or CI/CD jobs) from running `terraform apply` at the same time.

### Resource Definitions

| Resource | Name / Value | Purpose |
| --- | --- | --- |
| **S3 Bucket** | `eks-project-terraform-state-0001` | State storage |
| **DynamoDB Table** | `eks-project-terraform-locks-0001` | State locking |
| **Billing Mode** | `PAY_PER_REQUEST` | Cost-effective (free tier friendly) |

### How to Initialize

1. Navigate to the bootstrap folder:
```bash
cd 00_eks-bootstrap

```


2. Initialize and Apply:
```bash
terraform init
terraform apply

```


3. After completion, note the bucket name and DynamoDB table name. These are hardcoded into `01_s3_backend.tf` in the root directory.

</details>

---
