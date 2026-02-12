# claude-notif-hub - Plan d'implementation

## Context

Un developpeur qui utilise plusieurs sessions Claude Code en parallele (worktrees, projets differents) n'a aucun moyen simple de savoir l'etat de chaque session sans switcher entre les terminaux. Le projet [claude-second-screen](https://github.com/steima/claude-second-screen) propose un dashboard web, mais c'est lourd (serveur Express + navigateur).

**L'objectif** : un widget macOS natif, ultra-leger, toujours visible en surimpression -- comme les widgets Whisper -- qui affiche un resume agrege des sessions Claude : `2 working / 1 input needed / 1 done`.

## Decision de design (synthese de l'equipe)

5 agents ont analyse le probleme. Voici les conclusions cles :

| Question | Decision | Justification |
|----------|----------|---------------|
| **Tech stack** | Swift natif (AppKit + SwiftUI) | Le plus leger (15-30MB RAM, ~500KB binaire). Tauri a des bugs de transparence sur macOS 15.4+ (showstopper). Electron = 200MB pour un point colore. |
| **Communication** | Fichiers par session + FSEvents | Zero serveur HTTP, zero port, zero risque securite. Les hooks ecrivent un fichier par session, le widget surveille le dossier. |
| **UI** | Pilule flottante agregee | L'utilisateur veut "2 busy / 1 waiting / 3 done", pas une liste de sessions. Clic pour developper le detail. |
| **Distribution** | DMG + Homebrew cask | Pas besoin de notarisation si distribue via brew. |

## Architecture

```
~/.claude/settings.json (hooks config)
    |
    v
~/.claude-notif-hub/hook.sh (script bash unique, ~25 lignes)
    |
    v  (ecrit un fichier par session)
~/.claude-notif-hub/sessions/<session_id>.json
    ^
    |  (surveille via FSEvents - natif macOS, zero polling)
ClaudeNotifHub.app (Swift natif, ~300-500 lignes)
    |
    v
Pilule flottante toujours visible
```

**3 fichiers = tout le projet.** Un script bash, des fichiers JSON, une app native.

## Composants a implementer

### 1. Hook script unique (`hook.sh`)

Un seul script bash pour tous les evenements (SessionStart, UserPromptSubmit, Stop, Notification). Claude Code passe un JSON via stdin avec `session_id`, `cwd`, `hook_event_name`.

```
~/.claude-notif-hub/hook.sh
```

- Lit stdin JSON avec `jq`
- Ecrit/met a jour `~/.claude-notif-hub/sessions/<session_id>.json`
- Format du fichier session :
  ```json
  {"cwd": "/Users/me/project-a", "status": "busy", "ts": 1707600000}
  ```
- Sur `Stop` → status = "idle"
- Sur `UserPromptSubmit` → status = "busy"
- Sur `Notification` → status = "waiting"
- Sur `SessionStart` → status = "idle" (enregistrement)
- Fichiers ecrits atomiquement (write to .tmp + mv)

### 2. Installeur de hooks (`install.sh`)

Script qui ajoute les hooks dans `~/.claude/settings.json` en fusionnant avec les hooks existants (ne pas ecraser).

```
~/.claude-notif-hub/install.sh
```

### 3. App Swift native

```
ClaudeNotifHub/
  Package.swift              -- SPM, zero dependance externe
  Sources/
    App.swift                -- Point d'entree, NSApplication
    FloatingPanel.swift      -- NSPanel flottant (always-on-top, non-activating, draggable)
    SessionStore.swift       -- Lecture des fichiers sessions + FSEvents watcher
    PillView.swift           -- Vue SwiftUI de la pilule agregee
    SessionDetailView.swift  -- Vue expandee avec liste des sessions
    StatusColor.swift        -- Mapping status → couleur
```

**~300-500 lignes de Swift au total.**

#### FloatingPanel (AppKit)

```swift
NSPanel avec:
  .level = .floating                    // toujours au-dessus
  .collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
  .isMovableByWindowBackground = true   // draggable
  .hidesOnDeactivate = false            // visible meme quand pas focus
  .styleMask = [.nonactivatingPanel, .fullSizeContentView]
  .backgroundColor = .clear             // transparent
```

+ `NSVisualEffectView` avec material `.hudWindow` pour l'effet vitreux natif macOS.

#### PillView (SwiftUI) - Vue par defaut

Pilule compacte (~220x36px) affichant :

```
 [●] 2 working  [●] 1 input needed  [●] 1 done
```

- Couleur de bordure = pire statut (rouge si un session attend, sinon ambre si une travaille, sinon vert)
- Le point "working" pulse doucement (animation opacity 3s)
- Semi-translucide, coins arrondis 12px

#### SessionDetailView (SwiftUI) - Vue expandee au clic

Apparait sous la pilule au clic :

```
 project-a     working
 project-b     input needed
 project-c     done
```

- Chaque ligne : [point couleur] [nom du dossier tronque] [statut]
- Clic sur une ligne → rien pour v1 (eventuellement ouvrir le terminal en v2)
- Max 5 lignes visibles, scroll apres

#### SessionStore

- Surveille `~/.claude-notif-hub/sessions/` via `DispatchSource.makeFileSystemObjectSource` (FSEvents natif)
- Re-lit tous les fichiers `.json` du dossier quand un changement est detecte
- Marque comme "disconnected" si `ts` > 5 minutes sans update
- Supprime les fichiers de sessions mortes apres 30 minutes
- Publie via `@Observable` (ou `ObservableObject`) pour que SwiftUI re-render automatiquement

#### Menu bar complementaire

- `NSStatusItem` avec un point colore (couleur = pire statut)
- Clic sur l'icone menu bar → toggle la visibilite du widget
- Filet de securite si le widget est perdu hors-ecran

### Statuts affiches

| Hook event | Statut interne | Label affiche | Couleur |
|---|---|---|---|
| `SessionStart` | idle | done | Vert #34C759 |
| `UserPromptSubmit` | busy | working | Ambre #FF9F0A |
| `Stop` | idle | done | Vert #34C759 |
| `Notification` | waiting | input needed | Rouge #FF453A |
| stale (>5min) | disconnected | disconnected | Gris #8E8E93 |

### Comportements UX

- **Position** : sauvegardee dans UserDefaults, restauree au lancement
- **Position hors-ecran** (moniteur deconnecte) : reset au coin haut-droit
- **Zero sessions** : pilule grise "No sessions", opacite reduite a 60% apres 10min
- **Animations** : expand/collapse 200ms spring, crossfade couleurs 500ms
- **Pas de sons, pas de notifications macOS** -- communication 100% visuelle/ambiante

## Structure du projet

```
claude-notif-hub/
  README.md
  ClaudeNotifHub/
    Package.swift
    Sources/
      App.swift
      FloatingPanel.swift
      SessionStore.swift
      PillView.swift
      SessionDetailView.swift
      StatusColor.swift
  hooks/
    hook.sh
    install.sh
  Makefile                   -- build, install, clean
```

## Ordre d'implementation

1. **Hook script** (`hooks/hook.sh`) + script d'installation
2. **SessionStore** - lecture des fichiers + FSEvents watcher
3. **FloatingPanel** - fenetre flottante AppKit
4. **PillView** - vue agregee SwiftUI
5. **SessionDetailView** - vue expandee au clic
6. **Menu bar icon** - NSStatusItem complementaire
7. **Makefile** - build (`swift build`), install (copie + hooks), clean
8. **Tests manuels** end-to-end

## Verification & Tests

### Test automatise : script de simulation (`test.sh`)

Creer un script `test.sh` a la racine qui simule le cycle de vie complet :

```bash
#!/bin/bash
# Simule 3 sessions avec differents etats

DIR="$HOME/.claude-notif-hub/sessions"
mkdir -p "$DIR"

# 1. Enregistrer 3 sessions
for i in test1 test2 test3; do
  echo "{\"session_id\":\"$i\",\"cwd\":\"/tmp/project-$i\",\"hook_event_name\":\"SessionStart\"}" | bash hooks/hook.sh
  sleep 0.5
done

sleep 2  # Laisser le widget reagir

# 2. Passer test1 en busy, test2 en waiting
echo '{"session_id":"test1","cwd":"/tmp/project-test1","hook_event_name":"UserPromptSubmit"}' | bash hooks/hook.sh
echo '{"session_id":"test2","cwd":"/tmp/project-test2","hook_event_name":"Notification"}' | bash hooks/hook.sh

sleep 2

# 3. Ramener tout en idle
for i in test1 test2 test3; do
  echo "{\"session_id\":\"$i\",\"cwd\":\"/tmp/project-$i\",\"hook_event_name\":\"Stop\"}" | bash hooks/hook.sh
done

sleep 2

# 4. Cleanup
rm -f "$DIR"/test*.json
```

### Verification visuelle par screenshot

A chaque etape cle, je prendrai un screenshot et le lirai pour verifier visuellement :

```bash
# Capturer une zone de l'ecran (coin haut-droit ou la pilule devrait etre)
screencapture -R 0,0,400,100 /tmp/claude-widget-test.png

# Ou capturer tout l'ecran
screencapture /tmp/claude-widget-full.png
```

Puis utiliser l'outil `Read` pour lire l'image et verifier :
- La pilule est visible et correctement positionnee
- Les couleurs correspondent aux statuts (vert/ambre/rouge)
- Le texte agrege est correct ("2 working / 1 input needed")
- L'expand/collapse fonctionne

### Checklist de verification (dans l'ordre)

**Phase 1 : Build**
- [ ] `swift build` compile sans erreur ni warning
- [ ] Le binaire existe dans `.build/debug/ClaudeNotifHub`
- [ ] Taille du binaire < 2MB

**Phase 2 : Lancement**
- [ ] Lancer l'app : `.build/debug/ClaudeNotifHub &`
- [ ] Screenshot → verifier : pilule visible en haut a droite, "No sessions", grise
- [ ] Verifier le process tourne : `ps aux | grep ClaudeNotifHub`
- [ ] Verifier la memoire : `ps -o rss -p $(pgrep ClaudeNotifHub)` → < 50MB

**Phase 3 : Hook script**
- [ ] Le hook script est executable : `chmod +x hooks/hook.sh`
- [ ] Simuler SessionStart → verifier que le fichier JSON est cree dans `~/.claude-notif-hub/sessions/`
- [ ] Contenu du fichier JSON est valide : `cat ~/.claude-notif-hub/sessions/test1.json | python3 -m json.tool`

**Phase 4 : Reactions du widget (screenshots a chaque etape)**
- [ ] 1 session idle → screenshot → pilule verte "1 done"
- [ ] 1 session busy → screenshot → pilule ambre "1 working"
- [ ] 1 session waiting → screenshot → pilule rouge "1 input needed"
- [ ] 3 sessions mixtes (1 busy, 1 waiting, 1 idle) → screenshot → pilule rouge "1 working / 1 input needed / 1 done"
- [ ] 0 sessions (cleanup fichiers) → screenshot → pilule grise "No sessions"

**Phase 5 : Interactions**
- [ ] Clic sur la pilule → screenshot → vue expandee avec liste des sessions
- [ ] Re-clic → screenshot → retour a la pilule compacte
- [ ] Menu bar icon visible et colore correctement

**Phase 6 : Persistance**
- [ ] Kill et relancer l'app → la pilule reapparait a la meme position
- [ ] Verifier UserDefaults : `defaults read com.claude-notif-hub` (ou equivalent)

**Phase 7 : Installation des hooks**
- [ ] `bash hooks/install.sh` → verifier `~/.claude/settings.json` contient les hooks
- [ ] Si des hooks existaient deja → verifier qu'ils n'ont pas ete ecrases
- [ ] Lancer une vraie session Claude Code → verifier que le widget detecte la session

### Test d'integration reel

Apres tous les tests de simulation, faire un test end-to-end reel :
1. Installer les hooks avec `install.sh`
2. Ouvrir un terminal, lancer `claude`
3. Verifier que la pilule passe a "1 working" quand Claude travaille
4. Verifier que la pilule passe a "1 done" quand Claude finit
5. Screenshot final de validation

## Hors scope (v1)

- **Usage/quota** : le pourcentage de plan utilise n'est pas accessible programmatiquement (issues GitHub #13585, #20399). On pourra l'ajouter quand Anthropic exposera ces donnees. Les stats locales existent dans `~/.claude/stats-cache.json` (messages, tokens, sessions par jour) mais sans les limites du plan, un % serait trompeur.
- **Cross-platform** : macOS uniquement pour l'instant
- **Clic sur session → ouvrir terminal** : complexe (AppleScript + identifier la fenetre terminal), reporte en v2
- **Notifications macOS natives** : on reste sur l'approche 100% visuelle/ambiante
