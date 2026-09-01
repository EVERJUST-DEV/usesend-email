# usesend-email

Self-hosted, **multi-tenant transactional email** on AWS — a replacement for
Resend that costs **$0 per sending domain**. One [useSend](https://github.com/usesend/useSend)
deployment, one **Team** per product, unlimited sending domains, delivered
through **Amazon SES** (which bills per email, never per domain).

This repo is the infrastructure to run it: Terraform for the AWS stack, a local
docker-compose for evaluation, and runbooks for the manual AWS steps.

> **Why useSend?** See the decision brief that led here:
> [Resend Exit Plan](https://claude.ai/code/artifact/20362363-00e4-4a7d-91b0-90fb0e5e6f26).
> Short version: it's the only OSS option that is SES-backed (free domains),
> genuinely multi-tenant in the self-hosted build (Team-scoped), and close to a
> drop-in Resend migration.

## Layout

```
usesend-email/
├── docker-compose.yml        # local evaluation (Postgres + Redis + useSend)
├── .env.example              # local env template
├── terraform/                # the AWS stack (see below)
│   ├── vpc.tf security.tf rds.tf elasticache.tf
│   ├── alb.tf ecs.tf iam.tf secrets.tf
│   ├── variables.tf outputs.tf versions.tf
│   └── terraform.tfvars.example
├── mcp/                      # useSend MCP server — agents send mail via MCP
├── scripts/
│   └── add-tenant-dns.sh     # publish a product's DKIM/SPF/DMARC into Route 53
├── docs/                     # Fumadocs docs site → GitHub Pages (auto-deployed)
│   └── content/docs/*.mdx    # overview, quickstart, API, webhooks, MCP, ops, …
└── .github/workflows/docs.yml
```

## Documentation

Full product docs live in [`docs/`](docs/content/docs/) (a Fumadocs site) and are
built + deployed to **GitHub Pages** by [`.github/workflows/docs.yml`](.github/workflows/docs.yml)
on every push that touches `docs/` — so they stay in sync with the repo. The
[`mcp/`](mcp/) directory is a Model Context Protocol server that lets AI agents
send mail and manage the account; see [`docs/content/docs/mcp.mdx`](docs/content/docs/mcp.mdx)
and [`mcp/README.md`](mcp/README.md). A machine-readable index for agents is at
[`docs/public/llms.txt`](docs/public/llms.txt).

> Private-repo GitHub Pages needs a paid plan. Until it's enabled, the workflow's
> **build** job still validates the docs on every push; read the pages as MDX in
> `docs/content/docs/`, or run the site locally (`cd docs && npm install && npm run dev`).

## What gets provisioned (AWS)

| Layer | Resource |
|-------|----------|
| Network | VPC, 2 public + 2 private subnets, IGW (Fargate egresses via public IP — no NAT gateway, since the account was at its Elastic IP cap; inbound still locked to the ALB by security group) |
| Compute | ECS Fargate cluster + 1 service (single useSend container; workers run in-process) |
| Ingress | Application Load Balancer + ACM TLS cert, HTTP→HTTPS redirect |
| Data | RDS PostgreSQL 16 (Multi-AZ), ElastiCache Redis 7 |
| Secrets | Secrets Manager: DB URL, Redis URL, auth secret, GitHub secret |
| Identity | ECS task role with SES + SNS access (no static AWS keys) |
| DNS/TLS | Route 53 records + ACM DNS validation (optional; or bring your own cert) |
| Delivery | Amazon SES — configuration sets + SNS wiring are created **by useSend at runtime**, not Terraform |

**Rough cost floor:** the shipped `terraform.tfvars` is cost-optimized
(single-AZ RDS, one Fargate task, no NAT) at ~**$65–80/month** — Fargate + RDS +
Redis + ALB — plus SES at ~$0.10 per 1,000 emails. Domains are free. Set
`db_multi_az=true` and raise `app_desired_count` for a production HA posture.

---

## Option A — try it locally first (5 minutes)

Needs Docker.

```bash
cp .env.example .env
# set NEXTAUTH_SECRET (openssl rand -base64 33) and a GitHub OAuth app's ID/secret
docker compose up -d
open http://localhost:3000
```

You can explore the whole dashboard without AWS. To actually send, add an IAM
user's keys (`AWS_ACCESS_KEY_ID`/`SECRET`) to `.env` and take SES out of sandbox.

## Option B — deploy to AWS

Needs: `terraform` ≥ 1.5, `aws` CLI (configured), a domain in a **Route 53
hosted zone**, and a **GitHub OAuth App**.

**1. Start the slow thing first — SES production access.** It's human-reviewed
(24–48h). AWS console → SES → *Account dashboard* → **Request production
access**, and request a sending-quota increase. Details in
[`docs/content/docs/operations.mdx`](docs/content/docs/operations.mdx).

**2. Create a GitHub OAuth App** (self-host login). Callback URL:
`https://<app_domain>/api/auth/callback/github`. Keep the client ID + secret.

**3. Configure and apply.**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit: app_domain, route53_zone_id, github_client_id
export TF_VAR_github_client_secret='...'      # keep the secret out of the file
terraform init
terraform plan
terraform apply
```

**4. Point DNS + finish setup.** If Terraform manages your zone
(`route53_zone_id` set), the app record and cert validation are automatic —
otherwise create a record for `app_domain` → the `alb_dns_name` output. Then:
- Open `https://<app_domain>`, sign in with GitHub.
- In the admin UI, configure SES: region + the **callback URL** from the
  `ses_callback_url` output (`https://<app_domain>/api/ses_callback`). useSend
  creates the SES configuration set + SNS subscription for you.

**5. Onboard your products.** One Team + domain(s) + API key per product —
see [`docs/content/docs/onboard-a-product.mdx`](docs/content/docs/onboard-a-product.mdx).

**6. Before co-hosting unrelated products,** run the cross-tenant isolation
tests — [`docs/content/docs/tenant-isolation.mdx`](docs/content/docs/tenant-isolation.mdx). This is a gate,
not optional: useSend is beta and isolation is app-layer.

---

## Migrating off Resend

useSend's send payload mirrors Resend's (`from`/`to`/`subject`/`html`/`text`/
`headers`), so per product: point the SDK's base URL at `https://<app_domain>`,
swap the API key for the `us_` Team key, port templates to React Email, and
shadow-send against Resend before cutover. Keep Resend as a hot fallback until
each product's deliverability looks good.

## Known boundaries (read before production)

- **AGPL-3.0.** Running the stock image is fine. If you *modify* useSend and
  expose it over the network, the license obligates you to publish the source.
  Get legal sign-off before forking. (Postal is the MIT alternative if this is a
  dealbreaker — see the decision brief.)
- **Beta + app-layer isolation.** Pin `usesend_image` to a version tag (not
  `:latest`) and run `docs/content/docs/tenant-isolation.mdx` after every upgrade.
- **Shared SES reputation by default.** All Teams share the SES account's
  quota/reputation until you give high-volume products their own SES
  configuration set + dedicated IP pool.
- **Login is OAuth (GitHub/Google) or email magic-link** — no enterprise SSO out
  of the box.
- **Object storage is optional** and only powers editor image uploads; it is not
  provisioned by default. See "Object storage (optional)" in the runbook if you
  want it (note: useSend's S3 client hardcodes `region:"auto"`, so real AWS S3
  needs a source patch or an R2/MinIO backend).
