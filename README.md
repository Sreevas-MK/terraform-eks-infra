# Enterprise EKS Platform

This repository contains a full-stack Infrastructure-as-Code (IaC) deployment for an Amazon EKS environment. It includes a complete data layer, GitOps with ArgoCD, and a full observability stack.


##  Project Phases

To deploy this infrastructure safely, you can follow the sequence below:

### Phase 1: Remote State Bootstrap
Before the main infrastructure can be managed, we must create a secure place to store the Terraform State. 
* **Go to:** `00_eks-bootstrap/`
* **Purpose:** Create an S3 bucket and DynamoDB table for state locking.
* **Follow the README inside that directory.**


