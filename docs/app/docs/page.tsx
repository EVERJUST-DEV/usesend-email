import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Documentation',
  description:
    'Run EverJust product email on useSend + AWS SES — onboarding, API, webhooks, SMTP, migration, operations, and MCP.',
};

const JOURNEY = [
  { step: '01', eyebrow: 'Start', title: 'Quickstart', desc: 'Authenticate and send your first email.', href: '/docs/quickstart' },
  { step: '02', eyebrow: 'Set up', title: 'Onboard a product', desc: 'Create a tenant, verify a sending domain, mint an API key.', href: '/docs/onboard-a-product' },
  { step: '03', eyebrow: 'Integrate', title: 'Send email (API & SDKs)', desc: 'The send endpoint, batch sends, attachments, scheduling.', href: '/docs/sending-email' },
  { step: '04', eyebrow: 'Operate', title: 'Webhooks & events', desc: 'React to delivered, bounced, complained, opened, clicked.', href: '/docs/webhooks' },
];

const TOPICS = [
  {
    category: 'Guides',
    links: [
      { label: 'Overview', href: '/docs' },
      { label: 'Quickstart', href: '/docs/quickstart' },
      { label: 'Onboard a product', href: '/docs/onboard-a-product' },
      { label: 'Migrate from Resend', href: '/docs/migrate-from-resend' },
      { label: 'SMTP relay', href: '/docs/smtp' },
    ],
  },
  {
    category: 'Reference',
    links: [
      { label: 'API reference', href: '/docs/api' },
      { label: 'Sending email', href: '/docs/sending-email' },
      { label: 'Domains', href: '/docs/domains' },
      { label: 'Contacts', href: '/docs/contacts' },
      { label: 'Webhooks', href: '/docs/webhooks' },
    ],
  },
  {
    category: 'AI & agents',
    links: [
      { label: 'MCP server', href: '/docs/mcp' },
      { label: 'Using useSend from agents', href: '/docs/ai-agents' },
      { label: 'llms.txt', href: '/llms.txt' },
    ],
  },
  {
    category: 'Platform',
    links: [
      { label: 'Architecture (AWS)', href: '/docs/architecture' },
      { label: 'Operations & runbook', href: '/docs/operations' },
      { label: 'Tenant isolation', href: '/docs/tenant-isolation' },
      { label: 'Troubleshooting', href: '/docs/troubleshooting' },
    ],
  },
];

export default function DocsHome() {
  return (
    <div className="mx-auto max-w-5xl px-6 py-14">
      <div className="mb-14">
        <p className="ca-eyebrow mb-4">Documentation</p>
        <h1 className="ca-display text-[36px] font-extrabold leading-[1.04] tracking-tight text-fd-foreground sm:text-[48px]">
          Run product email on useSend.
        </h1>
        <p className="mt-4 max-w-2xl text-[16px] text-fd-muted-foreground" style={{ lineHeight: 1.7 }}>
          Pick a path below, or jump to any topic in the sidebar. New here? Start at 01.
        </p>
      </div>

      <section className="mb-16">
        <h2 className="mb-6 text-[11px] font-bold uppercase tracking-[0.18em] text-fd-muted-foreground">Guided path</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          {JOURNEY.map((j) => (
            <Link
              key={j.step}
              href={j.href}
              className="group rounded-2xl border border-fd-border bg-fd-card p-6 transition-all hover:-translate-y-0.5 hover:border-fd-foreground/20"
            >
              <div className="mb-4 flex items-center gap-3">
                <span className="font-mono text-[11px] font-bold tracking-[0.18em] text-fd-muted-foreground">{j.step}</span>
                <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-fd-muted-foreground">{j.eyebrow}</span>
              </div>
              <h3 className="mb-2 text-[17px] font-bold tracking-tight text-fd-foreground">{j.title}</h3>
              <p className="text-[13px] text-fd-muted-foreground" style={{ lineHeight: 1.65 }}>{j.desc}</p>
            </Link>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-6 text-[11px] font-bold uppercase tracking-[0.18em] text-fd-muted-foreground">All topics</h2>
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {TOPICS.map((t) => (
            <div key={t.category}>
              <p className="mb-3 text-[12px] font-bold uppercase tracking-[0.14em] text-fd-foreground">{t.category}</p>
              <ul className="space-y-2">
                {t.links.map((l) => (
                  <li key={l.label}>
                    <Link href={l.href} className="text-[13px] text-fd-muted-foreground transition-colors hover:text-fd-foreground">
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
