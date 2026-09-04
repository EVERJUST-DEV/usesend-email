# useSend for EVERJUST

Self-hosted, multi-tenant transactional email on Amazon SES — one deployment for every product, $0 per sending domain.

**Status:** Production · deployed 2026-09-02 · public

[![docs](https://img.shields.io/github/actions/workflow/status/EVERJUST-DEV/usesend-email/docs.yml?style=flat&color=1D1D1F&label=docs)](https://github.com/EVERJUST-DEV/usesend-email/actions/workflows/docs.yml)
[![live](https://img.shields.io/badge/live-mail.everjust.app-1D1D1F?style=flat)](https://mail.everjust.app)

[Dashboard](https://mail.everjust.app) · [Docs](https://mail.everjust.app/docs/) · [Docs mirror](https://everjust-dev.github.io/usesend-email/) · [by EVERJUST](https://everjust.app)

|  |  |
|---|---|
| **What it is** | Infrastructure to run [useSend](https://github.com/usesend/useSend) on your own AWS account |
| **Who it's for** | Teams sending transactional email from many domains on one bill |
| **Live at** | [mail.everjust.app](https://mail.everjust.app) · API `mail.everjust.app/api/v1` · [docs](https://mail.everjust.app/docs/) |
| **Stack** | Terraform · ECS Fargate · RDS PostgreSQL 16 · ElastiCache Redis 7 · ALB + ACM · Amazon SES |
| **Status** | Production · one deployment, `send.everjust.app` verified (DKIM, SPF, DMARC, MAIL FROM) · SES sandbox pending review |

This repository is the infrastructure — not the application. It provisions and operates one
useSend deployment that every EVERJUST product sends through, replacing Resend. Terraform builds
the AWS stack, a docker-compose file runs the same thing locally for evaluation, an MCP server
lets agents send mail, and a Fumadocs site documents all of it.

## The problem

Hosted transactional email is priced per sending domain. Every product you launch, every
white-label customer who brings their own domain, adds a line to the bill before it sends a
single message. For a portfolio of products with per-tenant domains, the domain count grows
faster than the volume does.

Amazon SES bills per email — roughly $0.10 per thousand — and never per domain. useSend is the
open-source dashboard and API on top of it, and it is genuinely multi-tenant in the self-hosted
build: a **Team** is a tenant, owning its own sending domains and its own API keys. One
deployment, one Team per product, unlimited domains.

The catch is that nobody hands you the AWS stack. That is what this repository is: a VPC, a
Fargate service, Postgres, Redis, an ALB with TLS, the IAM to reach SES without static keys, and
the runbooks for the manual steps AWS makes you do by hand.

## Quickstart

Evaluate the whole dashboard locally in about five minutes. Needs Docker.

```bash
cp .env.example .env
# set NEXTAUTH_SECRET (openssl rand -base64 33) and a GitHub OAuth app's ID + secret
docker compose up -d
open http://localhost:3000
```

That gets you the UI with no AWS at all. To deploy for real, you need `terraform` ≥ 1.5, a
configured `aws` CLI, a Route 53 hosted zone and a GitHub OAuth App — then:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set app_domain, route53_zone_id, github_client_id
export TF_VAR_github_client_secret='...'       # keep the secret out of the file
terraform init && terraform plan && terraform apply
```

Start the **SES production-access request first** — it is human-reviewed and takes 24–48 hours.
Full sequence in [`docs/content/docs/operations.mdx`](docs/content/docs/operations.mdx).

## What it does

- **Provisions the stack** — VPC across two AZs, ECS Fargate, RDS PostgreSQL 16, ElastiCache
  Redis 7, ALB with an ACM certificate, Secrets Manager, and Route 53 records.
- **Reaches SES without static credentials** — the ECS task role carries the SES and SNS
  permissions; no access keys are stored anywhere in the stack.
- **Onboards a product per Team** — one Team, its domains, one API key, DNS published by
  [`scripts/add-tenant-dns.sh`](scripts/add-tenant-dns.sh).
- **Lets agents send mail** — [`mcp/`](mcp/) is an [MCP](https://modelcontextprotocol.io) server
  exposing the useSend API as tools for Claude Code, Claude Desktop and Cursor.
- **Publishes its own documentation** — [`docs/`](docs/content/docs/) is a Fumadocs site built and
  deployed by GitHub Actions on every push that touches it.
- **Migrates off Resend** — the send payload mirrors Resend's, so a product swaps a base URL and
  an API key. See [migrate-from-resend](docs/content/docs/migrate-from-resend.mdx).

## How it works

One deployment serves every product; tenancy is logical. Traffic hits the ALB on 443, terminates
TLS with an ACM certificate, and reaches a single Fargate task running the useSend container with
its BullMQ workers in-process. That task talks to RDS for application data, to Redis for the
queue, and outbound to the SES API to send. SES delivery events return over SNS to a callback the
app registers itself. The tasks run in public subnets with public-IP egress and no NAT gateway —
inbound is still closed to everything but the ALB security group.

### Repository layout

```text
.
├── terraform/               # the AWS stack: vpc, security, rds, elasticache, alb, ecs, iam, secrets
│   └── docs/                # standalone module (own state) for the /docs service
├── mcp/                     # useSend MCP server — TypeScript, builds to dist/
├── docs/                    # Fumadocs site; content in docs/content/docs/*.mdx
├── scripts/add-tenant-dns.sh  # publish a product's DKIM/SPF/DMARC into Route 53
├── docker-compose.yml       # local evaluation: Postgres + Redis + useSend
└── .github/workflows/       # docs.yml (build, push to ECR, deploy) · mcp.yml (type-check + build)
```

## Configuration

Local evaluation reads `.env` (template in `.env.example`); the AWS deployment sets the same
values from Terraform and Secrets Manager. Nothing below is committed.

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `NEXTAUTH_SECRET` | yes | — | Session signing. `openssl rand -base64 33`. |
| `DATABASE_URL` | yes | — | PostgreSQL connection. Terraform writes it to Secrets Manager in AWS. |
| `REDIS_URL` | yes | — | BullMQ queue backend. |
| `GITHUB_ID` / `GITHUB_SECRET` | yes | — | Dashboard login. At least one OAuth provider is required. |
| `USESEND_API_KEY` | yes (MCP) | — | A Team's `us_` key. One key per product; never commit it. |
| `USESEND_BASE_URL` | no | `https://app.usesend.com/api/v1` | Point at your own instance's `/api/v1`. |

Terraform inputs live in `terraform/variables.tf`; copy `terraform.tfvars.example` and set
`app_domain`, `route53_zone_id` and `github_client_id`. Pass `github_client_secret` through
`TF_VAR_github_client_secret`, never the file.

## Operations

Pushes to `main` that touch `docs/` or `terraform/docs/` build the docs image and roll the ECS
docs service, authenticating to AWS with GitHub OIDC — there are no long-lived deploy keys. Roll
back by re-running the workflow at the previous commit, or `terraform apply -var="docs_image_tag=<sha>"`.
Cost floor for the shipped cost-optimised `terraform.tfvars` is roughly **$65–80/month** plus SES
usage; set `db_multi_az = true` and raise `app_desired_count` for an HA posture.

## Known limitations

- **SES production access is still pending review.** Until AWS grants it, sending is restricted to
  verified addresses and the SES mailbox simulator. No code changes when it lands.
- **useSend is beta and isolation is app-layer.** Pin `usesend_image` to a version tag, never
  `:latest`, and run [tenant-isolation](docs/content/docs/tenant-isolation.mdx) after every upgrade
  — that is a gate before co-hosting unrelated products, not a suggestion.
- **Shared SES reputation by default.** All Teams share the account's quota and reputation until a
  high-volume product gets its own configuration set and dedicated IP pool.
- **Login is OAuth or email magic-link.** No enterprise SSO out of the box.
- The GitHub Pages mirror is a copy of the docs built for root mounting; its in-page navigation
  points at the canonical site. Read the docs at [mail.everjust.app/docs](https://mail.everjust.app/docs/).

## License

No `LICENSE` file is committed for the Terraform, MCP server and docs in this repository. The
application it deploys, [useSend](https://github.com/usesend/useSend), is **AGPL-3.0** — running
the stock image is fine, but modifying it and exposing it over a network obliges you to publish
the source. Get legal sign-off before forking.
