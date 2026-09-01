import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="text-[15px] font-extrabold tracking-tight">
          useSend
          <span className="ml-1.5 rounded bg-fd-accent px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-fd-muted-foreground align-middle">
            EverJust
          </span>
        </span>
      ),
      url: '/',
    },
    links: [
      {
        type: 'custom',
        on: 'nav',
        children: (
          <a
            href="https://mail.everjust.app"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden md:inline-flex items-center justify-center rounded-full border border-fd-border bg-fd-background px-3.5 py-1 text-[11px] font-bold tracking-wider text-fd-foreground transition-colors hover:bg-fd-accent"
          >
            DASHBOARD
          </a>
        ),
      },
      {
        type: 'custom',
        on: 'nav',
        children: (
          <a
            href="https://github.com/EVERJUST-DEV/usesend-email"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden md:inline-flex items-center justify-center rounded-full bg-fd-foreground px-3.5 py-1 text-[11px] font-bold tracking-wider text-fd-background transition-opacity hover:opacity-80"
          >
            GITHUB
          </a>
        ),
      },
    ],
  };
}
