# Projekt-Regeln für Claude Code

## Prompt-Logging

Logging wird automatisch durch Hooks übernommen. Der Hook schreibt bei jedem Prompt:
- Timestamp, Prompt-Text, Projektpfad
- Geänderte Dateien mit Zeilenbereichen
- Diff-Snippet (max 30 Zeilen)

**Deine einzige Aufgabe:** Hänge nach abgeschlossenen Code-Änderungen genau eine Zeile an den offenen Eintrag in der heutigen Log-Datei an:

```
**Summary:** [Ein Satz, der beschreibt was getan wurde]
```

Nichts sonst schreiben — kein Datum, keine Dateiliste, keine Nummerierung. Der Hook erledigt den Rest.

## Allgemein

- Antworte auf Deutsch.
