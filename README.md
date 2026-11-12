# Terra Mia

Gioco di fattoria a quadranti: coltivando e allevando riporti in vita un borgo
italiano abbandonato. Single-player, sessioni da 5–10 minuti, prima su browser
(CrazyGames, Poki), poi Steam e mobile dallo stesso progetto.

Il documento di design completo è in [`docs/design.md`](docs/design.md).

## Requisiti

- [Godot 4.4](https://godotengine.org/download) (versione standard, non .NET)
- Renderer **Compatibility**, necessario per l'export HTML5

## Avvio

1. Apri Godot e importa `project.godot`.
2. Premi **F5**: parte `scenes/main.tscn`.

## Come si gioca (prototipo)

- **Zappa:** tocca i quadranti d'erba per metterli in coda. Il contadino li
  lavora uno alla volta, 15 secondi l'uno, anche a gioco chiuso. Si semina solo
  sulla terra lavorata; toccando di nuovo un quadrante in coda lo togli.
- **Negozio:** semi di tutte le piante (ognuna si sblocca al suo livello) e concime.
- **Semi:** scegli il seme nella barra in basso e tocca la terra lavorata.
- **Annaffia:** costa una goccia e toglie il 30% del tempo che manca. Il pozzo
  si riempie di una goccia ogni 90 secondi, fino a 20.
- **Concime:** raddoppia il prossimo raccolto della pianta (dal livello 2).
- **Raccolto:** le piante pronte si raccolgono con qualsiasi strumento.
  Tenendo premuto e trascinando si zappa, semina, annaffia o raccoglie su più
  quadranti in un colpo. Alberi e arbusti restano piantati e rifanno i frutti.

## Struttura

```
project.godot            configurazione, autoload, finestra 1280×720
scenes/
  main.tscn / main.gd    scena principale, HUD, navigazione Fattoria ↔ Borgo
  farm/farm.gd           griglia isometrica 6×6, piantare e raccogliere
  borgo/borgo.gd         bacheca degli ordini e mulino
  farm/backdrop.gd       sfondo: cielo, colline, nuvole, il paese
  ui/shop.gd             negozio di semi e concime
  ui/settings_panel.gd   impostazioni: lingua, volumi, informazioni
scripts/ui/ui_kit.gd     pezzi d'interfaccia riusati (pastiglie, icone, pulsanti)
scripts/autoload/settings.gd  lingua e volumi (impostazioni del dispositivo)
scripts/autoload/
  game_data.gd           dati statici: colture, edifici, livelli (dal documento)
  game_state.gd          stato della partita e regole (monete, XP, ordini, restauri)
  save_manager.gd        salvataggio locale in user:// e progresso offline
tests/test_game_state.gd test delle regole di gioco (senza grafica)
tools/build_theme.gd     genera il tema dell'interfaccia
tools/translations_source.py  testi in 4 lingue -> localization/translations.csv
tools/extract_icons.py   ritaglia le icone dal foglio illustrato
tools/extract_plants.py  ritaglia gli sprite delle piante (3 stadi) da un foglio
tools/paint_tiles.py     dipinge i blocchi di terreno (erba, terra, terra bagnata)
docs/art_direction.md    prompt e regole per tutte le illustrazioni
assets/graphics/         blocchi di terreno SVG (tiles/), icone PNG (icons/) ritagliate
                         da source/icons_sheet.webp con tools/extract_icons.py
assets/theme/            tema dell'interfaccia (generato, non modificarlo a mano)
assets/fonts/            Fredoka (SIL Open Font License, vedi OFL.txt)
docs/design.md           documento di design
```

### Scelte tecniche

- **Timer reali.** Ogni coltura salva il timestamp Unix di semina, quindi il
  tempo scorre anche a gioco chiuso senza simulare nulla. La moka recupera gli
  espressi persi al rientro (`GameState.apply_offline_progress`).
- **Dati in un posto solo.** Tempi, livelli, prezzi, zappa, gocce e concime
  stanno in `game_data.gd`; il bilanciamento si fa lì. I prezzi delle piante
  vengono da una formula descritta in testa al file.
- **Grafica 2.5D.** Vista isometrica con blocchi di terra dipinti
  (`tools/paint_tiles.py`). Le piante con uno sprite illustrato lo usano, le
  altre si disegnano da codice in `farm.gd`. Ogni quadrante si disegna dal
  fondo verso lo spettatore, terra e pianta insieme. Sopra il mondo c'è una
  rifinitura leggera (`assets/shaders/painterly.gdshader`: luce calda e grana
  della carta); etichette e timer stanno sopra, per restare nitidi.
- **Tema dell'interfaccia.** È l'equivalente del CSS: colori, bordi, font e
  varianti dei controlli (`PrimaryButton`, `ToolButton`, `Card`, `Pill`...) stanno
  in `tools/build_theme.gd`. Dopo una modifica si rigenera con
  `godot --headless --path . -s tools/build_theme.gd`.
- **Salvataggi locali** in `user://terramia_save.json` (su web finisce in
  IndexedDB). Supabase arriva solo con gli acquisti in-app.

## Lingue

Il gioco è in italiano, inglese, francese e spagnolo. All'avvio usa la lingua
scelta dal giocatore nelle Impostazioni (l'ingranaggio in alto a destra),
altrimenti quella del dispositivo, altrimenti l'inglese.

## Impostazioni

L'ingranaggio in alto a destra apre lingua, volume di musica ed effetti e
informazioni sul gioco (versione, creatore, crediti). Tutto sta in
`user://settings.cfg`, separato dal salvataggio della partita. I volumi
regolano i bus audio `Music` e `SFX`: musica ed effetti, quando ci saranno,
vanno suonati su quei bus. Il nome del creatore è `GameData.CREATOR`.

I testi stanno in `tools/translations_source.py`: ogni chiave ha le quattro
versioni. Per aggiungere o cambiare un testo:

```bash
python3 tools/translations_source.py
```

```bash
godot --headless --import
```

Il primo comando rigenera `localization/translations.csv`, il secondo lo fa
reimportare a Godot. I test controllano che ogni lingua abbia tutte le chiavi
e gli stessi segnaposto (`%d`, `%s`) dell'italiano.

## Test

```bash
godot --headless --path . -s tests/test_game_state.gd
```

Esce con codice 1 se un controllo fallisce.

## Export web

1. *Editor → Manage Export Templates*: installa i template della 4.4.
2. *Project → Export → Add → Web*, poi esporta in `build/web/`.
3. Per provarlo in locale serve un server HTTP, non il file aperto da disco:
   ```bash
   python3 -m http.server --directory build/web 8000
   ```

`export_presets.cfg` e `build/` sono esclusi da git.

## Roadmap del prototipo

- [x] Griglia isometrica, piantare e raccogliere grano e pomodori
- [x] Tutte le piante del documento, negozio di semi e concime
- [x] Zappa con il contadino, gocce d'acqua, raccolto trascinando
- [x] Timer reali e progresso offline
- [x] Bacheca ordini, monete, esperienza e livelli 1–3
- [x] Mulino restaurabile con il mugnaio (prima versione)
- [ ] Tutorial dei primi 15 minuti
- [ ] Grafica SVG provvisoria e audio di base
- [ ] SDK CrazyGames con video premio
- [ ] Pubblicazione su CrazyGames e due settimane di dati

Fuori scopo per ora: multiplayer, visite tra amici, scambi, classifiche, chat.
