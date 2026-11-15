# App Store Connect API: plan

**Status:** plan only. Nothing here is built yet.

**Goal:** let Claude Code (or a script) work with App Store Connect from this repo, so release chores stop being click-throughs: reading review status, editing store metadata, attaching builds, and swapping screenshots. Submissions stay human-approved.

**Why:** during the 1.0 review (Aug–Nov 2026), every metadata change, build swap, and status check was done by hand from screenshots. The current description isn't stored anywhere in the repo either, so it can't be reviewed or diffed.

---

## Ground rules

These apply to every phase.

1. **The key never enters git.** `.p8` files are in the root `.gitignore`. The key lives only in `~/.appstoreconnect/private_keys/`, with mode `600`.
2. **Never print the key.** Don't paste its contents into a chat, log, or PR. Scripts read it from disk and only use it to sign short-lived tokens.
3. **Reads are free; writes need a yes.** Read-only calls (status, builds, current metadata) can run at any time. Any call that changes App Store Connect first shows a before/after diff and waits for Rohan's explicit approval.
4. **Submitting for review is always manual approval.** Submitting or resubmitting needs a direct "submit it" from Rohan for that specific submission. Approval for one submission doesn't carry over to the next.
5. **No PII in the repo.** App Review contact details (phone, email) stay in App Store Connect. They are never pulled into tracked files.
6. **Doesn't touch the app.** This is release tooling only. The app itself stays free of network code (see `CLAUDE.md`, "On-device only"). The tooling runs on the Mac, never in `ios/GeethaHealth/`.

---

## Phase 0: create the key (Rohan, ~5 min)

Requires the Account Holder or Admin role on GEETHAKAMAL LLC.

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys**.
2. First time only: **Request Access** and accept the terms.
3. **Generate API Key**:
   - Name: `Claude Code`
   - Access: **App Manager**. It covers metadata, builds, and submissions. Don't use Admin, which is broader than needed.
4. **Download** the `.p8` file. Apple allows this **once**.
5. Note the **Key ID** (shown next to the key) and the **Issuer ID** (shown at the top of the page).
6. Install the key:
   ```bash
   mkdir -p ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
   ```
   This is the default folder Xcode's command-line tools search for keys.
7. Store the two IDs (they aren't secret on their own) in `~/.appstoreconnect/config`, outside the repo:
   ```bash
   ASC_KEY_ID=XXXXXXXXXX
   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

**Revoking:** on the same Team Keys page, click **Revoke**. Do this immediately if the `.p8` file is ever exposed, then generate a new key.

---

## How authentication works

Each request carries a JWT signed with the `.p8` key (ES256):

- Header: `{"alg": "ES256", "kid": "<ASC_KEY_ID>", "typ": "JWT"}`
- Payload: `{"iss": "<ASC_ISSUER_ID>", "iat": <now>, "exp": <now + ≤20 min>, "aud": "appstoreconnect-v1"}`
- Send it as `Authorization: Bearer <token>` to `https://api.appstoreconnect.apple.com/v1/...`

Apple rejects tokens that are valid for more than 20 minutes. Mint a new token per run. Don't cache it on disk.

---

## Tooling choice

**One dependency-free Swift script: `ios/Scripts/asc.swift`.** This matches the existing `swift make-pdf.swift` pattern, and the Mac already has everything it needs:

- `CryptoKit`: `P256.Signing.PrivateKey(pemRepresentation:)` loads the `.p8` file (PKCS#8 PEM). The JWT signature must be the **raw** `r‖s` form (`signature.rawRepresentation`), not DER.
- `URLSession` for the HTTP calls.
- Subcommands, so each one has a clear read or write boundary (for example `asc status`, `asc metadata pull`, `asc metadata push --dry-run`).

Rejected alternatives:
- **fastlane:** a Ruby toolchain and a large dependency surface for a handful of calls.
- **Python + PyJWT:** an extra install, and nothing else in the iOS tooling uses Python.

---

## Phases

### Phase 1: read-only status (first milestone)

`asc status` prints:
- The app record (look it up by bundle ID `com.geethahealth.GeethaHealth`; Apple ID `6790617715`).
- Each App Store version, with its state (for example `REJECTED`, `WAITING_FOR_REVIEW`, `READY_FOR_SALE`) and the attached build.
- Recent builds, with their processing state.
- Current review submission state.

Endpoints: `GET /v1/apps?filter[bundleId]=…`, `GET /v1/apps/{id}/appStoreVersions`, `GET /v1/appStoreVersions/{id}/build`, `GET /v1/builds?filter[app]=…`, `GET /v1/reviewSubmissions?filter[app]=…`.

**Done when** `asc status` matches what the App Store Connect web page shows.

### Phase 2: metadata in the repo

Pull the store listing into tracked plain-text files, so changes go through PRs like code:

```
ios/AppStore/metadata/en-US/
  name.txt
  subtitle.txt
  description.txt
  keywords.txt
  promotional_text.txt
  support_url.txt
  marketing_url.txt
  release_notes.txt          # "What's New", from 1.0.1 on
ios/AppStore/review_notes.txt    # App Review Information → Notes (no contact info)
```

- `asc metadata pull` writes these files from App Store Connect.
- `asc metadata push --dry-run` shows the diff. `asc metadata push` applies it after approval.

Endpoints:
- Version-level text: `GET/PATCH /v1/appStoreVersionLocalizations/{id}` (description, keywords, promotionalText, supportUrl, marketingUrl, whatsNew).
- App-level text: `GET /v1/apps/{id}/appInfos` → `GET/PATCH /v1/appInfoLocalizations/{id}` (name, subtitle).
- Review notes: `GET/PATCH /v1/appStoreReviewDetails/{id}` (`notes` only; the script never reads or writes contact fields into files).

Note: name and subtitle can only be changed while a version is editable (for example Prepare for Submission or Rejected).

### Phase 3: builds

- **Upload:** keep `xcodebuild archive` + `xcodebuild -exportArchive` (as on Nov 14, 2026), but authenticate with the key instead of the Xcode-signed-in account:
  `-authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8 -authenticationKeyID <ID> -authenticationKeyIssuerID <ISSUER>`
- **Wait:** `asc build wait 5` polls `GET /v1/builds?filter[version]=5` until `processingState` is `VALID`.
- **Attach (write):** `asc build attach 5`, using `PATCH /v1/appStoreVersions/{id}/relationships/build`.

Lesson from Nov 14: App Store Connect refuses a build number it has already seen, even one that was never submitted. Check existing build numbers before archiving, and always bump `CURRENT_PROJECT_VERSION` in `ios/project.yml` through a PR.

### Phase 4: screenshots

- `asc screenshots list` shows each screenshot set (by display type) and its images.
- `asc screenshots replace <display-type> <dir>` deletes the set's current images and uploads new ones. It is a write, so it needs approval. Upload is three steps: `POST /v1/appScreenshots` (reserve) → `PUT` the bytes to the returned `uploadOperations` → `PATCH` with `uploaded: true` and the MD5 `sourceFileChecksum`.
- The source images come from `GeethaHealthUITests/MarketingScreenshotTests`, run on a 6.9" simulator (for example iPhone 17 Pro Max), so store screenshots and site screenshots come from the same test.

### Phase 5: submission (approval-gated)

`asc submit` creates a review submission (`POST /v1/reviewSubmissions`), adds the version (`POST /v1/reviewSubmissionItems`), and marks it submitted (`PATCH /v1/reviewSubmissions/{id}` with `submitted: true`). Before doing anything it prints exactly what will be submitted (version, build, changed metadata) and asks for confirmation.

**To verify when building this:** how the API handles resubmitting a submission that's already in "Unresolved Issues" (an existing rejected submission versus a new one).

---

## Out of scope

- **App Review messages (Resolution Center).** As far as we know, the public API doesn't expose reading or replying to review messages. Re-check when building Phase 1. Until then, replies are posted by hand in App Store Connect.
- Pricing, availability, agreements, tax and banking.
- In-app purchases and subscriptions (the app has none).
- Anything in the app binary.

---

## Open questions

- This repo is **public** on GitHub. The store listing is public anyway, so `ios/AppStore/metadata/` is fine here. Decide whether `review_notes.txt` belongs in a public repo, or should stay local and untracked like the key IDs.
- Once Phase 2 exists, should a PR that changes `ios/AppStore/` also run `asc metadata push --dry-run` in CI? That would need the key as a GitHub secret, which goes against ground rule 1. The current answer is no: run it locally only.
