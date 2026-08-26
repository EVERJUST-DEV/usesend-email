#!/usr/bin/env bash
# =============================================================================
# add-tenant-dns.sh
#
# When you add a product's sending domain in the useSend admin UI, useSend
# creates the SES identity for you and shows the DNS records you must publish
# (DKIM CNAMEs, SPF TXT, a custom MAIL FROM MX/TXT, and a DMARC TXT). This
# script publishes those records into a Route 53 hosted zone in one shot.
#
# Usage:
#   ./add-tenant-dns.sh <hosted_zone_id> <records.json>
#
# records.json format (copy the values useSend shows you):
#   [
#     { "name": "resend._domainkey.mail.acme.com", "type": "CNAME",
#       "value": "xxxx.dkim.amazonses.com", "ttl": 300 },
#     { "name": "mail.acme.com", "type": "TXT",
#       "value": "\"v=spf1 include:amazonses.com ~all\"", "ttl": 300 },
#     { "name": "_dmarc.mail.acme.com", "type": "TXT",
#       "value": "\"v=DMARC1; p=quarantine; rua=mailto:dmarc@acme.com\"", "ttl": 300 }
#   ]
#
# Requires: aws CLI (configured), jq.
# =============================================================================
set -euo pipefail

ZONE_ID="${1:?usage: add-tenant-dns.sh <hosted_zone_id> <records.json>}"
RECORDS_FILE="${2:?usage: add-tenant-dns.sh <hosted_zone_id> <records.json>}"

command -v aws >/dev/null || { echo "aws CLI not found" >&2; exit 1; }
command -v jq  >/dev/null || { echo "jq not found" >&2; exit 1; }
[ -f "$RECORDS_FILE" ] || { echo "records file not found: $RECORDS_FILE" >&2; exit 1; }

# Build a Route53 change batch (UPSERT) from the records JSON.
CHANGE_BATCH=$(jq '{
  Comment: "useSend tenant sending domain",
  Changes: [ .[] | {
    Action: "UPSERT",
    ResourceRecordSet: {
      Name: .name,
      Type: .type,
      TTL: (.ttl // 300),
      ResourceRecords: [ { Value: .value } ]
    }
  } ]
}' "$RECORDS_FILE")

echo "About to UPSERT $(jq 'length' "$RECORDS_FILE") record(s) into zone $ZONE_ID:"
jq -r '.[] | "  \(.type)  \(.name)  ->  \(.value)"' "$RECORDS_FILE"
read -r -p "Proceed? [y/N] " ok
[ "$ok" = "y" ] || { echo "aborted"; exit 0; }

CHANGE_ID=$(aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "$CHANGE_BATCH" \
  --query 'ChangeInfo.Id' --output text)

echo "Submitted change $CHANGE_ID. Waiting for INSYNC..."
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"
echo "Done. Now click 'Verify' on the domain in the useSend dashboard (DKIM can take a few minutes)."
