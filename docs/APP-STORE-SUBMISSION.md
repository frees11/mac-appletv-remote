# App Store submission — ATV Remote Pro

Everything App Store Connect asks for, in the order it asks. Drafts are drafts —
read them before pasting.

App: `com.atv.remote` · Team `YK34UDN964` (Aurodent CZ, s.r.o.) · macOS 14.0+

---

## 1. Account setup — done

Verified against the App Store Connect API on 2026-08-08, not just read off a page.

| Item | State |
|---|---|
| Paid Applications Agreement | **Active**, effective 2026-08-07 |
| Bank account | Fio (CZK / USD royalties) — **Active** |
| Tax forms | W-8BEN-E + Certificate of Foreign Status — **Active** |
| Digital Services Act | **Active** (27 countries) |
| App record | **ATV Remote Pro**, Apple ID `6755641074`, bundle `com.atv.remote`, macOS |
| API key | Team key named `github`, role App Manager. Installed under `~/.appstoreconnect/private_keys/` (0600) |
| Issuer ID | In ASC → Users and Access → Integrations, above the key table |

This repository is public, so the Key ID and Issuer ID are deliberately not
written down here — together with the `.p8` they are full App Manager
credentials. Both live in GitHub Secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`).

The API key was already in `~/Downloads` from an earlier session, so no new key was
generated — a `.p8` can only be downloaded once, and creating a spare would have
left an unused credential on the account.

### GitHub Secrets

Already set (uploaded 2026-08-08 by `ATVRemote/scripts/export-secrets.sh --upload`):
`MAS_CERTIFICATE`, `MAS_CERTIFICATE_PASSWORD`, `MAS_INSTALLER_CERTIFICATE`,
`MAS_INSTALLER_CERTIFICATE_PASSWORD`, `MAS_PROVISIONING_PROFILE`. `PAT_TOKEN`
carried over from the Electron era.

Still missing, and the release workflow cannot upload without them:
`ASC_KEY_P8_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`. Once the API key exists,
re-running `export-secrets.sh --upload` picks up the first two automatically;
the issuer ID has to be pasted by hand.

**The repository is public.** Secrets are not exposed by that, and the release
workflow only triggers on pushes to `main` and manual dispatch — never on pull
requests — so forks cannot reach them. Keep it that way if the triggers change.

## 2. Subscriptions — created

Subscription group **ATV Remote Pro**, group ID `22294690`.

| Level | Reference name | Product ID | Duration | Base price | Availability |
|---|---|---|---|---|---|
| 1 | Pro Yearly | `com.atv.remote.pro.yearly` | 1 year | €19.99 (SK base, 175 regions) | all |
| 2 | Pro Monthly | `com.atv.remote.pro.monthly` | 1 month | €2.49 (SK base, 175 regions) | all |

Both carry an English (U.S.) localization: display name as above, description
"Control every Apple TV on your network." Prices were anchored on Slovakia (EUR)
so the euro figure is exact rather than converted from USD; the US ends up at
$17.99 / $1.99. The group itself has an en-US localization named "ATV Remote Pro".

**Pro Yearly carries a 2-month free trial** as an introductory offer, created in
all 175 territories. The App Store Connect web UI would not open its offer dialog
at all, so the offers were created through the App Store Connect API — one call
per territory, which is what the API requires (`territory` is a mandatory
relationship on `subscriptionIntroductoryOffers`).

**Both products are `READY_TO_SUBMIT`** — verified through the API, not read off
a page. The review screenshot is a 2560×1600 capture of the paywall, which is a
standard macOS screenshot size; a straight 400×832 window capture is rejected with
`IMAGE_BAD_DIMENSION_SM_LESS_MIN` and `IMAGE_BAD_ASPECT_RATIO`.

Regenerate the screenshot after any paywall change:

```bash
open -n ~/Library/Developer/Xcode/DerivedData/ATV_Remote-*/Build/Products/Debug/"ATV Remote.app" --args -useMocks
# window id from CGWindowListCopyWindowInfo, then:
screencapture -o -x -l <windowID> shot.png
sips -Z 1500 shot.png --out scaled.png
sips -p 1600 2560 --padColor 1C1C1E scaled.png --out review.png
```

The product IDs are hardcoded in
`ATVRemote/Packages/ATVRemoteCore/Sources/ATVRemoteCore/Models/SubscriptionModels.swift`.
Changing them in ASC means changing them there too.

**On the trial length:** Apple only allows 3 days, 1 or 2 weeks, 1, 2, 3 or 6
months, or 1 year. A literal 60 days is not selectable, so this is set up as
**2 months**. See
[App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/).

**Still to do:** create `ATVRemote/ATVRemote.storekit` in Xcode
(File → New → File → StoreKit Configuration File) and add both products to it.
It was deliberately not hand-written here — the format is Xcode-generated and a
malformed file fails in confusing ways. Once it exists, select it in the scheme's
Run → Options → StoreKit Configuration to test purchases without App Store Connect.

## 3. Listing

**Name:** ATV Remote Pro
**Subtitle** (30 chars): `Ovládač pre Apple TV z Macu` / `Apple TV remote for your Mac`
**Category:** Utilities (matches `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.utilities`)

**Keywords** (100 chars, comma-separated, no spaces after commas):
`apple tv,remote,ovládač,siri remote,diaľkové,mediaremote,airplay,tv control,keyboard,touchpad`

**Promotional text** (170 chars):
> Control your Apple TV from your Mac — touchpad, keyboard, playback and volume,
> with no phone in hand. Discovers every Apple TV on your network automatically.

**Description** — draft, expand before submitting:
> ATV Remote Pro turns your Mac into a full Apple TV remote.
>
> • Automatic discovery — every Apple TV on your local network shows up on its own
> • Trackpad gestures — swipe and click exactly like the Siri Remote
> • Keyboard input — type into search fields instead of hunting letters on screen
> • Playback and volume control, with now-playing information
> • Secure pairing — credentials are stored in your Mac's Keychain and never leave it
>
> Requires an Apple TV on the same local network.

**URLs:**
- Privacy policy — `atvremote-website` already ships `privacy.html` and
  `src/app/privacy`. **Verify it is deployed and that the text matches what the
  app actually does** before pasting the URL.
- Support URL — **does not exist yet.** App Store Connect requires one. The site
  lives in a separate repository under a different owner
  (`github.com/babca/atvremote-website`), so the page has to be added there.

**Screenshots** — macOS accepts 1280×800, 1440×900, 2560×1600 or 2880×1800.
At least one, 4–6 recommended: device list, remote control, touchpad, now playing,
paywall. The app window is 400×832, so compose them on a backdrop rather than
shipping a narrow strip.

**App icon:** 1024×1024, no alpha channel.

**App Privacy:** the app stores pairing credentials in the Keychain, talks only to
devices on the local network, and has no analytics or backend. That points at
"Data Not Collected" — confirm against the shipping build rather than this note.

## 4. App Review notes

Paste something close to this. The first paragraph is the one that matters.

> **Reviewing without an Apple TV**
>
> This app controls Apple TV hardware over the local network. If no Apple TV is
> reachable, the device list is legitimately empty. To review the full interface
> without hardware, tap **"Try the demo"** at the bottom of the subscription
> screen. Demo mode runs against simulated devices and exercises every screen:
> device list, pairing, remote control, touchpad and now playing. A yellow banner
> marks it, and **Exit** in that banner returns to live mode.
>
> **Local network entitlement**
>
> The app declares `com.apple.security.temporary-exception.bonjour-browse` for
> `_mediaremotetv._tcp`, `_companion-link._tcp` and `_airplay._tcp`. These are the
> Bonjour services Apple TV publishes; browsing them is the only way to find a
> device to control. No other network access is made — there is no backend and no
> analytics.
>
> **Subscription**
>
> Full functionality requires a subscription, which starts with a 2-month free
> trial. "Restore purchases" is on the subscription screen.

## 5. Verification before submitting

1. `./ATVRemote/scripts/release.sh --archive-only` — signs cleanly with the MAS
   identities without uploading anything.
2. Full `release.sh` with the `ASC_*` variables set — build reaches TestFlight.
3. Install the TestFlight build on a clean account. Test against a real Apple TV,
   not just `tools/fake-atv` — the fake runs a tvOS 13 build where direct MRP
   works, while real tvOS 26 devices tunnel through AirPlay.
4. Run the app with no Apple TV on the network and check that demo mode carries a
   reviewer through the whole app.
5. Sandbox-test the subscription: purchase, restore on a second machine, and
   confirm a purchase made outside the app is picked up by the
   `Transaction.updates` listener.

## 6. Expiry

Both signing certificates and the `embedded` provisioning profile expire
**2026-11-21**. Renew before then or releases stop building.
