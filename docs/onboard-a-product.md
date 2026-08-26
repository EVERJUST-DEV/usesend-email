# Onboarding a product (tenant)

In useSend the tenant boundary is a **Team**. Each of your software products gets
its own Team, its own API key(s), and its own sending domain(s). One deployment
holds many Teams. This is an **app-level** flow (the useSend UI/API creates the
SES identity, configuration set, and SNS subscription for you) — not Terraform.

> ⚠️ Isolation between Teams is enforced in the application layer and has had
> scoping bugs patched historically. Before you co-host **unrelated** products on
> one deployment, run `docs/isolation-tests.md`.

## One-time platform setup (before any product)

1. **SES out of sandbox.** In the AWS console → SES → *Account dashboard* →
   **Request production access**, and request a sending-quota increase. This is
   human-reviewed (usually 24–48h), so do it first. Sandbox only sends to
   verified addresses at ~200/day.
2. **Configure SES in the useSend admin UI.** Log in to
   `https://<app_domain>`, open the SES settings, enter your region
   (e.g. `us-east-1`) and the **callback URL** — this is the `ses_callback_url`
   Terraform output: `https://<app_domain>/api/ses_callback`. useSend validates
   it's reachable, then creates the SES configuration set and subscribes the SNS
   topic to that URL automatically.

## Per product

1. **Create the Team** in the dashboard (one per product, e.g. `acme-app`).
2. **Add the sending domain(s)** for that Team (e.g. `mail.acme.com`,
   `receipts.acme.com`). useSend creates the SES identity + DKIM and shows you
   the DNS records to publish (DKIM CNAMEs, SPF, a custom MAIL FROM, DMARC).
   A Team can hold **many** domains — this is the key advantage over one-domain
   tools.
3. **Publish the DNS records.** Save the records useSend shows into a JSON file
   and run:
   ```bash
   ./scripts/add-tenant-dns.sh <hosted_zone_id> records.json
   ```
   (or add them by hand in Route 53). Then click **Verify** in the dashboard.
4. **Mint an API key** scoped to that Team. Store it in that product's own secret
   manager. This key can only send as / read logs for this Team.
5. **Point the product at useSend.** Set the base URL to `https://<app_domain>`
   and use the `us_`-prefixed API key. The send payload mirrors Resend's shape
   (`from`/`to`/`subject`/`html`/`text`/`headers`), so the code change is small.
6. **(Optional) Reputation isolation.** For a high-volume product, give its SES
   configuration set a **dedicated IP pool** (AWS console → SES) so its bounces
   can't affect other products' deliverability.

## Deliverability checklist per domain

- [ ] DKIM verified (3 CNAMEs) — useSend shows green
- [ ] SPF TXT authorizes `amazonses.com`
- [ ] Custom MAIL FROM subdomain set (for DMARC SPF alignment)
- [ ] DMARC record present (start `p=none`, move to `p=quarantine`/`reject`)
- [ ] Test send scores well on mail-tester.com and Google Postmaster Tools
