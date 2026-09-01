import Link from 'next/link';
import { HomeLayout } from 'fumadocs-ui/layouts/home';
import { baseOptions } from '@/lib/layout.shared';

const QUICK = [
  { title: 'Quickstart', desc: 'Send your first email in five minutes.', href: '/docs/quickstart' },
  { title: 'Onboard a product', desc: 'Add a tenant, verify a domain, mint a key.', href: '/docs/onboard-a-product' },
  { title: 'API reference', desc: 'Every endpoint, field, and response.', href: '/docs/api' },
  { title: 'Migrate from Resend', desc: 'Swap the SDK, keep your templates.', href: '/docs/migrate-from-resend' },
  { title: 'MCP server', desc: 'Let AI agents send mail via MCP.', href: '/docs/mcp' },
  { title: 'Architecture', desc: 'How it runs on AWS SES.', href: '/docs/architecture' },
];

export default function Home() {
  return (
    <HomeLayout {...baseOptions()}>
      <section className="border-b border-fd-border">
        <div className="mx-auto max-w-5xl px-6 py-20 lg:py-28">
          <p className="ca-eyebrow mb-5">Self-hosted transactional email · EverJust</p>
          <h1 className="ca-display max-w-3xl text-[40px] font-extrabold leading-[1.05] tracking-tight text-fd-foreground sm:text-[56px]">
            Product email that costs nothing per domain.
          </h1>
          <p className="mt-6 max-w-2xl text-[17px] text-fd-muted-foreground" style={{ lineHeight: 1.7 }}>
            useSend runs on your own AWS account over Amazon SES — one deployment, one tenant per
            product, unlimited sending domains, billed only per email. These docs cover onboarding a
            product, the full REST API, webhooks, SMTP, migrating from Resend, and the MCP server for
            AI agents.
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Link
              href="/docs/quickstart"
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-fd-foreground px-7 py-3.5 text-[15px] font-semibold text-fd-background transition-opacity hover:opacity-90"
            >
              Quickstart →
            </Link>
            <Link
              href="/docs"
              className="inline-flex items-center justify-center rounded-xl border border-fd-border px-7 py-3.5 text-[15px] font-semibold text-fd-foreground transition-colors hover:bg-fd-accent"
            >
              Browse the docs
            </Link>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-6 py-16">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {QUICK.map((c) => (
            <Link
              key={c.href}
              href={c.href}
              className="group rounded-2xl border border-fd-border bg-fd-card p-6 transition-all hover:-translate-y-0.5 hover:border-fd-foreground/20"
            >
              <p className="text-[15px] font-bold tracking-tight text-fd-foreground">{c.title}</p>
              <p className="mt-1.5 text-[13px] text-fd-muted-foreground" style={{ lineHeight: 1.6 }}>
                {c.desc}
              </p>
              <p className="mt-4 text-[13px] font-semibold text-fd-foreground">Read →</p>
            </Link>
          ))}
        </div>
      </section>
    </HomeLayout>
  );
}
