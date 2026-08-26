# Runbook

Operational detail for deploying and running useSend on AWS. Start in the
[README](../README.md); this covers the manual AWS steps and day-2 operations.

## 1. Tooling

macOS:
```bash
brew install terraform awscli jq
# Docker Desktop for local eval: https://www.docker.com/products/docker-desktop
aws configure          # or aws configure sso
aws sts get-caller-identity   # confirm you're on the right account
```

## 2. Remote Terraform state (recommended)

Before your first real apply, create an encrypted state bucket + lock table,
then uncomment the `backend "s3"` block in `terraform/versions.tf` and run
`terraform init -migrate-state`.
```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://usesend-tfstate-$ACCT --region us-east-1
aws s3api put-bucket-versioning --bucket usesend-tfstate-$ACCT \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name usesend-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1
```
The DB and auth-secret values live in state, so keeping state encrypted +
private matters.

## 3. SES production access (do this FIRST — it's slow)

New SES accounts are in a **sandbox**: ~200 emails/day, 1/sec, and you can only
send to verified addresses. To send real transactional mail:

1. AWS console → **SES** → *Account dashboard* → **Request production access**.
2. Describe your use case (transactional email for your products), expected
   volume, and how you handle bounces/complaints (useSend does, via SNS).
3. Request a **sending-quota increase** to your expected peak.
4. Approval is human-reviewed, usually 24–48h. Do it before you need it.

Keep bounce rate < 5% and complaint rate < 0.1% or SES throttles/pauses the
account. useSend ingests these via SNS and maintains suppression lists.

## 4. GitHub OAuth App (dashboard login)

GitHub → Settings → Developer settings → **OAuth Apps** → New:
- Homepage URL: `https://<app_domain>`
- Authorization callback URL: `https://<app_domain>/api/auth/callback/github`

Put the client ID in `terraform.tfvars` (`github_client_id`) and export the
secret as `TF_VAR_github_client_secret` so it stays out of the file.

## 5. Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit app_domain, route53_zone_id, github_client_id
export TF_VAR_github_client_secret='...'
terraform init
terraform plan          # review
terraform apply
terraform output        # app_url, ses_callback_url, github_oauth_callback_url, alb_dns_name
```

Notes:
- **First boot runs migrations.** Each task runs `prisma migrate deploy` at
  start (Prisma takes an advisory lock, so concurrent boots are safe). The
  service has a 300s health-check grace period so the lock-waiting second task
  isn't killed before the first finishes migrating. For a very large initial
  migration you can also set `app_desired_count = 1` for the first apply, then
  scale up.
- **ACM + DNS:** with `route53_zone_id` set, cert validation and the app record
  are automatic. Without it, either set `acm_certificate_arn` to a pre-validated
  cert or the HTTPS listener can't come up.

## 6. Post-deploy verification

```bash
curl -fsS https://<app_domain>/api/health          # -> {"data":"Healthy"}
curl -fsS https://<app_domain>/api/ses_callback     # -> {"data":"Hello"} (reachable for SNS)
```
Then sign in and configure SES in the admin UI (region + the `ses_callback_url`
output). useSend validates reachability, creates the configuration set, and
subscribes SNS to `https://<app_domain>/api/ses_callback`.

## 7. Scaling

- Tasks autoscale on CPU (target 65%, 2→6). Adjust in `ecs.tf`
  (`aws_appautoscaling_*`).
- Bigger DB/Redis: change `db_instance_class` / `redis_node_type` and apply.
- Higher SES throughput: request a quota increase (per region).

## 8. Backups & DR

- RDS: 7-day automated backups + PITR are on; `deletion_protection = true` and a
  final snapshot are set. Take a manual snapshot before major upgrades.
- Redis holds only the job queue; 3 daily snapshots are configured. It's not the
  source of truth.
- Single region/deployment = shared blast radius. Multi-AZ RDS covers an AZ
  loss; for region loss you'd restore from snapshot in another region.

## 9. Upgrades

1. Pick a specific useSend version tag (avoid `:latest` in prod).
2. Set `usesend_image = "usesend/usesend:<tag>"`, `terraform apply` (rolling
   deploy with circuit-breaker rollback).
3. **Re-run [`isolation-tests.md`](isolation-tests.md)** — isolation is
   app-layer and can regress between versions.

## 10. Object storage (optional)

Only needed for **editor image uploads** in the campaign/template editor.
Transactional send and boot never use it. To enable, add these to the ECS task
`environment` in `ecs.tf` (all five required together):

```
S3_COMPATIBLE_API_URL      # e.g. https://<account>.r2.cloudflarestorage.com
S3_COMPATIBLE_PUBLIC_URL   # public read base incl. bucket, e.g. https://cdn.yourco.com
S3_COMPATIBLE_ACCESS_KEY   # static key (the app's S3 client does NOT use the task role)
S3_COMPATIBLE_SECRET_KEY
S3_COMPATIBLE_BUCKET
```

⚠️ useSend's S3 client hardcodes `region: "auto"` and `forcePathStyle: true`.
That works with **Cloudflare R2 or MinIO** but **real AWS S3 will reject the
presigned upload** (SigV4 region mismatch) unless you patch that line in a fork.
Recommendation: if you want image uploads, back them with **R2** (also has no
egress fees); otherwise leave storage off.

## 11. Reputation isolation per product

By default all Teams share the SES account's reputation. For a high-volume
product, in the AWS SES console assign a **dedicated IP pool** to that Team's
configuration set. Consider SES **Virtual Deliverability Manager** (VDM) for
inbox-placement dashboards. Keep transactional and any marketing/broadcast
sending on separate pools so a complaint spike can't sink transactional
delivery.

## 12. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `terraform apply` hangs on ACM | DNS validation not completing — confirm `route53_zone_id` is correct, or use `acm_certificate_arn` |
| Tasks cycle / fail health checks | Check CloudWatch log group `/ecs/usesend`. Common: bad `DATABASE_URL`, migrations failing, or DB SG not allowing ECS |
| SNS subscription never confirms | `https://<app_domain>/api/ses_callback` must be publicly reachable with a valid cert; check the ALB + cert are up |
| Can send to yourself but not others | SES still in sandbox — request production access |
| High bounce/complaint warnings | Verify per-domain DKIM/SPF/DMARC; clean lists; SES will throttle if thresholds are exceeded |
| Login fails | GitHub OAuth callback URL must exactly match `https://<app_domain>/api/auth/callback/github` |

## 13. Cost controls

- Non-prod: `db_multi_az=false`, `nat_per_az=false`, smaller instance classes.
- One NAT gateway instead of two (default) saves ~$32/mo.
- Fargate scales to `min_capacity`; drop `app_desired_count` to 1 for staging.
