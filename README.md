# Sola Birthdays (iOS)

Auf Deutsch heißt die App **Sola Geburtstage**.

Liste mit den Geburtstagen deiner Kontakte, Erinnerungen und Widgets für Home- und
Sperrbildschirm. SwiftUI + WidgetKit, keine Abhängigkeiten, iPhone und iPad, ab iOS 18,
Deutsch und Englisch.

* Kein Server, kein Konto – die Kontakte verlassen das Gerät nie.
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
| Datum und Geburtstage | Sperrbildschirm, über der Uhr | „Di. 13. Okt. · 🎉 Anna +1 · 🎂 2 in 7 Tagen“ – kürzt sich je nach Platz bis auf „Di. 13.“ |
| Nächste Geburtstage | Sperrbildschirm, rechteckig | die nächsten drei mit Tagen, heute fett |
| Nächste Geburtstage | Sperrbildschirm, rund | Tage bis zum nächsten, Vorname |

Antippen öffnet die App beim jeweiligen Geburtstag (`klarbirthdays://birthday/<id>`).

### Grenze von iOS: 64 Mitteilungen

iOS hält pro App höchstens 64 geplante Mitteilungen. Die App plant deshalb immer die
nächsten 60 und füllt nach: bei jeder Änderung, beim Öffnen, per Hintergrundaktualisierung
und einmal täglich aus den Widgets heraus. Wer die App monatelang nicht öffnet und kein
Widget nutzt, könnte bei sehr vielen Geburtstagen Lücken bekommen.

## Daten

Eine JSON-Datei plus verkleinerte Kontaktfotos (300 px) im App-Group-Container
`group.org.christophschneider.birthdays`, damit die Widgets sie lesen können:
`birthdays.json`, `Photos/<id>.jpg`. Kein iCloud-Sync.

## Sprachen

Englisch (Ausgangssprache) und Deutsch. Texte in `Shared/Localizable.xcstrings` (App und
Widgets), App-Name und Kontakt-Hinweis in `Birthdays/InfoPlist.xcstrings`. Wie bei Sola
Slideshow: neue Texte nur als Literal in `Text`/`Button`/`Label` oder über
`String(localized:)`, Pluralformen über den Catalog, die deutsche Übersetzung im selben
Schritt eintragen.

## Bauen

```bash
open Birthdays.xcodeproj
```

Simulator (ohne Team):

```bash
xcodebuild -project Birthdays.xcodeproj -scheme Birthdays -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/birthdays-build build
```

`-derivedDataPath` außerhalb von `~/Documents` halten (iCloud-Attribute stören die Signatur).

### Aufs eigene iPhone

Signiert mit dem kostenlosen Personal Team (`Z4Z62632W2`), läuft also **7 Tage**, danach
neu bauen und installieren – die Daten bleiben. App und Widget brauchen die App Group,
die Xcode beim ersten Bauen mit `-allowProvisioningUpdates` anlegt.

```bash
xcodebuild -project Birthdays.xcodeproj -scheme Birthdays -configuration Release -destination 'id=00008150-000655C92E20401C' -derivedDataPath /tmp/birthdays-device -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device 00008150-000655C92E20401C "/tmp/birthdays-device/Build/Products/Release-iphoneos/Sola Birthdays.app"
```

App-Icon neu erzeugen (braucht Pillow):

```bash
python3 tools/make_icon.py
```

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `Shared/Models.swift` | `Birthday`, `AppData`, nächster Termin, Alter, 29. Februar |
| `Shared/Storage.swift` | JSON und Fotos im App-Group-Container, Deep Links |
| `Shared/Reminders.swift` | Mitteilungen planen (die nächsten 60), Texte, Foto-Anhang |
| `Shared/Texts.swift` / `Theme.swift` | gemeinsame Texte, Farben, `Avatar` |
| `Birthdays/Store.swift` | App-Zustand, Abgleich-Logik, Speichern → Widgets + Erinnerungen |
| `Birthdays/ContactsReader.swift` | Kontakte mit Geburtstag lesen |
| `Birthdays/ListView.swift` | Hauptliste, Heute-Karten, Verstecken mit Rückgängig |
| `Birthdays/SyncView.swift` | Abgleich und Auswahl neuer Geburtstage |
| `Birthdays/DetailView.swift` / `EditView.swift` | Detail mit eigenen Erinnerungen, Eintrag von Hand |
| `Birthdays/SettingsView.swift` | Einstellungen, versteckte Geburtstage |
| `BirthdaysWidget/` | Timeline (ein Eintrag je Mitternacht), Home- und Sperrbildschirm-Widgets |
