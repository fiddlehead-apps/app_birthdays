# Sola Birthdays (iOS und macOS)

Auf Deutsch heißt die App **Sola Geburtstage**.

Liste mit den Geburtstagen deiner Kontakte, Erinnerungen und Widgets für Home- und
Sperrbildschirm und den Mac-Schreibtisch. SwiftUI + WidgetKit, keine Abhängigkeiten, iPhone
und iPad ab iOS 18, Mac ab macOS 15 (native App aus denselben Targets, kein Catalyst),
Deutsch und Englisch.

* Kein Server, kein Konto – die Kontakte verlassen das Gerät nie, außer man schaltet den
  iCloud-Sync ein (aus, solange man ihn nicht einschaltet; dann in die eigene private iCloud).
* Gleicher Look wie die anderen Sola-Apps, Akzentfarbe Himbeerrot.

## Was die App kann

**Abgleich mit den Kontakten** (Pfeil-Knopf oben, läuft nur manuell): liest alle
Kontakte mit Geburtstag. Neue werden in einer Auswahlliste angeboten (alle vorausgewählt,
„Keine auswählen“/„Alle auswählen“). Nicht ausgewählte landen direkt bei *Versteckt*, damit
sie beim nächsten Abgleich nicht wieder angeboten werden. Bekannte Einträge werden still
aktualisiert (Name, Datum, Foto); Einträge, deren Kontakt oder Geburtstag verschwunden ist,
fliegen raus. Bei eingeschränktem Kontaktzugriff (iOS 18) wird nichts entfernt.

**Liste:** heute als große Karten, dann „Nächste 7 Tage“, dann nach Monaten. Wischen nach
links = verstecken (mit Rückgängig). Antippen = Detail mit Datum, Alter, Erinnerungen.

**Versteckt:** Versteckte Geburtstage bleiben in den Daten, bekommen aber keine
Erinnerungen und erscheinen nicht in Liste und Widgets. Liste aller versteckten: unten in
der Hauptliste („2 versteckt“) oder in den Einstellungen; dort mit Suche und „Zeigen“.

**Von Hand hinzufügen** (+ oben): für Leute, die nicht in den Kontakten stehen. Jahr
optional. Diese Einträge lassen sich bearbeiten und löschen; der Abgleich fasst sie nicht an.

**Erinnerungen:** Standard 1 Woche vorher und am Tag selbst, Uhrzeit 9:00 – beides in den
Einstellungen änderbar (30/14/7/3/2/1/0 Tage vorher). Pro Geburtstag lässt sich der
Standard abschalten und eine eigene Auswahl treffen. Das Kontaktfoto hängt als Bild an der
Mitteilung.

**Widgets:**

| Widget | Größe | Inhalt |
| --- | --- | --- |
| Nächste Geburtstage | klein | nächster Geburtstag mit Foto, große Zahl „Tage“, Name, Datum, Alter. Mehrere am selben Tag: Fotos überlappend, „Anna und Ida“. Heute: ganze Fläche himbeerrot mit Konfetti |
| Nächste Geburtstage | mittel | links wie klein, rechts die drei danach mit Foto und Tagen (jede Zeile öffnet ihren Geburtstag) |
| Nächste Geburtstage | groß | oben der nächste als Zeile, darunter die fünf danach |
| Datum und Geburtstage | Sperrbildschirm, über der Uhr | hinter dem Datum, das iOS dort selbst zeigt: „🎉 Anna +1 · 🎂 Ben in 3; +2“ – wer heute dran ist, wer als Nächstes in den nächsten 7 Tagen (Name und Tage) und wie viele danach noch kommen; kürzt sich je nach Platz bis auf die Anzahlen |
| Nächste Geburtstage | Sperrbildschirm, rechteckig | die nächsten drei mit Tagen, heute fett |
| Nächste Geburtstage | Sperrbildschirm, rund | Tage bis zum nächsten, Vorname |

Antippen öffnet die App beim jeweiligen Geburtstag (`solabirthdays://birthday/<id>`).
Auf dem Mac gibt es die Home-Widgets (klein, mittel, groß) für Schreibtisch und
Mitteilungszentrale; Sperrbildschirm-Widgets gibt es dort nicht.

### Mac

Dieselbe App, nativ für macOS: ein Fenster, Knöpfe in der Symbolleiste, im Menü
„Geburtstag hinzufügen“ (⌘N), „Mit Kontakten abgleichen“ (⌘R) und „Einstellungen …“ (⌘,).
Verstecken per Rechtsklick oder Wischen auf dem Trackpad. Kontakte und Erinnerungen wie auf
dem iPhone, mit zwei Unterschieden: Es gibt keinen eingeschränkten Kontaktzugriff, und der
Hinweis „Erinnerungen sind aus“ erscheint nur, bis die Frage nach Mitteilungen beantwortet
ist – wer am Mac Nein sagt, weil das iPhone schon erinnert, wird nicht weiter gefragt.
Fenster schließen beendet die App nicht, damit der iCloud-Sync weiterläuft.

### Grenze von iOS: 64 Mitteilungen

iOS hält pro App höchstens 64 geplante Mitteilungen. Die App plant deshalb immer die
nächsten 60 und füllt nach: bei jeder Änderung, beim Öffnen, per Hintergrundaktualisierung
und einmal täglich aus den Widgets heraus. Wer die App monatelang nicht öffnet und kein
Widget nutzt, könnte bei sehr vielen Geburtstagen Lücken bekommen.

## Daten

Eine JSON-Datei plus verkleinerte Kontaktfotos (300 px) im App-Group-Container
`group.eu.fiddlehead.sola.birthdays`, damit die Widgets sie lesen können:
`birthdays.json`, `Photos/<id>.jpg`.

### iCloud-Sync

Standardmäßig aus, Schalter in den Einstellungen. Eingeschaltet gehen über die private
CloudKit-Datenbank (CKSyncEngine, Record-Zone „Birthdays“) ein Record pro Geburtstag (Name,
Datum, versteckt, eigene Erinnerungen, aus Kontakten oder von Hand, Foto als Asset) und einer
für die Erinnerungs-Einstellungen. Inhalte liegen in `encryptedValues`. Jedes Gerät plant
seine Mitteilungen selbst.

* **Kontakt-IDs sind pro Gerät verschieden** und werden nicht synchronisiert. Geburtstage aus
  iCloud haben auf einem neuen Gerät erst keine Kontakt-ID; der nächste Kontakte-Abgleich
  ordnet sie über Name und Datum zu. Ohne Zuordnung bleiben sie stehen, nur Geburtstage, deren
  Kontakt *auf diesem Gerät* verschwunden ist, fliegen raus.
* Wurde derselbe Geburtstag auf zwei Geräten angelegt, bevor sie sich gesehen haben, bleibt
  der aus iCloud (Abgleich über Name und Datum), der andere wird gelöscht.
* Konflikte: die neuere Änderung gewinnt (`modified` pro Geburtstag, `settingsModified`).
* Ausschalten fragt, ob die Daten in iCloud bleiben oder gelöscht werden; auf dem Gerät bleibt
  alles. Abmelden, Account-Wechsel oder in iCloud gelöschte Daten schalten den Sync ebenfalls
  aus, ohne lokal etwas zu löschen. Der Sync-Zustand liegt in
  `Application Support/CloudSync.json` (nicht in der App Group).

## Sprachen

Englisch (Ausgangssprache) und Deutsch. Texte in `Shared/Localizable.xcstrings` (App und
Widgets), App-Name und Kontakt-Hinweis in `SolaBirthdays/InfoPlist.xcstrings`. Wie bei Sola
Slideshow: neue Texte nur als Literal in `Text`/`Button`/`Label` oder über
`String(localized:)`, Pluralformen über den Catalog, die deutsche Übersetzung im selben
Schritt eintragen.

## Bauen

```bash
open SolaBirthdays.xcodeproj
```

Simulator (ohne Team):

```bash
xcodebuild -project SolaBirthdays.xcodeproj -scheme SolaBirthdays -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/birthdays-build build
```

`-derivedDataPath` außerhalb von `~/Documents` halten (iCloud-Attribute stören die Signatur).

### Aufs eigene iPhone

Team und Bundle-ID (`eu.fiddlehead.sola.birthdays`) kommen aus `Config/Config.xcconfig`.
Signiert mit dem kostenlosen Personal Team (`Z4Z62632W2`), läuft also **7 Tage**, danach
neu bauen und installieren – die Daten bleiben. App und Widget brauchen die App Group,
die Xcode beim ersten Bauen mit `-allowProvisioningUpdates` anlegt.

```bash
xcodebuild -project SolaBirthdays.xcodeproj -scheme SolaBirthdays -configuration Release -destination 'id=00008150-000655C92E20401C' -derivedDataPath /tmp/birthdays-device -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device 00008150-000655C92E20401C "/tmp/birthdays-device/Build/Products/Release-iphoneos/Sola Birthdays.app"
```

### iCloud

iCloud-Sync braucht ein bezahltes Developer-Team; das Personal Team kann iCloud und Push
nicht signieren. Deshalb ist es ein Build-Schalter in `Config/Config.xcconfig`:
`SOLA_ICLOUD = NO` (Standard) baut ohne iCloud-Entitlements, der Schalter in der App sagt
dann, dass dieser Build nicht synchronisiert. Mit dem fiddlehead-Team neben den Repos eine
`sola-local.xcconfig` anlegen (gilt für alle Sola-Apps, auch in Xcode):

```
SOLA_TEAM = <Team-ID>
SOLA_ICLOUD = YES
```

oder einmalig `../build-sola-apps.sh --icloud`. Vor TestFlight/App Store im CloudKit
Dashboard das Schema nach Production deployen.

### Auf den eigenen Mac

```bash
./build.sh --mac
```

baut die Mac-App (Release, signiert) und kopiert sie nach `/Applications`; danach lässt sich
das Widget auf dem Schreibtisch hinzufügen (Rechtsklick → Widgets bearbeiten). Der Mac
braucht dieselbe App Group und denselben iCloud-Container wie das iPhone, Xcode registriert
ihn beim ersten Bauen mit `-allowProvisioningUpdates` als Gerät.

App-Icon neu erzeugen (braucht Pillow), danach die Mac-Größen daraus (abgerundet nach Apples
Mac-Vorlage):

```bash
python3 tools/make_icon.py
```

```bash
swift tools/make_mac_icon.swift
```

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `Shared/Models.swift` | `Birthday`, `AppData`, nächster Termin, Alter, 29. Februar |
| `Shared/Storage.swift` | JSON und Fotos im App-Group-Container, Deep Links |
| `Shared/Reminders.swift` | Mitteilungen planen (die nächsten 60), Texte, Foto-Anhang |
| `Shared/Texts.swift` / `Theme.swift` | gemeinsame Texte, Farben, `Avatar` |
| `Shared/Platform.swift` | was zwischen iPhone/iPad und Mac abweicht: Bilder, Farben, Systemeinstellungs-Links, Sheet-Größen |
| `SolaBirthdays/Store.swift` | App-Zustand, Abgleich-Logik, Speichern → Widgets + Erinnerungen + iCloud, Records |
| `SolaBirthdays/CloudSync.swift` / `CloudSyncToggle.swift` | iCloud-Sync (CKSyncEngine), Schalter mit Status; gleiche Dateien wie in Sola Slideshow |
| `SolaBirthdays/ContactsReader.swift` | Kontakte mit Geburtstag lesen |
| `SolaBirthdays/ListView.swift` | Hauptliste, Heute-Karten, Verstecken mit Rückgängig |
| `SolaBirthdays/SyncView.swift` | Abgleich und Auswahl neuer Geburtstage |
| `SolaBirthdays/DetailView.swift` / `EditView.swift` | Detail mit eigenen Erinnerungen, Eintrag von Hand |
| `SolaBirthdays/SettingsView.swift` | Einstellungen, versteckte Geburtstage |
| `Config/` | `Config.xcconfig` (Bundle-IDs, Team, iCloud-Schalter), Info.plists, Entitlements (mit und ohne iCloud, für den Mac mit Sandbox) |
| `SolaBirthdaysWidget/` | Timeline (ein Eintrag je Mitternacht), Home- und Sperrbildschirm-Widgets |
