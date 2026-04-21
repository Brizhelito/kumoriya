interface Env {}

const INVITE_HOST = "join.kumoriya.online";
const MARKETING_ORIGIN = "https://kumoriya.online";
const INVITE_CODE_RE = /^[A-Z0-9]{4,12}$/;

const ASSET_LINKS = [
  {
    relation: [
      "delegate_permission/common.get_login_creds",
      "delegate_permission/common.handle_all_urls",
    ],
    target: {
      namespace: "android_app",
      package_name: "dev.kumoriya.app",
      sha256_cert_fingerprints: [
        "E0:CE:93:F8:46:78:5F:67:67:32:14:B0:F3:96:1D:39:C6:5C:13:48:72:07:BF:6C:CD:FF:00:23:20:B9:80:9A",
      ],
    },
  },
  {
    relation: [
      "delegate_permission/common.get_login_creds",
      "delegate_permission/common.handle_all_urls",
    ],
    target: {
      namespace: "android_app",
      package_name: "dev.kumoriya.app.debug",
      sha256_cert_fingerprints: [
        "D0:66:F8:1A:97:8D:3E:C6:51:C0:80:D3:F4:24:CA:D9:66:D9:39:EC:41:94:3E:01:0D:E6:63:5E:8D:36:C4:B2",
      ],
    },
  },
] as const;

export default {
  async fetch(request: Request, _env: Env): Promise<Response> {
    const url = new URL(request.url);
    const host = url.hostname.toLowerCase();

    if (host !== INVITE_HOST) {
      return new Response("Not found", {
        status: 404,
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (url.pathname === "/.well-known/assetlinks.json") {
      return json(ASSET_LINKS);
    }

    const segments = url.pathname.split("/").filter(Boolean);
    if (segments.length === 0) {
      return Response.redirect(`${MARKETING_ORIGIN}/`, 302);
    }
    if (segments.length !== 1) {
      return notFound();
    }

    const code = segments[0].toUpperCase();
    if (!INVITE_CODE_RE.test(code)) {
      return new Response("Invalid invite code", {
        status: 400,
        headers: noStoreHeaders("text/plain; charset=utf-8"),
      });
    }

    return new Response(renderLanding(code), {
      status: 200,
      headers: noStoreHeaders("text/html; charset=utf-8"),
    });
  },
};

function notFound(): Response {
  return new Response("Not found", {
    status: 404,
    headers: noStoreHeaders("text/plain; charset=utf-8"),
  });
}

function json(value: unknown): Response {
  return new Response(JSON.stringify(value, null, 2), {
    status: 200,
    headers: {
      ...noStoreHeaders("application/json; charset=utf-8"),
      "access-control-allow-origin": "*",
    },
  });
}

function noStoreHeaders(contentType: string): HeadersInit {
  return {
    "content-type": contentType,
    "cache-control": "no-store, no-cache, must-revalidate",
    "x-kumoriya-join-router": "1",
  };
}

function renderLanding(code: string): string {
  const customScheme = `kumoriya://party/join?code=${code}`;
  const downloadUrl = `${MARKETING_ORIGIN}/#download`;
  const androidIntent =
    `intent://party/join?code=${code}` +
    `#Intent;scheme=kumoriya;package=dev.kumoriya.app;` +
    `S.browser_fallback_url=${encodeURIComponent(downloadUrl)};end`;
  const appLink = `https://${INVITE_HOST}/${code}`;

  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
<title>Watch Party · Kumoriya</title>
<meta name="description" content="Te invitaron a una Watch Party en Kumoriya. Abrí la app o instalala para unirte." />
<meta property="og:title" content="Watch Party en Kumoriya" />
<meta property="og:description" content="Te invitaron a ver anime en sincronía. Código: ${code}" />
<meta property="og:type" content="website" />
<meta property="og:url" content="${appLink}" />
<meta property="og:site_name" content="Kumoriya" />
<meta name="theme-color" content="#7C3BED" />
<link rel="icon" href="${MARKETING_ORIGIN}/favicon.svg" type="image/svg+xml" />
<style>
  :root {
    color-scheme: dark;
    --bg: #0D0915;
    --surface: #171121;
    --primary: #7C3BED;
    --primary-light: #9055EB;
    --primary-dark: #6831C9;
    --text: #FFFFFF;
    --muted: #A8B6CC;
    --border: rgba(255, 255, 255, 0.08);
  }
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter, sans-serif;
    min-height: 100dvh;
  }
  body {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
    overflow-x: hidden;
  }
  .bg {
    position: fixed;
    inset: 0;
    z-index: -1;
    background:
      radial-gradient(60% 50% at 20% 10%, rgba(124, 59, 237, 0.35), transparent 70%),
      radial-gradient(50% 50% at 85% 95%, rgba(86, 184, 255, 0.18), transparent 65%),
      var(--bg);
  }
  .card {
    width: 100%;
    max-width: 440px;
    background: linear-gradient(180deg, rgba(23, 17, 33, 0.9), rgba(13, 9, 21, 0.9));
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 28px 24px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45);
    backdrop-filter: blur(14px);
    -webkit-backdrop-filter: blur(14px);
    text-align: center;
  }
  .logo {
    width: 64px;
    height: 64px;
    margin: 0 auto 16px;
    display: grid;
    place-items: center;
    border-radius: 18px;
    background: radial-gradient(circle at 30% 30%, var(--primary-light), var(--primary-dark));
    box-shadow: 0 10px 24px rgba(124, 59, 237, 0.45);
    font-size: 28px;
  }
  h1 {
    margin: 0 0 6px;
    font-size: 22px;
    font-weight: 800;
    letter-spacing: -0.01em;
  }
  p.sub {
    margin: 0 0 20px;
    color: var(--muted);
    font-size: 14px;
    line-height: 1.5;
  }
  .code {
    display: inline-block;
    padding: 10px 18px;
    margin-bottom: 22px;
    font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
    font-size: 22px;
    font-weight: 700;
    letter-spacing: 5px;
    color: var(--primary-light);
    background: rgba(124, 59, 237, 0.12);
    border: 1px solid rgba(124, 59, 237, 0.35);
    border-radius: 12px;
  }
  .btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    padding: 14px 18px;
    font-size: 15px;
    font-weight: 700;
    border-radius: 12px;
    border: 1px solid transparent;
    cursor: pointer;
    text-decoration: none;
    transition: transform 120ms ease, box-shadow 120ms ease, background 120ms ease;
  }
  .btn:active { transform: scale(0.98); }
  .btn.primary {
    background: linear-gradient(180deg, var(--primary-light), var(--primary));
    color: #fff;
    box-shadow: 0 10px 24px rgba(124, 59, 237, 0.35);
  }
  .btn.primary:hover { background: linear-gradient(180deg, var(--primary-light), var(--primary-dark)); }
  .btn.secondary {
    background: transparent;
    color: var(--text);
    border-color: var(--border);
  }
  .btn.secondary:hover { background: rgba(255, 255, 255, 0.04); }
  .stack > * + * { margin-top: 10px; }
  .hint {
    margin-top: 18px;
    color: var(--muted);
    font-size: 12px;
    line-height: 1.5;
  }
  footer {
    margin-top: 24px;
    color: var(--muted);
    font-size: 11px;
  }
</style>
</head>
<body>
  <div class="bg"></div>
  <main class="card">
    <div class="logo" aria-hidden="true">🎬</div>
    <h1>Te invitaron a una Watch Party</h1>
    <p class="sub">Abrí Kumoriya para unirte a la sala. Si no tenés la app, descargala y el código se usará automáticamente.</p>
    <div class="code" aria-label="Código de invitación">${code}</div>
    <div class="stack">
      <a class="btn primary" href="${customScheme}" id="open-app">Abrir en Kumoriya</a>
      <a class="btn secondary" href="${downloadUrl}">Descargar Kumoriya</a>
    </div>
    <p class="hint">
      ¿No se abrió? Copiá este código y pegalo manualmente en la app:
      <br /><strong>${code}</strong>
    </p>
    <footer>${INVITE_HOST} · ver anime en sincronía con tus amigos</footer>
  </main>
  <script>
    (function () {
      var fallbackLink = ${JSON.stringify(customScheme)};
      var androidIntentLink = ${JSON.stringify(androidIntent)};
      var opened = false;
      var openAppButton = document.getElementById('open-app');
      var isAndroid = /android/i.test(navigator.userAgent);
      var isMobile = /android|iphone|ipad|ipod/i.test(navigator.userAgent);
      var preferredLink = isAndroid ? androidIntentLink : fallbackLink;

      if (isAndroid && openAppButton) {
        // Chrome/Android handles intent:// more reliably than a custom scheme
        // when the user arrives from a regular HTTPS page.
        openAppButton.setAttribute('href', androidIntentLink);
      }

      function tryOpen() {
        if (opened) return;
        opened = true;
        window.location.href = preferredLink;
      }
      if (isMobile) {
        setTimeout(tryOpen, 500);
      }
      if (openAppButton) {
        openAppButton.addEventListener('click', function () {
          opened = true;
        });
      }
    })();
  </script>
</body>
</html>`;
}
