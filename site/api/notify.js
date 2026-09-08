// Launch-notification signup.
//
// Handles a plain HTML form POST — deliberately not a fetch() from the page.
// Keeping the form scriptless means the site's Content-Security-Policy can stay
// at `default-src 'none'` with no script-src at all, and the form still works
// with JavaScript disabled. The only CSP concession is `form-action 'self'`.
//
// CommonJS on purpose: there is no package.json in site/, so Vercel treats .js
// as CommonJS. `export default` here would fail at runtime.
//
// Requires env var BUTTONDOWN_API_KEY (Vercel → Settings → Environment Variables).

const BUTTONDOWN_URL = 'https://api.buttondown.com/v1/subscribers';

// Deliberately loose. The only real validation of an address is mailing it;
// anything stricter mostly rejects valid, unusual addresses.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

// Best-effort throttle. Serverless instances are ephemeral and there can be many
// in parallel, so this stops a naive flood from one client, not a real attacker.
// It is a speed bump, not a rate limiter — say so rather than pretending.
const seen = new Map();
const THROTTLE_MS = 10_000;

function seeOther(res, location) {
  res.statusCode = 303;
  res.setHeader('Location', location);
  res.setHeader('Cache-Control', 'no-store');
  res.end();
}

function parseBody(req) {
  if (!req.body) return {};
  if (typeof req.body === 'string') {
    return Object.fromEntries(new URLSearchParams(req.body));
  }
  return req.body;
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    res.statusCode = 405;
    return res.end('Method Not Allowed');
  }

  const body = parseBody(req);
  const email = String(body.email || '').trim().toLowerCase();

  // Honeypot. The field is hidden from people and irresistible to bots.
  // Answer with the success page so the bot has no signal to retry differently.
  if (String(body.company || '').trim()) {
    return seeOther(res, '/thanks');
  }

  if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
    return seeOther(res, '/signup-error');
  }

  const ip = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  const now = Date.now();
  if (ip) {
    if (now - (seen.get(ip) || 0) < THROTTLE_MS) {
      return seeOther(res, '/thanks');
    }
    seen.set(ip, now);
    if (seen.size > 500) {
      for (const [k, t] of seen) if (now - t > 10 * 60_000) seen.delete(k);
    }
  }

  const key = process.env.BUTTONDOWN_API_KEY;
  if (!key) {
    console.error('notify: BUTTONDOWN_API_KEY is not set');
    return seeOther(res, '/signup-error');
  }

  try {
    const r = await fetch(BUTTONDOWN_URL, {
      method: 'POST',
      headers: {
        Authorization: `Token ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email_address: email, tags: ['landing-page'] }),
    });

    // 201 = created. 400 = collision, i.e. already subscribed.
    // Both mean "you're on the list" to the visitor, and treating them
    // identically avoids disclosing whether an address is already subscribed.
    if (r.status === 201 || r.status === 400) {
      return seeOther(res, '/thanks');
    }

    // Never log the address itself — it is the one piece of personal data here.
    console.error('notify: buttondown returned', r.status);
    return seeOther(res, '/signup-error');
  } catch (err) {
    console.error('notify: request to buttondown failed', err && err.message);
    return seeOther(res, '/signup-error');
  }
};
