# Marketing site (geethahealth.com)

The public website for Geetha Health. Its only job is to convince someone on a
laptop to install the iPhone app — it is **not** a web client, and there is no
plan for one.

Lives in [`site/`](../site/), deployed to Vercel. Live at
[geethahealth.com](https://geethahealth.com).

## Why it exists in this shape

The obvious alternative — a real web app with accounts syncing to a backend —
was considered and rejected. It would have required a server holding medical
records, a schema migration to give SwiftData models stable IDs, a privacy-label
flip from "Data Not Collected", a mandatory account-deletion flow, and a
Washington My Health My Data Act compliance package. A static page keeps every
invariant in `CLAUDE.md` intact.

## Deployment

Vercel project, **Root Directory `site`**. Framework preset "Other", **no build
command and no output directory** — the files are served as authored.

Getting the root directory wrong is the main way this breaks: Vercel builds the
repo root, finds no index, and serves a 404.

Production deploys from `main`. `geethahealth.com` is registered at Vercel, so
DNS is managed there and needs no manual records.

## Asset caching

Images are cached `immutable` for a year. **CSS is not** — it is
`max-age=0, must-revalidate`.

That asymmetry is deliberate and was learned the hard way. There is no build
step, so `site.css` has no content hash in its name; serving it `immutable`
meant returning visitors kept a year-old stylesheet and never saw new rules.
When the signup form shipped, anyone who had visited before got the new HTML
with the old CSS — an unstyled input and a *visible* spam honeypot. The
stylesheet is 10KB and revalidation is a 304, so correctness wins easily.

`?v=2` on the stylesheet link is the one-time buster for caches poisoned before
the header was fixed. It can be dropped once no one is running a browser cache
from that window; leaving it costs nothing.

If a screenshot ever needs replacing, give it a new filename rather than
overwriting — images *are* served immutable.

## No build step, and no Jekyll

`site/` is hand-authored HTML. The header and footer are duplicated across the
four pages; with a site this small that is cheaper than owning a build
pipeline, but it does mean **a change to the shell must be made in all four
files**.

The pages were originally Jekyll (when GitHub Pages hosted them) and were
converted once. Do not reintroduce Liquid — Vercel has no first-class Jekyll
support, and the templating bought little for four pages.

## Constraints that are load-bearing

**No external requests. At all.** System font stack, no Google Fonts, no CDN, no
analytics, no pixels. A page that phones home while advertising an app that
doesn't would undercut the entire pitch. This is also why there is no captcha on
the signup form.

**No JavaScript.** Not a stylistic preference — it is what lets
[`vercel.json`](../site/vercel.json) ship `default-src 'none'` with no
`script-src` at all. The privacy claim is enforced by headers rather than only
asserted in copy. Adding one inline `style=` attribute or one `<script>` breaks
it, silently, because the browser blocks it rather than erroring visibly.

**Keep Vercel Analytics and Speed Insights off.** Both are one toggle away from
making the footer's "no analytics, no trackers, no cookies" false.

**No medical-advice or diagnosis language**, same bar as the app's UI copy, and
keep the not-a-medical-device disclaimer in the footer.

## Call to action

The app is not on the App Store yet, so the page shows a non-clickable
"Coming Fall 2026" badge. A button that goes nowhere is worse than an honest
status label.

All three placements (header, hero, closing band) render from
[`site/_includes`-style logic inlined in each page](../site/index.html) — set the
App Store URL in the CTA markup to swap them. Size and inversion variants are
`comingsoon`, `comingsoon-lg`, `comingsoon-invert` in `site/assets/site.css`.

## Email signup

`POST /api/notify` → [`site/api/notify.js`](../site/api/notify.js) → Buttondown →
`303` redirect to `/thanks` or `/signup-error`.

- **A plain HTML form POST, deliberately not `fetch()`.** This is what keeps the
  site script-free; the only CSP concession is `form-action 'self'`. It also
  works with JavaScript disabled.
- **CommonJS, not ESM.** There is no `package.json` in `site/`, so Vercel treats
  `.js` as CommonJS; `export default` would fail at runtime.
- Requires env var **`BUTTONDOWN_API_KEY`** (Production + Preview + Development).
  Environment variables do not apply to existing deployments — redeploy after
  changing one.
- Buttondown returns **400 on a duplicate** address. That is treated identically
  to 201 so the response never discloses whether an address is already
  subscribed.
- **The address is never written to logs.** It is the only personal data here.
- Spam handling is a hidden honeypot field (`company`) plus a per-IP speed bump.
  The throttle is best-effort only — serverless instances are ephemeral and
  parallel, so it stops a naive flood, not an attacker.
- **Double opt-in is enabled** in Buttondown: a new subscriber is `Unactivated`
  until they click the confirmation link. `/thanks` says so explicitly. If that
  setting is ever changed, that copy becomes wrong.

## The privacy policy exists twice

[`site/privacy.html`](../site/privacy.html) is canonical.
[`docs/privacy.md`](privacy.md) is a mirror that keeps
`rohanrobinson.github.io/GeethaHealthAI/privacy` resolving, because that URL is
registered in App Store Connect.

**Edit both, or neither.** They have been verified word-for-word identical, and
a drift between two published versions of a privacy policy is a real problem,
not a tidiness one.

Once the App Store Connect privacy URL is updated to
`https://geethahealth.com/privacy`, the `docs/` copy can become a redirect and
the duplication goes away. Instructions are in `docs/_layouts/page.html`.

Note the policy is no longer "we collect nothing": the mailing list means the
website collects an email address if you type one in. The policy says so.

## Screenshots

`site/assets/shot-*.png` are generated by
`GeethaHealthUITests/MarketingScreenshotTests`, not shot by hand, so they can be
regenerated after a UI change instead of quietly going stale.

```bash
xcrun simctl erase <device>          # so onboarding is shown
xcodebuild test -only-testing:GeethaHealthUITests/MarketingScreenshotTests \
  -resultBundlePath shots.xcresult
xcrun xcresulttool export attachments --path shots.xcresult --output-path <dir>
sips --resampleWidth 700 <file> --out <file>
```

The test seeds a fictional profile and drives the UI by accessibility label, so
label changes break it in the same way they break `VoiceSymptomUITests`. It
waits out the undo snackbar before the hero shot and dismisses both consent
sheets ("Continue" for voice, "I understand" for Ask).

Never use real medical information in marketing assets.

## Anything added to `docs/` becomes a public web page

GitHub Pages serves this whole folder. Every `.md` here is live on the web
unless it is in the `exclude:` list in [`_config.yml`](_config.yml) — which is
how the engineering design docs (including this one) stay unpublished.

**Add new design notes to that list**, or they ship publicly the moment they
merge.

## Known gaps

- The four pages duplicate their header and footer.
- No sitemap or `robots.txt`.
- Contact address in the footer and the privacy policy is a personal Gmail
  account; sending from `geethahealth.com` would be better for deliverability
  and for how the launch email reads.
- Buttondown needs a physical mailing address configured before any send —
  CAN-SPAM requires one in the footer.
