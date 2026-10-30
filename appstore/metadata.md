# App Store Connect – Sola Geburtstage / Sola Birthdays

Texte zum Einfügen in App Store Connect. Zeichenlimits sind geprüft (Name/Untertitel 30, Werbetext 170, Keywords 100 Bytes, Beschreibung 4000).

## Allgemein

| Feld | Wert |
| --- | --- |
| Bundle-ID | `eu.fiddlehead.sola.birthdays` |
| SKU | `eu.fiddlehead.sola.birthdays` |
| Plattformen | iPhone, iPad, Mac (gleiche Bundle-ID, ein Kauf für alle) |
| Primärsprache | Deutsch (weitere: Englisch) |
| Kategorie | Lifestyle |
| Zweite Kategorie | Produktivität (Productivity) |
| Preis | Kostenlos |
| Copyright | 2026 Christoph Schneider |
| Support-URL | https://fiddlehead.eu/sola-birthdays/support/ |
| Marketing-URL | https://fiddlehead.eu/sola-birthdays/ |
| Datenschutz-URL | https://fiddlehead.eu/sola-birthdays/privacy/ |
| Verschlüsselung | Im Info.plist erledigt (`ITSAppUsesNonExemptEncryption = NO`) |

## App-Datenschutz

Datenschutzangaben: „Daten werden nicht erfasst“ („Data Not Collected“). Die App schickt nichts an eigene Server; iCloud-Sync (nur wenn eingeschaltet) läuft über die private iCloud-Datenbank der Nutzerin bzw. des Nutzers, darauf hast du keinen Zugriff – das zählt bei Apple nicht als Datenerfassung durch dich.

## Altersfreigabe

Alle Fragen „Nein/Keine“ → 4+.

## Deutsch

**Name** (16/30)

Sola Geburtstage

**Untertitel / Subtitle** (26/30)

Erinnerungen aus Kontakten

**Werbetext / Promotional text** (144/170)

Nie wieder einen Geburtstag vergessen: Erinnerungen zur Wunschzeit und Widgets für den Sperrbildschirm. Deine Kontakte bleiben auf deinem Gerät.

**Keywords** (94/100)

```
geburtstag,erinnerung,kontakte,widget,sperrbildschirm,alter,kalender,jahrestag,freunde,familie
```

**Beschreibung / Description** (1049/4000)

```
Sola Geburtstage sorgt dafür, dass du nie wieder einen Geburtstag vergisst.

Die App holt die Geburtstage aus deinen Kontakten in eine übersichtliche Liste: heute, die nächsten 7 Tage, dann nach Monaten. Du entscheidest, welche Geburtstage du behalten willst – der Rest bleibt versteckt.

RECHTZEITIG ERINNERT
• Standardmäßig eine Woche vorher und am Tag selbst, zur Uhrzeit deiner Wahl.
• Für jeden Geburtstag lässt sich eine eigene Auswahl treffen.
• Das Kontaktfoto kommt mit in die Mitteilung.

WIDGETS
• Home-Bildschirm und Mac-Schreibtisch: wer als Nächstes dran ist, mit Foto, Tagen und Alter.
• Sperrbildschirm: Datum und anstehende Geburtstage über der Uhr, als Liste oder rund.

AUCH OHNE KONTAKT
• Geburtstage von Leuten, die nicht in deinen Kontakten stehen, trägst du von Hand ein – das Jahr ist optional.

DEINE KONTAKTE BLEIBEN BEI DIR
• Alles bleibt auf deinem Gerät. Synchronisierung über deine eigene iCloud nur, wenn du sie einschaltest.
• Kein Konto, keine Werbung, kein Tracking.

Für iPhone, iPad und Mac. Sola Geburtstage ist kostenlos und Open Source.
```

## English

**Name** (14/30)

Sola Birthdays

**Untertitel / Subtitle** (28/30)

Reminders from your contacts

**Werbetext / Promotional text** (123/170)

Never forget a birthday again: reminders when you want them and Lock Screen widgets. Your contacts never leave your device.

**Keywords** (92/100)

```
birthday,reminder,contacts,widget,lock screen,age,calendar,anniversary,friends,family,notify
```

**Beschreibung / Description** (866/4000)

```
Sola Birthdays makes sure you never forget a birthday again.

The app gathers the birthdays from your contacts into a clear list: today, the next 7 days, then by month. You decide which birthdays to keep – the rest stays hidden.

REMINDED IN TIME
• By default a week before and on the day, at the time you choose.
• Choose different reminders for any birthday.
• The contact photo comes along in the notification.

WIDGETS
• Home Screen and Mac desktop: who's next, with photo, days to go and age.
• Lock Screen: the date and upcoming birthdays above the clock, as a list or round.

NOT IN YOUR CONTACTS?
• Add birthdays by hand for anyone else – the year is optional.

YOUR CONTACTS STAY WITH YOU
• Everything stays on your device. Sync through your own iCloud only if you turn it on.
• No account, no ads, no tracking.

For iPhone, iPad and Mac. Sola Birthdays is free and open source.
```

## Hinweise für die Prüfung (App Review Information)

Anmeldedaten: keine (Haken bei „Anmeldung erforderlich“ weglassen). Kontakt: dein Name, Telefonnummer und support@fiddlehead.eu.

```
Keine Anmeldung nötig. Die App funktioniert auch ohne Kontaktzugriff: „Von Hand hinzufügen“ antippen und einen Namen mit Geburtstag eintragen. Mit Kontaktzugriff übernimmt „Aus Kontakten übernehmen“ die Geburtstage aus den Kontakten; die Kontakte verlassen das Gerät nicht.

Mitteilungen werden nur für Erinnerungen genutzt. iCloud-Sync ist standardmäßig aus und wird in den Einstellungen eingeschaltet.

English: No sign-in needed. The app works without contacts access: tap "Add by hand" and enter a name and birthday. With access, "Import from contacts" reads birthdays from Contacts; contacts never leave the device. Notifications are used for reminders only. iCloud sync is off by default.
```

## Screenshots

In `appstore/screenshots/<sprache>/`, in der Reihenfolge der Nummern hochladen. Größen: iPhone 6,9" (1320 × 2868), iPad 13" (2064 × 2752).

Entstanden im Simulator mit Demodaten: Debug-Build mit dem Startargument `-demoData YES` (siehe `DemoData.swift`; im Release-Build nicht enthalten). Alle Namen und Bilder sind erfunden.

- `screenshots/de/ipad-1.png`
- `screenshots/de/ipad-2.png`
- `screenshots/de/iphone-1.png`
- `screenshots/de/iphone-2.png`
- `screenshots/de/iphone-3.png`
- `screenshots/en/ipad-1.png`
- `screenshots/en/ipad-2.png`
- `screenshots/en/iphone-1.png`
- `screenshots/en/iphone-2.png`
- `screenshots/en/iphone-3.png`

## Vor dem Einreichen

- In App Store Connect unter Business den **EU-Händlerstatus (DSA)** angeben, sonst erscheint die App in der EU nicht.
- Archiv bauen: Xcode → Product → Archive (Release, Schema der App) → Distribute App → App Store Connect.
- **CloudKit-Schema auf Production deployen** (CloudKit Console → Container der Geburtstage-App → Deploy Schema Changes).
- **Mac:** In App Store Connect bei der App die Plattform macOS hinzufügen (gleicher Eintrag, gleiche Bundle-ID). Eigenes Archiv mit dem Ziel „Any Mac“ hochladen, eigene Screenshots (16:10, z. B. 2880 × 1800) und dieselben Texte. Die Mac-Version durchläuft eine eigene Prüfung.
