import { cors } from "../_shared/common.ts";

/// Handles GET requests for deep link redirects.
/// When called with ?code=XXXX, returns an HTML page that redirects to the app
/// deep link scheme or falls back to app store URL.
Deno.serve((req) => {
  // Handle CORS preflight
  const preflight = cors(req);
  if (preflight) return preflight;

  const url = new URL(req.url);
  const code = url.searchParams.get("code") ?? "";

  if (!code) {
    return new Response("Missing referral code.", {
      status: 400,
      headers: { "Content-Type": "text/plain" },
    });
  }

  const appScheme = `repgate://join/${encodeURIComponent(code)}`;
  const playStoreUrl = "https://play.google.com/store/apps/details?id=com.repgate.app";

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Join RepGate</title>
  <meta http-equiv="refresh" content="3;url=${playStoreUrl}">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      color: #fff;
      text-align: center;
      padding: 24px;
    }
    .logo { font-size: 48px; margin-bottom: 16px; }
    h1 { font-size: 24px; margin: 0 0 8px; }
    p { font-size: 16px; color: #b0b0b0; margin: 0 0 24px; }
    .code { 
      background: #C4E86B; 
      color: #1a1a2e; 
      padding: 8px 20px; 
      border-radius: 20px; 
      font-weight: bold; 
      font-size: 18px;
      display: inline-block;
      margin-bottom: 24px;
    }
    a {
      background: #C4E86B;
      color: #1a1a2e;
      padding: 14px 32px;
      border-radius: 30px;
      text-decoration: none;
      font-weight: bold;
      font-size: 16px;
    }
  </style>
  <script>
    // Try to open the app via deep link
    window.location.href = "${appScheme}";
    // If the app does not open, the meta refresh will redirect to Play Store
  </script>
</head>
<body>
  <div class="logo">💪</div>
  <h1>You've been invited to RepGate!</h1>
  <p>Use this referral code after signing up:</p>
  <div class="code">${code.replace(/[<>"'&]/g, '')}</div>
  <p>Redirecting to the app...</p>
  <a href="${playStoreUrl}">Download RepGate</a>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
