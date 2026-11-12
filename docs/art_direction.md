# Direzione artistica

Tutte le illustrazioni del gioco (piante, edifici, icone, terreno, personaggi)
seguono questo prompt. Va usato così com'è per ogni nuovo foglio di sprite,
così lo stile resta uniforme.

## Prompt

```
Premium Italian farming game asset, stylized cartoon 2.5D, Tuscan countryside aesthetic, FarmVille 2 level quality, original artwork, chunky readable shapes, vibrant Mediterranean colors, terracotta roofs, olive trees, cypress trees, hand-painted shading, soft ambient occlusion, toy-like materials, highly readable at small scale, modular isometric tiles, warm sunlight, charming rural Italy atmosphere, polished casual game production quality, clean silhouettes, no text, transparent background.
```

"FarmVille 2 level quality" indica il livello di cura, non lo stile da
copiare: personaggi, edifici e oggetti devono essere originali.

## Fogli di sprite

- **Sfondo:** uniforme e chiaro (beige), oppure trasparente. Niente scritte vicino ai disegni.
  Se ci sono etichette, devono stare ben staccate (a sinistra o in alto).
- **Piante:** una riga per pianta e tre colonne per gli stadi: germoglio,
  crescita, maturazione. Ogni stadio sta sopra il proprio blocco di terra,
  nella stessa vista isometrica dei quadranti del gioco (rombo 2:1).
- **Icone:** una per cella, ben distanziate.
- **Sorgenti:** i fogli originali vanno in `assets/graphics/source/`; gli
  script in `tools/` ne ritagliano gli sprite.

## Palette di riferimento

- Terra coltivata: terracotta (#a8532e) con sassolini chiari.
- Erba: verde caldo e vivo (#8fb34a, #a5c45a).
- Legno: #9a6a3e. Tetti: coppi terracotta (#c0603e). Muri: sabbia (#f0d2a6).
- Interfaccia: crema (#fbf3e2), terracotta (#d0643c), verde oliva (#7c9a3c).
