#!/usr/bin/env node
// useSend MCP server — exposes the useSend REST API as MCP tools so AI agents
// (Claude Code/Desktop, Cursor, etc.) can send transactional email and manage
// domains, contacts, campaigns, and analytics.
//
// Config (env):
//   USESEND_API_KEY   required — a useSend API key (us_...)
//   USESEND_BASE_URL  default cloud; for the EverJust instance:
//                     https://mail.everjust.app/api/v1
//
// Transport: stdio. All logging goes to stderr (stdout carries MCP frames).

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { usReq } from './client.js';

const server = new McpServer({ name: 'usesend', version: '1.0.0' });

type Handler = (args: any) => Promise<unknown>;

function register(name: string, description: string, shape: z.ZodRawShape, fn: Handler) {
  server.tool(name, description, shape, async (args: any) => {
    try {
      const data = await fn(args);
      const text = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
      return { content: [{ type: 'text' as const, text }] };
    } catch (e) {
      return {
        content: [{ type: 'text' as const, text: `Error: ${(e as Error).message}` }],
        isError: true,
      };
    }
  });
}

const strOrArr = z.union([z.string(), z.array(z.string())]);

// Shared shape for an email object (used by send_email + send_batch).
const emailFields = {
  to: strOrArr.describe('Recipient address(es)'),
  from: z.string().describe('Sender, e.g. "EverJust <hello@send.everjust.app>"'),
  subject: z.string().optional().describe('Required unless templateId is set'),
  html: z.string().optional(),
  text: z.string().optional(),
  cc: strOrArr.optional(),
  bcc: strOrArr.optional(),
  replyTo: strOrArr.optional(),
  headers: z.record(z.string()).optional().describe('Custom email headers'),
  templateId: z.string().optional(),
  variables: z.record(z.string()).optional().describe('Template variable substitutions'),
  scheduledAt: z.string().optional().describe('ISO-8601 with offset'),
  inReplyToId: z.string().optional().describe('Thread a reply to a prior email id'),
  attachments: z
    .array(z.object({ filename: z.string(), content: z.string().describe('base64') }))
    .max(10)
    .optional(),
};
const emailObject = z.object(emailFields);

// ---------------- Emails ----------------
register(
  'send_email',
  'Send a single transactional email. Provide subject or templateId, and html or text.',
  { ...emailFields, idempotencyKey: z.string().optional() },
  ({ idempotencyKey, ...body }) =>
    usReq('POST', '/emails', {
      body,
      headers: idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : undefined,
    }),
);

register(
  'send_batch',
  'Send a batch of emails (up to 100) in one request.',
  { emails: z.array(emailObject).max(100), idempotencyKey: z.string().optional() },
  ({ emails, idempotencyKey }) =>
    usReq('POST', '/emails/batch', {
      body: emails,
      headers: idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : undefined,
    }),
);

register('get_email', 'Get an email and its delivery events by id.', { emailId: z.string() }, ({ emailId }) =>
  usReq('GET', `/emails/${encodeURIComponent(emailId)}`),
);

register(
  'list_emails',
  'List emails (paginated).',
  {
    page: z.number().optional(),
    limit: z.number().optional(),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
    domainId: z.string().optional(),
  },
  (q) => usReq('GET', '/emails', { query: q }),
);

register(
  'reschedule_email',
  'Reschedule a scheduled email.',
  { emailId: z.string(), scheduledAt: z.string().describe('ISO-8601 with offset') },
  ({ emailId, scheduledAt }) =>
    usReq('PATCH', `/emails/${encodeURIComponent(emailId)}`, { body: { scheduledAt } }),
);

register('cancel_email', 'Cancel a scheduled email.', { emailId: z.string() }, ({ emailId }) =>
  usReq('POST', `/emails/${encodeURIComponent(emailId)}/cancel`),
);

// ---------------- Domains ----------------
register(
  'create_domain',
  'Add a sending domain (region must match the instance SES settings, e.g. us-east-1). Returns DNS records to publish.',
  { name: z.string(), region: z.string() },
  (body) => usReq('POST', '/domains', { body }),
);
register('list_domains', 'List sending domains.', {}, () => usReq('GET', '/domains'));
register('get_domain', 'Get a domain (and its DNS records) by numeric id.', { id: z.number() }, ({ id }) =>
  usReq('GET', `/domains/${id}`),
);
register('verify_domain', 'Trigger re-verification of a domain by numeric id.', { id: z.number() }, ({ id }) =>
  usReq('PUT', `/domains/${id}/verify`),
);
register('delete_domain', 'Delete a domain by numeric id.', { id: z.number() }, ({ id }) =>
  usReq('DELETE', `/domains/${id}`),
);

// ---------------- Contact books ----------------
const contactBookFields = {
  name: z.string(),
  emoji: z.string().optional(),
  properties: z.record(z.string()).optional(),
  doubleOptInEnabled: z.boolean().optional(),
  doubleOptInFrom: z.string().optional(),
  doubleOptInSubject: z.string().optional(),
  doubleOptInContent: z.string().optional(),
  variables: z.array(z.string()).optional(),
};
register('create_contact_book', 'Create a contact book (audience list).', contactBookFields, (body) =>
  usReq('POST', '/contactBooks', { body }),
);
register('list_contact_books', 'List contact books.', {}, () => usReq('GET', '/contactBooks'));
register('get_contact_book', 'Get a contact book by id.', { contactBookId: z.string() }, ({ contactBookId }) =>
  usReq('GET', `/contactBooks/${encodeURIComponent(contactBookId)}`),
);
register(
  'update_contact_book',
  'Update a contact book (all fields optional).',
  { contactBookId: z.string(), name: z.string().optional(), emoji: z.string().optional(), properties: z.record(z.string()).optional(), variables: z.array(z.string()).optional() },
  ({ contactBookId, ...body }) =>
    usReq('PATCH', `/contactBooks/${encodeURIComponent(contactBookId)}`, { body }),
);
register('delete_contact_book', 'Delete a contact book by id.', { contactBookId: z.string() }, ({ contactBookId }) =>
  usReq('DELETE', `/contactBooks/${encodeURIComponent(contactBookId)}`),
);

// ---------------- Contacts ----------------
const contactBody = {
  email: z.string(),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  properties: z.record(z.string()).optional(),
  subscribed: z.boolean().optional(),
};
register(
  'create_contact',
  'Create a contact in a contact book.',
  { contactBookId: z.string(), ...contactBody },
  ({ contactBookId, ...body }) =>
    usReq('POST', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts`, { body }),
);
register(
  'list_contacts',
  'List contacts in a contact book.',
  {
    contactBookId: z.string(),
    emails: z.string().optional().describe('comma-separated'),
    ids: z.string().optional().describe('comma-separated'),
    page: z.number().optional(),
    limit: z.number().optional(),
  },
  ({ contactBookId, ...query }) =>
    usReq('GET', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts`, { query }),
);
register(
  'get_contact',
  'Get a contact by id.',
  { contactBookId: z.string(), contactId: z.string() },
  ({ contactBookId, contactId }) =>
    usReq('GET', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts/${encodeURIComponent(contactId)}`),
);
register(
  'update_contact',
  'Partially update a contact (no email change).',
  { contactBookId: z.string(), contactId: z.string(), firstName: z.string().optional(), lastName: z.string().optional(), properties: z.record(z.string()).optional(), subscribed: z.boolean().optional() },
  ({ contactBookId, contactId, ...body }) =>
    usReq('PATCH', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts/${encodeURIComponent(contactId)}`, { body }),
);
register(
  'upsert_contact',
  'Create or update a contact by id (email required).',
  { contactBookId: z.string(), contactId: z.string(), ...contactBody },
  ({ contactBookId, contactId, ...body }) =>
    usReq('PUT', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts/${encodeURIComponent(contactId)}`, { body }),
);
register(
  'delete_contact',
  'Delete a contact by id.',
  { contactBookId: z.string(), contactId: z.string() },
  ({ contactBookId, contactId }) =>
    usReq('DELETE', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts/${encodeURIComponent(contactId)}`),
);
register(
  'bulk_add_contacts',
  'Bulk add/upsert contacts in a contact book.',
  { contactBookId: z.string(), contacts: z.array(z.object(contactBody)) },
  ({ contactBookId, contacts }) =>
    usReq('POST', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts/bulk`, { body: contacts }),
);
register(
  'bulk_delete_contacts',
  'Bulk delete contacts by id.',
  { contactBookId: z.string(), contactIds: z.array(z.string()) },
  ({ contactBookId, contactIds }) =>
    usReq('DELETE', `/contactBooks/${encodeURIComponent(contactBookId)}/contacts/bulk`, { body: { contactIds } }),
);

// ---------------- Campaigns (broadcasts) ----------------
register(
  'create_campaign',
  'Create a campaign (broadcast) to a contact book.',
  {
    name: z.string(),
    from: z.string(),
    subject: z.string(),
    contactBookId: z.string(),
    previewText: z.string().optional(),
    content: z.string().optional(),
    html: z.string().optional(),
    replyTo: strOrArr.optional(),
    cc: strOrArr.optional(),
    bcc: strOrArr.optional(),
    sendNow: z.boolean().optional(),
    scheduledAt: z.string().optional().describe('ISO-8601 or natural language e.g. "tomorrow 9am"'),
    batchSize: z.number().optional(),
  },
  (body) => usReq('POST', '/campaigns', { body }),
);
register(
  'list_campaigns',
  'List campaigns.',
  { page: z.number().optional(), status: z.enum(['DRAFT', 'SCHEDULED', 'RUNNING', 'PAUSED', 'SENT']).optional(), search: z.string().optional() },
  (query) => usReq('GET', '/campaigns', { query }),
);
register('get_campaign', 'Get a campaign by id.', { campaignId: z.string() }, ({ campaignId }) =>
  usReq('GET', `/campaigns/${encodeURIComponent(campaignId)}`),
);
register('delete_campaign', 'Delete a campaign by id.', { campaignId: z.string() }, ({ campaignId }) =>
  usReq('DELETE', `/campaigns/${encodeURIComponent(campaignId)}`),
);
register(
  'schedule_campaign',
  'Schedule (or send now) a campaign.',
  { campaignId: z.string(), scheduledAt: z.string().optional(), batchSize: z.number().optional() },
  ({ campaignId, ...body }) =>
    usReq('POST', `/campaigns/${encodeURIComponent(campaignId)}/schedule`, { body }),
);
register('pause_campaign', 'Pause a running campaign.', { campaignId: z.string() }, ({ campaignId }) =>
  usReq('POST', `/campaigns/${encodeURIComponent(campaignId)}/pause`),
);
register('resume_campaign', 'Resume a paused campaign.', { campaignId: z.string() }, ({ campaignId }) =>
  usReq('POST', `/campaigns/${encodeURIComponent(campaignId)}/resume`),
);

// ---------------- Analytics ----------------
register(
  'analytics_time_series',
  'Email metrics over time (sent/delivered/opened/clicked/bounced/complained).',
  { days: z.enum(['7', '30']).optional(), domainId: z.string().optional() },
  (query) => usReq('GET', '/analytics/email-time-series', { query }),
);
register(
  'analytics_reputation',
  'Reputation metrics: bounce rate and complaint rate.',
  { domainId: z.string().optional() },
  (query) => usReq('GET', '/analytics/reputation-metrics', { query }),
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('useSend MCP server running on stdio');
}

main().catch((e) => {
  console.error('Fatal:', e);
  process.exit(1);
});
