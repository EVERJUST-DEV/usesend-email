# Phase 4 — cross-tenant isolation tests (GATING)

useSend is beta, isolation is enforced in the application layer (no database
row-level security), and the changelog shows past fixes that "enforce team
scoping." **Do not co-host unrelated commercial products on one deployment until
these pass.** Re-run after every useSend version bump.

Setup: create two throwaway Teams, **A** and **B**, each with its own domain and
an API key (`KEY_A`, `KEY_B`). Every check below must **fail closed** — Team A's
key must never touch Team B's data.

```bash
BASE=https://<app_domain>
KEY_A=us_...   # Team A
KEY_B=us_...   # Team B
```

## Checks

1. **Cannot send as another team's domain.** With `KEY_A`, try to send `from:`
   a Team B domain. Expect rejection (not accepted/queued).
   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' -X POST $BASE/api/v1/emails \
     -H "Authorization: Bearer $KEY_A" -H 'Content-Type: application/json' \
     -d '{"from":"noreply@<TEAM_B_DOMAIN>","to":"test@example.com","subject":"x","text":"x"}'
   # expect 4xx, NOT 200/201
   ```

2. **Cannot read another team's email logs / message by ID.** Capture a message
   ID created by `KEY_B`, then try to GET it with `KEY_A`.
   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' $BASE/api/v1/emails/<B_MESSAGE_ID> \
     -H "Authorization: Bearer $KEY_A"      # expect 403/404, NOT 200
   ```
   Increment/decrement the ID (IDOR probe) and confirm no Team B data leaks.

3. **Cannot list another team's domains.** `KEY_A` listing domains must return
   only Team A's, never Team B's.

4. **Cannot read/modify another team's templates, contacts, contact books, or
   webhooks.** Repeat the GET/PUT/DELETE probes across each resource type.

5. **Suppression lists are team-scoped.** A suppressed address in Team B must not
   suppress or appear for Team A, and vice versa.

6. **API key revocation is immediate and scoped.** Revoke `KEY_A`; confirm it
   stops working and `KEY_B` is unaffected.

7. **Dashboard cross-team access.** Log in as a Team A member; confirm the UI
   exposes no Team B domains, logs, keys, or contacts.

## Pass criteria

Every probe returns an authorization failure (4xx) or an empty/own-team result.
Any `200` that returns another team's data, or any accepted cross-team send, is a
**blocker** — pin to a known-good version, file upstream, and keep unrelated
products on separate deployments/AWS accounts until resolved.

## Hardening regardless of results

- Pin `usesend_image` to a specific version tag (never `:latest` in prod).
- Run a dependency/image scan (e.g. `trivy image usesend/usesend:<tag>`).
- Keep high-compliance products on their own deployment/account (silo) if any
  probe is marginal.
