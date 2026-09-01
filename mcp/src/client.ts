// Thin HTTP client for the useSend REST API (v1). Reads credentials from env so
// the API key is never hard-coded: USESEND_API_KEY (required) and USESEND_BASE_URL
// (default cloud; for the EverJust instance set https://mail.everjust.app/api/v1).

export interface UseSendConfig {
  apiKey: string;
  baseUrl: string;
}

export function getConfig(): UseSendConfig {
  const apiKey = process.env.USESEND_API_KEY ?? process.env.UNSEND_API_KEY;
  if (!apiKey) {
    throw new Error(
      'USESEND_API_KEY is not set. Provide a useSend API key (us_...) via the environment.',
    );
  }
  let baseUrl =
    process.env.USESEND_BASE_URL ??
    process.env.UNSEND_BASE_URL ??
    'https://app.usesend.com/api/v1';
  baseUrl = baseUrl.replace(/\/+$/, '');
  // Be forgiving if someone passes the instance root without /api/v1.
  if (!/\/api\/v\d+$/.test(baseUrl)) {
    if (/\/api$/.test(baseUrl)) baseUrl += '/v1';
    else baseUrl += '/api/v1';
  }
  return { apiKey, baseUrl };
}

type Query = Record<string, string | number | boolean | undefined | null>;

export interface RequestOptions {
  query?: Query;
  body?: unknown;
  headers?: Record<string, string>;
}

export async function usReq(
  method: string,
  path: string,
  opts: RequestOptions = {},
): Promise<unknown> {
  const { apiKey, baseUrl } = getConfig();
  const url = new URL(baseUrl + path);
  if (opts.query) {
    for (const [k, v] of Object.entries(opts.query)) {
      if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, String(v));
    }
  }

  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      ...(opts.headers ?? {}),
    },
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });

  const raw = await res.text();
  let data: any;
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = { raw };
  }

  if (!res.ok) {
    const code = data?.error?.code ? `${data.error.code} ` : '';
    const msg = data?.error?.message ?? res.statusText;
    throw new Error(`useSend ${res.status} ${code}- ${msg}`);
  }
  return data;
}
