# useSend MCP server

An [MCP](https://modelcontextprotocol.io) server that exposes the useSend REST
API as tools, so AI agents (Claude Code, Claude Desktop, Cursor, …) can send
transactional email and manage domains, contacts, campaigns, and analytics on an
EverJust useSend / Amazon SES instance.

## Build

```bash
cd mcp
npm install
npm run build      # compiles src/ → dist/
```

## Configure

Two environment variables:

| Var | Required | Default | For the EverJust instance |
|-----|----------|---------|---------------------------|
| `USESEND_API_KEY` | yes | — | a useSend API key (`us_…`) from a Team's **Developer settings** |
| `USESEND_BASE_URL` | no | `https://app.usesend.com/api/v1` | `https://mail.everjust.app/api/v1` |

> The API key grants send access for its Team — scope one key per product and
> keep it in the environment. Never commit it.

## Run

```bash
USESEND_API_KEY=us_xxx USESEND_BASE_URL=https://mail.everjust.app/api/v1 node dist/index.js
```

## Add to an MCP client

Claude Desktop (`claude_desktop_config.json`) or Claude Code (`.mcp.json`):

```json
{
  "mcpServers": {
    "usesend": {
      "command": "node",
      "args": ["/absolute/path/to/usesend-email/mcp/dist/index.js"],
      "env": {
        "USESEND_API_KEY": "us_xxx",
        "USESEND_BASE_URL": "https://mail.everjust.app/api/v1"
      }
    }
  }
}
```

Then ask your agent things like *"send a receipt from EverJust
<hello@send.everjust.app> to success@simulator.amazonses.com"* or *"what's our
bounce rate this week?"*.

## Tools

| Group | Tools |
|-------|-------|
| Emails | `send_email`, `send_batch`, `get_email`, `list_emails`, `reschedule_email`, `cancel_email` |
| Domains | `create_domain`, `list_domains`, `get_domain`, `verify_domain`, `delete_domain` |
| Contact books | `create_contact_book`, `list_contact_books`, `get_contact_book`, `update_contact_book`, `delete_contact_book` |
| Contacts | `create_contact`, `list_contacts`, `get_contact`, `update_contact`, `upsert_contact`, `delete_contact`, `bulk_add_contacts`, `bulk_delete_contacts` |
| Campaigns | `create_campaign`, `list_campaigns`, `get_campaign`, `delete_campaign`, `schedule_campaign`, `pause_campaign`, `resume_campaign` |
| Analytics | `analytics_time_series`, `analytics_reputation` |

Templates, suppressions, and webhook configuration are managed in the useSend
dashboard (not exposed by the REST API), so they're intentionally not tools here.

See the full docs at [`/docs/mcp`](../docs/content/docs/mcp.mdx).
