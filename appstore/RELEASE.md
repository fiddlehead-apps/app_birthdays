 # Releasing Sola Birthdays to the App Store

This guide covers a first release of Sola Birthdays (iPhone, iPad and Mac, one App Store
record) and every update after it. The texts to paste into App Store Connect are in
[`metadata.md`](metadata.md). The screenshots are in [`screenshots/`](screenshots).

## Overview

| # | Step | Where | Once or every release |
| --- | --- | --- | --- |
| 1 | [Paid developer team and local config](#1-paid-developer-team-and-local-config) | Apple Developer, `../sola-local.xcconfig` | once |
| 2 | [Identifiers: App ID, App Group, iCloud container](#2-identifiers) | Xcode, Apple Developer | once |
| 3 | [iCloud: fill the development schema, then deploy it to production](#3-icloud) | the app, CloudKit Console | once, and again when you add fields |
| 4 | [The build script](#4-the-build-script) | Terminal | every release |
| 5 | [Create the app in App Store Connect](#5-create-the-app-in-app-store-connect) | App Store Connect | once |
| 6 | [Archive and upload the iPhone/iPad app](#6-archive-and-upload-iphone-and-ipad) | Xcode | every release |
| 7 | [Archive and upload the Mac app](#7-archive-and-upload-the-mac-app) | Xcode | every release |
| 8 | [Test with TestFlight](#8-test-with-testflight) | TestFlight | every release |
| 9 | [Submit for review](#9-submit-for-review) | App Store Connect | every release |
| 10 | [Later updates](#10-later-updates) | | |

---

## 1. Paid developer team and local config

You need a membership in the **Apple Developer Program** (99 €/year). The free Personal Team
can't sign iCloud or push notifications and can't upload to App Store Connect.

1. Check your membership at <https://developer.apple.com/account>. The **Team ID** is under
   *Membership details*.
2. Put the team and the iCloud switch into `sola-local.xcconfig` **next to** the repos, at
   `~/git/sola-local.xcconfig`. It isn't in git. All Sola apps and Xcode read it:

   ```
   SOLA_TEAM = <your paid Team ID>
   SOLA_ICLOUD = YES
   ```

   This is already set up: `SOLA_TEAM = Z4Z62632W2` (the paid fiddlehead team, also the
   default in `Config/Config.xcconfig`) and `SOLA_ICLOUD = YES`.
3. In Xcode open **Settings → Accounts** and check that the Apple ID of the paid team is
   signed in.

> `SOLA_ICLOUD = YES` matters for the App Store build. Without it the archive has no iCloud
> entitlement, and Settings → iCloud only says that this build can't sync.
> `Config/Config.xcconfig` defaults to `NO` so other people can build the app with a free
> team. Only your local file switches it on.

## 2. Identifiers

The project uses automatic signing. Xcode registers everything the first time it builds with
the paid team:

| What | Identifier |
| --- | --- |
| App ID (app) | `eu.fiddlehead.sola.birthdays`: App Groups, iCloud (CloudKit), Push Notifications |
| App ID (widget) | `eu.fiddlehead.sola.birthdays.widget`: App Groups |
| App Group | `group.eu.fiddlehead.sola.birthdays` |
| iCloud container | `iCloud.eu.fiddlehead.sola.birthdays` |

To trigger the registration, build once for the iPhone and once for the Mac (see
[step 4](#4-the-build-script)):

```bash
./build.sh            # iPhone, connected by cable or on the same Wi-Fi
./build.sh --mac      # Mac, copies the app to /Applications
```

Then check at <https://developer.apple.com/account/resources/identifiers/list>:

- Both App IDs exist.
- The app's App ID has **App Groups**, **iCloud** (with the container
  `iCloud.eu.fiddlehead.sola.birthdays` ticked) and **Push Notifications** turned on.
- Under *App Groups* and *iCloud Containers* in the dropdown on the top right, the group and
  the container exist.

If a build fails with "No profile matching …" or "container not found", open the project in
Xcode once, select the **SolaBirthdays** target → *Signing & Capabilities*, choose the paid
team and let Xcode fix the profile. Then run the build script again.

## 3. iCloud

CloudKit has two environments:

- **Development**: used by every build you sign yourself (Xcode Run, `build.sh`). It creates
  record types and fields automatically the first time the app saves them.
- **Production**: used by TestFlight and the App Store. It only knows the record types and
  fields you **deploy** to it. A field that is missing there makes uploads fail for every
  user.

The data of the two environments is separate: what you synced with your own builds isn't in
the App Store version. That is expected.

### 3a. Make sure every field exists in development

CloudKit only creates a field when a record is saved with a value in it. Fields that are
empty (`nil`) never appear. So once, with a build from `./build.sh` (with
`SOLA_ICLOUD = YES`), on the iPhone or the Mac:

1. Open **Settings** in the app and turn on the switch under **iCloud**.
2. Create a birthday **by hand** with a **year**.
3. Import a birthday **from your contacts** whose contact has a **photo**.
4. Open a birthday, turn off **Use default** under Reminders and pick something different.
5. **Hide** a birthday.
6. Change the **reminder time** or the default reminders in Settings.
7. Wait a few seconds, or close and reopen the app.

### 3b. Check the schema in the CloudKit Console

1. Open <https://icloud.developer.apple.com> → **CloudKit Database** → the container
   `iCloud.eu.fiddlehead.sola.birthdays` → environment **Development**.
2. Go to **Schema → Record Types**. These fields must be there:

   **Birthday**

   | Field | Type | Note |
   | --- | --- | --- |
   | `name` | String | encrypted |
   | `shortName` | String | encrypted |
   | `month` | Int(64) | encrypted |
   | `day` | Int(64) | encrypted |
   | `year` | Int(64) | encrypted, only if a birthday with a year was synced |
   | `reminders` | Bytes | encrypted, only if a birthday has its own reminders |
   | `fromContacts` | Int(64) | |
   | `hidden` | Int(64) | |
   | `modified` | Date/Time | |
   | `photo` | Asset | only if a birthday with a photo was synced |

   **Settings**

   | Field | Type | Note |
   | --- | --- | --- |
   | `defaultReminders` | Int(64) List | encrypted |
   | `reminderHour` | Int(64) | encrypted |
   | `reminderMinute` | Int(64) | encrypted |
   | `modified` | Date/Time | |

   If a field is missing, repeat the matching step from 3a.

3. Indexes: the app syncs through record zone changes and never queries, so it needs no
   indexes. If you want to browse records in the Console, add a *Queryable* index on
   `recordName` for each record type. It doesn't hurt.

### 3c. Deploy the schema to production

1. In the CloudKit Console, still in **Development**, click **Deploy Schema Changes…**.
2. Check the list (two record types, the fields above) and confirm.
3. Switch to **Production → Schema → Record Types** and check that both types are there.

> Production fields can't be deleted or change their type later. You can only add new ones.
> If you add a field in a future version, repeat 3a–3c **before** you upload that version.

### 3d. Push notifications

Changes from other devices arrive by silent push. `Config/*-iCloud.entitlements` contain
`aps-environment = development`. **Don't change that.** When you distribute to App Store
Connect, Xcode switches it to `production` automatically.

## 4. The build script

`build.sh` builds the app for your own devices and raises the build number. **It doesn't
make the App Store archive.** That's done in Xcode ([steps 6](#6-archive-and-upload-iphone-and-ipad)
and [7](#7-archive-and-upload-the-mac-app)).

```bash
cd ~/git/app_birthdays
./build.sh --help
```

| Command | What it does |
| --- | --- |
| `./build.sh` | builds for the iPhone (Release) and installs it on the one paired iPhone |
| `./build.sh --no-install` | builds for the iPhone, doesn't install |
| `./build.sh --install-only` | installs the last iPhone build without building |
| `./build.sh --mac` | builds for the Mac (Release) and copies it to `/Applications`, including the widget |
| `./build.sh --sim` | quick compile check for the simulator, without signing |
| `./build.sh --icloud` | builds with iCloud even without `SOLA_ICLOUD = YES` in the local config |
| `./build.sh --bump` | raises the build number by one. Alone it only does that; with other options it builds afterwards |

Environment variables:

| Variable | Use |
| --- | --- |
| `DEVICE_ID` | which iPhone, if more than one is paired (`xcrun devicectl list devices` lists them) |
| `TEAM_ID` | another team for signing, for this one call |
| `BUILD_DIR` | where builds and logs go (default `/tmp/sola-build`) |

Examples:

```bash
DEVICE_ID=00008150-000655C92E20401C ./build.sh
./build.sh --bump --mac       # raise the build number, then build the Mac app
```

If a step fails, the script shows the first errors and the path of the full log, for
example `/tmp/sola-build/birthdays-device.log`.

### Version and build number

- **Version** (`MARKETING_VERSION`, now `1.0`): what users see in the App Store. Raise it
  for each new release (1.0 → 1.1). It's set once at project level for the app and the
  widget, which must match. So change it in Xcode on the **project** (not a target) →
  *Build Settings* → *Marketing Version*, or in Terminal:

  ```bash
  sed -i '' 's/MARKETING_VERSION = 1.0;/MARKETING_VERSION = 1.1;/' SolaBirthdays.xcodeproj/project.pbxproj
  ```

  Don't use the *Version* field in a target's *General* tab. It would set the version for
  that target only, and the upload fails if the app and the widget differ.
- **Build** (`CURRENT_PROJECT_VERSION`, now `1`): must go up with **every** upload, including
  TestFlight. The iPhone and Mac uploads may have the same number.

Before every upload:

```bash
./build.sh --bump
git commit -am "Build 2"
git push
```

## 5. Create the app in App Store Connect

At <https://appstoreconnect.apple.com>:

### Business (once per account)

1. **Business → Agreements**: the *Free Apps* agreement is active once you accept the
   Program License Agreement. A free app needs nothing more.
2. **Business → EU Digital Services Act**: declare your **trader status**. Without it the app
   doesn't appear in the EU stores. As a private developer of a free app with no commercial
   intent you can declare "not a trader". Otherwise address, phone and email become public on
   the App Store page.

### The app record

1. **Apps → + → New App**:
   - Platforms: tick **iOS** and **macOS** (one record, one bundle ID, one purchase for all
     devices).
   - Name: `Sola Geburtstage`. If it's taken, it has to change.
   - Primary language: **German**.
   - Bundle ID: `eu.fiddlehead.sola.birthdays`. It's only in the list after step 2.
   - SKU: `eu.fiddlehead.sola.birthdays`.
   - User access: Full Access.
2. **App Information**: category Lifestyle, secondary category Productivity, content rights
   "doesn't contain third-party content". Add **English** as a second localization (dropdown
   on the top right) and fill in its name and subtitle.
3. **App Privacy**: privacy policy URL `https://fiddlehead.eu/sola-birthdays/privacy/`.
   Data types: **Data Not Collected**.
4. **Pricing and Availability**: Free, all countries.
5. **Age Rating**: answer every question "No/None" → 4+.
6. Version page **iOS App 1.0**, for German and English each:
   - Promotional text, description, keywords, support URL and marketing URL from
     `metadata.md`.
   - Screenshots: **iPhone 6.9"**: `iphone-1…3.png`; **iPad 13"**: `ipad-1…2.png`. Drag
     them in in the order of their numbers.
   - Copyright: `2026 Christoph Schneider`.
   - **App Review Information**: untick "Sign-in required", add contact details, paste the
     notes from `metadata.md`.
   - Version Release: **Manually release this version** is the safer choice for the first
     release.
7. Version page **macOS App 1.0**: same texts, screenshots `mac-1.png` and `mac-2.png`
   (2880 × 1800), same review notes.

Check that the support, privacy and marketing pages under `fiddlehead.eu/sola-birthdays/`
are live. Apple opens them during review.

## 6. Archive and upload: iPhone and iPad

1. `./build.sh --bump`, then commit (see [step 4](#version-and-build-number)).
2. Check that `~/git/sola-local.xcconfig` contains `SOLA_ICLOUD = YES` and the paid team.
3. `open SolaBirthdays.xcodeproj`
4. In the toolbar choose the scheme **SolaBirthdays** and the destination **Any iOS Device
   (arm64)**.
5. **Product → Archive**. This uses Release automatically. When it's done, the Organizer
   opens.
6. Select the archive → **Distribute App** → **App Store Connect** → **Distribute**. Xcode
   signs with the distribution certificate and uploads. Keep the default options (upload
   symbols, automatic signing).
7. After 5–30 minutes the build shows up in App Store Connect under **TestFlight** and you
   get an email. Encryption is already answered in the Info.plist
   (`ITSAppUsesNonExemptEncryption = NO`), so there's no question about it.

Check the entitlements after the archive (optional, but quick): Organizer → right-click the
archive → *Show in Finder* → right-click → *Show Package Contents*, then in Terminal:

```bash
codesign -d --entitlements - "Products/Applications/Sola Birthdays.app"
```

You should see `icloud-container-identifiers` with `iCloud.eu.fiddlehead.sola.birthdays`. If
it's missing, `SOLA_ICLOUD` wasn't `YES` when you archived.

## 7. Archive and upload the Mac app

The same steps with a different destination. No new bump is needed, because the iPhone and
the Mac can share a build number.

1. Destination **Any Mac** (in the same scheme **SolaBirthdays**).
2. **Product → Archive** → **Distribute App** → **App Store Connect** → **Distribute**.
3. The build appears in App Store Connect under **TestFlight → macOS**.

The Mac app has the App Sandbox, Hardened Runtime and contacts access in its entitlements
(`Config/SolaBirthdays-macOS-iCloud.entitlements`), which the Mac App Store requires.

## 8. Test with TestFlight

TestFlight builds use the **production** iCloud environment, the same one as the App Store.
This is the only place where you can test the deployed schema before release.

1. App Store Connect → **TestFlight** → **Internal Testing** → create a group and add
   yourself. Internal builds need no review.
2. Install **TestFlight** on the iPhone and on the Mac (Mac App Store), then install the build
   from there. It replaces the version from `build.sh`. The local data stays because it's the
   same bundle ID and App Group.
3. Test:
   - [ ] Turn on iCloud sync on the iPhone and on the Mac. Both show no error.
   - [ ] A birthday added on the iPhone appears on the Mac within about a minute, and the
         other way round.
   - [ ] Hide one, change its reminders, delete one: each change arrives on the other device.
   - [ ] Photos arrive.
   - [ ] Import from contacts on both devices: no duplicates afterwards.
   - [ ] Reminders arrive at the chosen time (set a reminder for today if one is due).
   - [ ] Widgets on the iPhone home screen, the Lock Screen and the Mac desktop show the same
         birthdays, and hidden ones don't appear.
   - [ ] Restart the iPhone without unlocking it for a while, then unlock: the list is still
         there.

If sync fails with an error like "unknown field" or "record type not found", the schema
wasn't deployed completely. Repeat [3a–3c](#3-icloud). Those builds need no new upload, as
the schema is on the server.

## 9. Submit for review

For each platform, on its version page (iOS App 1.0, macOS App 1.0):

1. Under **Build**, click **+** and choose the uploaded build.
2. Check that every field is filled in. App Store Connect marks missing ones in red.
3. **Add for Review** → **Submit to App Review**.

iOS and Mac are reviewed separately. Usually it takes 1–2 days. If Apple rejects it, the
reason is under *App Review* in the Resolution Center. You answer there, or fix the app,
bump, upload, choose the new build and submit again.

With "Manually release" you then press **Release This Version** yourself.

## 10. Later updates

1. Make the changes, test with `./build.sh` and `./build.sh --mac`.
2. New fields in iCloud? Then do [3a–3c](#3-icloud) **before** the upload.
3. Raise the version ([see above](#version-and-build-number), for example 1.0 → 1.1), then
   `./build.sh --bump`, commit and push.
4. In App Store Connect, add a new version with **+** next to iOS App and macOS App, and fill
   in "What's New".
5. Archive and upload ([6](#6-archive-and-upload-iphone-and-ipad),
   [7](#7-archive-and-upload-the-mac-app)), test in TestFlight ([8](#8-test-with-testflight)),
   submit ([9](#9-submit-for-review)).

## Troubleshooting

| Problem | Fix |
| --- | --- |
| "Personal development teams … do not support the iCloud capability" | `SOLA_TEAM` is still the free team. Put the paid Team ID in `~/git/sola-local.xcconfig`. |
| "No Accounts" or "No signing certificate 'Apple Distribution'" when distributing | Xcode → Settings → Accounts → choose the team → *Manage Certificates* → **+** → *Apple Distribution*. |
| The bundle ID isn't in the dropdown for New App | The App ID isn't registered yet. Build once with `./build.sh` ([step 2](#2-identifiers)). |
| Upload error "The bundle version must be higher than the previously uploaded version" | Run `./build.sh --bump`, then archive again. |
| Upload error about the App Group on the Mac (`group.` prefix) | In the developer portal, check that the Mac App ID has the App Group `group.eu.fiddlehead.sola.birthdays` and let Xcode renew the profile (*Signing & Capabilities*). Since macOS 15, `group.` app groups are allowed if the provisioning profile contains them. |
| Settings → iCloud says "This build keeps everything on this device and can’t sync." | The archive was made without `SOLA_ICLOUD = YES`. Fix the local config and archive again. |
| Sync works with `build.sh` but not in TestFlight | The production schema is missing fields. See [3](#3-icloud). |
