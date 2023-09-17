resource "google_iam_workload_identity_pool" "upload_to_big3_storage" {
  # ID must be unique due to soft deletion.
  workload_identity_pool_id = "upload-to-big-3-storage-${var.unique_identifier}"
  display_name              = "Upload to Big 3 Storage IdP"
  description               = "Upload to Big 3 Storage Cross Cloud Identity"
}

# From AWS

resource "google_iam_workload_identity_pool_provider" "aws" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.upload_to_big3_storage.workload_identity_pool_id
  workload_identity_pool_provider_id = "upload-to-big3-storage-aws"
  display_name                       = "Federate from AWS IAM Role"

  aws {
    account_id = var.aws_account_id
  }

  attribute_mapping = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_account" = "assertion.aws_account_id"
    "attribute.aws_role"    = "assertion.arn.extract('assumed-role/{role}/')"
  }
}

resource "google_service_account_iam_member" "aws" {
  service_account_id = google_service_account.upload_to_big3_storage.name
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.upload_to_big3_storage.name}/attribute.aws_role/${var.aws_iam_role_name}"
  role               = "roles/iam.workloadIdentityUser"

  depends_on = [
    google_iam_workload_identity_pool.upload_to_big3_storage,
    google_iam_workload_identity_pool_provider.aws
  ]
}

data "template_file" "aws_workload_identity_client_configuration" {
  template = file("${path.module}/templates/aws-workload-identity-federation-configuration.tpl")

  vars = {
    identity_pool_provider_name = google_iam_workload_identity_pool_provider.aws.name
    service_account_email       = google_service_account.upload_to_big3_storage.email
  }
}

# From Azure
