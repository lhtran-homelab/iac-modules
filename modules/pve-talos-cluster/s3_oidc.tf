data "aws_caller_identity" "current" {
  count = local.s3_oidc_enabled ? 1 : 0
}

resource "aws_s3_bucket" "oidc" {
  count  = local.s3_oidc_enabled ? 1 : 0
  bucket = local.oidc_bucket
  region = local.oidc_region
}

resource "aws_s3_bucket_public_access_block" "oidc" {
  count                   = local.s3_oidc_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.oidc[0].id
  region                  = local.oidc_region
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "oidc_discovery" {
  count  = local.s3_oidc_enabled ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id
  region = local.oidc_region
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadDiscoveryDocuments"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource = [
        "${aws_s3_bucket.oidc[0].arn}/.well-known/openid-configuration",
        "${aws_s3_bucket.oidc[0].arn}/openid/v1/jwks",
      ]
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.oidc]
}

resource "null_resource" "wait_for_anonymous_jwks" {
  count = local.s3_oidc_enabled ? 1 : 0

  triggers = {
    bootstrap = talos_machine_bootstrap.this.id
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/templates/wait-for-url.sh.tmpl", {
      ca_cert_pem      = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
      client_cert_pem  = ""
      client_key_pem   = ""
      url              = "${talos_cluster_kubeconfig.this.kubernetes_client_configuration.host}/openid/v1/jwks"
      expected_status  = "200"
      attempts         = 60
      interval_seconds = 5
      description      = "Waiting for anonymous access to the cluster JWKS endpoint"
    })
  }

  depends_on = [null_resource.wait_for_kube_apiserver]
}

data "http" "cluster_jwks" {
  count       = local.s3_oidc_enabled ? 1 : 0
  url         = "${talos_cluster_kubeconfig.this.kubernetes_client_configuration.host}/openid/v1/jwks"
  ca_cert_pem = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Fetching the cluster JWKS returned HTTP ${self.status_code}: ${self.response_body}"
    }
  }

  depends_on = [null_resource.wait_for_anonymous_jwks]
}

resource "aws_s3_object" "oidc_jwks" {
  count        = local.s3_oidc_enabled ? 1 : 0
  bucket       = aws_s3_bucket.oidc[0].id
  region       = local.oidc_region
  key          = "openid/v1/jwks"
  content      = data.http.cluster_jwks[0].response_body
  content_type = "application/json"
}

resource "aws_s3_object" "oidc_openid_configuration" {
  count        = local.s3_oidc_enabled ? 1 : 0
  bucket       = aws_s3_bucket.oidc[0].id
  region       = local.oidc_region
  key          = ".well-known/openid-configuration"
  content_type = "application/json"
  content = jsonencode({
    issuer                                = local.oidc_issuer
    jwks_uri                              = local.oidc_jwks_uri
    response_types_supported              = ["id_token"]
    subject_types_supported               = ["public"]
    id_token_signing_alg_values_supported = ["RS256"]
    claims_supported                      = ["sub", "iss", "aud", "exp", "iat"]
  })
}