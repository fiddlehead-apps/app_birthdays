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
fliegen raus. Bei eingeschränktem Kontaktzugriff (iOS 18) wird nichts entfernt. Das passiert
schon beim Lesen; danach heißt der Knopf oben „Später“ (Neue werden nächstes Mal wieder
angeboten) bzw. „Schließen“.

**Liste:** heute als große Karten, dann „Nächste 7 Tage“, dann nach Monaten. Wischen nach
links = verstecken (mit Rückgängig), auch bei den Heute-Karten. Antippen = Detail mit Datum,
Alter, Erinnerungen. Um Mitternacht rückt die Liste weiter, auch wenn die App offen bleibt.
Passt „20. Oktober · Wird 34“ neben „In 12 Tagen“ nicht in eine Zeile, steht dort
„20. Okt. · Wird 34“, notfalls das Alter in einer eigenen Zeile.

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
und einmal täglich aus den Widgets heraus (die ihre Timeline nach jeder Mitternacht neu
holen). Nachgeplant wird nur, was fehlt oder sich geändert hat; bestehende Mitteilungen
bleiben stehen, damit ein abgebrochenes Nachplanen keine löscht. Wer die App monatelang nicht
öffnet und kein Widget nutzt, könnte bei sehr vielen Geburtstagen Lücken bekommen.

Die Widgets bekommen ihre Timeline, bevor nachgeplant wird, und werden auch beim Öffnen der
App neu geladen. Sind alle Geburtstage versteckt, sagen sie das; vor dem ersten Entsperren
nach einem Neustart zeigen sie nur „Geburtstage“ und versuchen es nach 15 Minuten wieder.

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
* Wurde derselbe Geburtstag auf zwei Geräten angelegt, bevor sie sich gesehen haben (Abgleich
  über Name und Datum), behalten alle Geräte die Kopie mit der kleineren ID und löschen die
  andere. Würde jedes Gerät die aus iCloud behalten, könnten zwei Geräte gleichzeitig die
  jeweils eigene löschen, und der Geburtstag wäre überall weg. War er auf einem der Geräte
  versteckt, bleibt er versteckt; eigene Erinnerungen der einen Kopie gehen nicht verloren.
* Konflikte: die neuere Änderung gewinnt (`modified` pro Geburtstag, `settingsModified`, mit
  Millisekunden). Eine Änderung wird nie früher datiert als die zuletzt gesehene Version,
  damit eine nachgehende Uhr eine spätere Änderung nicht verlieren lässt.
* Kontaktfotos rechnet jedes Gerät selbst um; als geändert gilt ein Foto nur, wenn sich das
  Foto im Kontakt ändert (`photoSource`, nur lokal). Sonst würden die Geräte es bei jedem
  Abgleich hin- und herschicken.
* Nach jedem vollständigen Abruf lädt die App hoch, was iCloud noch nicht hat – auch wenn der
  erste Abgleich beim Einschalten gescheitert ist.
* Änderungen von anderen Geräten kommen per stiller Push-Mitteilung; weil iOS nicht jede
  zustellt, holt die Hintergrundaktualisierung (etwa alle 12 Stunden) sie zusätzlich ab, damit
  Widgets und Erinnerungen ohne Öffnen der App nachziehen. Startet iOS die App im Hintergrund,
  bevor das iPhone nach einem Neustart entsperrt wurde, ist die Datei noch nicht lesbar: Dann
  speichert sie nichts, plant nichts um und wartet mit iCloud, bis die Datei lesbar ist, damit
  die leere Liste die echte nicht überschreibt.
* Ausschalten fragt, ob die Daten in iCloud bleiben oder gelöscht werden; auf dem Gerät bleibt
  alles. Abmelden, Account-Wechsel oder in iCloud gelöschte Daten schalten den Sync ebenfalls
  aus, ohne lokal etwas zu löschen. Was bei ausgeschaltetem Sync gelöscht wird, merkt sich die
  App und löscht es beim Wiedereinschalten auch in iCloud, statt es zurückzuholen. Der
  Sync-Zustand liegt in `Application Support/CloudSync.json` (nicht in der App Group).

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
Signiert mit dem bezahlten fiddlehead-Team (`Z4Z62632W2`, Apple Developer Program); ein
so signierter Build läuft ein Jahr. Wer die App mit dem kostenlosen Personal Team baut
(eigene `SOLA_TEAM`, ohne iCloud), muss sie alle **7 Tage** neu bauen und installieren –
die Daten bleiben. App und Widget brauchen die App Group, die Xcode beim ersten Bauen mit
`-allowProvisioningUpdates` anlegt. `./build.sh` erledigt das Folgende in einem Schritt;
von Hand die Geräte-ID aus `xcrun devicectl list devices` einsetzen:

```bash
xcodebuild -project SolaBirthdays.xcodeproj -scheme SolaBirthdays -configuration Release -destination 'id=<device-id>' -derivedDataPath /tmp/birthdays-device -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device <device-id> "/tmp/birthdays-device/Build/Products/Release-iphoneos/Sola Birthdays.app"
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

Die komplette Anleitung für den App Store (iCloud einrichten, Schema deployen, Archiv,
TestFlight, Einreichen) steht in [`appstore/RELEASE.md`](appstore/RELEASE.md).

Vor jedem Upload zu App Store Connect (auch TestFlight) die Buildnummer erhöhen und den
Commit mitnehmen:

```bash
./build.sh --bump
```

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
| `SolaBirthdays/CloudSync.swift` / `CloudSyncToggle.swift` | iCloud-Sync (CKSyncEngine), Schalter mit Status; aus Sola Slideshow, hier ergänzt um Nach-Upload nach jedem Abruf und Löschungen bei ausgeschaltetem Sync |
| `SolaBirthdays/ContactsReader.swift` | Kontakte mit Geburtstag lesen |
| `SolaBirthdays/ListView.swift` | Hauptliste, Heute-Karten, Verstecken mit Rückgängig |
| `SolaBirthdays/SyncView.swift` | Abgleich und Auswahl neuer Geburtstage |
| `SolaBirthdays/DetailView.swift` / `EditView.swift` | Detail mit eigenen Erinnerungen, Eintrag von Hand |
| `SolaBirthdays/SettingsView.swift` | Einstellungen, versteckte Geburtstage |
| `Config/` | `Config.xcconfig` (Bundle-IDs, Team, iCloud-Schalter), Info.plists, Entitlements (mit und ohne iCloud, für den Mac mit Sandbox) |
| `SolaBirthdaysWidget/` | Timeline (ein Eintrag je Mitternacht), Home- und Sperrbildschirm-Widgets |
