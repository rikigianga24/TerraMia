# Terra Mia — note per Claude

- Progetto Godot 4.4, GDScript, renderer Compatibility (serve per l'export HTML5).
- Il design è in `docs/design.md`; la fonte aggiornata è il documento Claude Docs
  "Terra Mia — Documento di design". Commenti e documentazione in italiano.
- Dati statici solo in `scripts/autoload/game_data.gd`; le regole in `game_state.gd`.
  Le scene leggono e modificano lo stato solo tramite `GameState` e ascoltano `GameState.changed`.
- Timer = timestamp Unix assoluti (`GameState.now()`), mai contatori che avanzano con `_process`.
- Il salvataggio è un dizionario JSON: un campo nuovo va aggiunto sia in `to_dict` sia in
  `from_dict`, con un valore di default per i salvataggi vecchi.
- Indentazione con tab nei file `.gd`.
- Dopo ogni modifica alle regole lancia i test: `godot --headless --path . -s tests/test_game_state.gd`.
  Negli script lanciati con `-s` gli autoload non si vedono per nome: si prendono con `root.get_node("GameState")`.
- Stili dell'interfaccia solo nel tema: si modifica `tools/build_theme.gd` e si rigenera
  `assets/theme/terramia_theme.tres`; nei controlli si usa `theme_type_variation`, non override sparsi.
- Per controllare la grafica: avvio con `xvfb-run -a godot --path . --rendering-driver opengl3`
  e screenshot con `get_viewport().get_texture().get_image().save_png(...)`.
- Nessun testo visibile scritto nel codice: si aggiunge una chiave in `tools/translations_source.py`
  (it, en, fr, es), si rigenera il CSV e si usa `tr("CHIAVE")`. Nomi di piante, prodotti ed edifici
  con `GameData.crop_name()`, `product_name()`, `building_name()`, `resident_name()`.
  Solo caratteri presenti nel font Fredoka (niente frecce o emoji).
- Direzione artistica e prompt per le illustrazioni: `docs/art_direction.md`. Ogni nuova grafica
  deve seguirlo (illustrazione dipinta, sagome pulite, colori mediterranei vivi).
- Sprite: fogli in `assets/graphics/source/`, nomi e riquadri in `assets/graphics/sprites/sprites.json`,
  ritaglio con `python3 tools/cut_sprites.py` (vedi `docs/art_direction.md`). Nel codice si usano con
  `Sprites.tex(nome)` / `Sprites.draw(...)`. Quello che non ha sprite si disegna da codice.
