# Terra Mia — note per Claude

- Progetto Godot 4.4, GDScript, renderer Compatibility (serve per l'export HTML5).
- Il design è in `docs/design.md`; la fonte aggiornata è il documento Claude Docs
  "Terra Mia — Documento di design". Testi del gioco, commenti e documentazione in italiano.
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
