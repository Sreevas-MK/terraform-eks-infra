#  GitHub Actions Workflow

This project uses GitHub Actions to automate the lifecycle of the EKS Infrastructure.

##  1. EKS Infrastructure Pipeline (`terraform-apply.yml`)

**Trigger:** Automatic on `push` or `pull_request` to the `main` branch.

###  Purpose

This is the primary Continuous Deployment (CD) pipeline. Every time you change your Terraform code and push it to GitHub, this workflow ensures the cloud environment matches your code.

###  Workflow Steps:

1. **Checkout Code:** Pulls the repository onto the GitHub runner.
2. **Setup Terraform:** Installs the specific version (`v3.1.2`) of the Terraform CLI.
3. **Generate SSH Key:** Injects your `SSH_PUBLIC_KEY` secret into `./files/eks-key.pub`. This ensures the Bastion host and EKS nodes can be accessed via the key you own.
4. **Init & Apply:** * Initializes the backend (S3).
* Automatically executes changes to the VPC, EKS, RDS, and Helm charts.

---

##  2. EKS Infrastructure Destroy (`terraform-destroy.yml`)

**Trigger:** **Manual Only** via the "Run workflow" button in the Actions tab.

###  Purpose

This workflow is a safety-first mechanism to tear down the entire infrastructure to save costs or reset the environment.

###  Safety Mechanism

The workflow will **fail immediately** unless you explicitly type `DESTROY` into the input prompt. This prevents accidental deletions.

###  Workflow Steps:

1. **Validation:** Checks if the manual input matches "DESTROY".
2. **Checkout & Setup:** Prepares the environment and SSH keys.
3. **Terraform Init:** Connects to the existing state in S3.
4. **Terraform Destroy:** Identifies all created resources and deletes them in the correct order (Helm charts first, then EKS, then VPC).

---

##  Required GitHub Secrets & Variables

To make these workflows function, the following must be configured in **Settings > Secrets and variables > Actions**:

| Name | Type | Description |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | IAM User key with AdministratorAccess |
| `AWS_SECRET_ACCESS_KEY` | Secret | IAM User secret |
| `SSH_PUBLIC_KEY` | Secret | The content of your `.pub` file for EC2 access |
| `AWS_REGION` | Variable | Set to `ap-south-1` (defined in the YAML) |

---

##  How to use the Manual Destroy

1. Navigate to the **Actions** tab in your GitHub repository.
2. Select **"EKS Infrastructure Destroy (MANUAL ONLY)"** from the sidebar.
3. Click the **Run workflow** dropdown.
4. Enter `DESTROY` in the text box.
5. Click the green **Run workflow** button.

---

##  Important Considerations

* **State Locking:** Both workflows use the DynamoDB table (from the bootstrap) to prevent two people from running the pipeline at once.
* **Bootstrap Dependencies:** These workflows assume the **S3 Bucket** and **DynamoDB** table already exist. If they don't, you must run the bootstrap folder manually from your local server first.

---
