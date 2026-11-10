terraform {
  backend "s3" {
    bucket         = "eks-gitops-terraform-state-bucket"
    key            = "platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-terraform-locks"
    encrypt        = true
  }
}
