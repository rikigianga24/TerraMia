# Terra Mia — Direzione audio e prompt

Campagna italiana rilassante, da ascoltare per ore. Il riferimento è l'atmosfera
dei giochi di fattoria e di villaggio "cozy", ma con un sapore italiano discreto.

**Da evitare sempre:** fisarmonica continua, mandolino stereotipato, musica
folcloristica esagerata, suoni realistici e fastidiosi.

**Strumenti:** chitarra acustica, pianoforte delicato, fisarmonica molto leggera,
contrabbasso pizzicato, flauto, campanellini (glockenspiel, celesta).

## Come usare i prompt

- I prompt sono in inglese perché gli strumenti AI li capiscono meglio.
- **Non scrivere nomi di giochi o di artisti** nei prompt: molti servizi li
  rifiutano, e comunque rischi di avere una copia. Le descrizioni qui sotto
  rendono già quell'atmosfera.
- **Musiche:** Suno o Udio, in modalità *Instrumental*. Generane 3-4 versioni e
  tieni la migliore. Per renderle un loop pulito, tagliale in Audacity
  (dissolvenza di pochi millisecondi all'inizio e alla fine).
- **Jingle, effetti, animali, ambienti:** ElevenLabs Sound Effects (fino a circa
  20 secondi) o Stable Audio. Genera più varianti e scegli.
- **Voci degli abitanti:** ElevenLabs (Voice Design per creare la voce, poi
  testo breve) oppure registrale tu o un amico. Vedi la sezione apposita.
- **Formato:** `.ogg` per musica e ambienti, `.ogg` o `.wav` per gli effetti.
  Mono a 44,1 kHz per gli effetti, stereo per musica e ambienti.
- **Volume:** normalizza tutto (per esempio -14 LUFS per la musica, -16/-18 per
  gli ambienti). Gli effetti non devono avere silenzio all'inizio.

### Udio: come ottenere buoni risultati

Udio funziona in modo diverso da Suno: i prompt lunghi e descrittivi lo
confondono. Ogni musica qui sotto ha una versione **Udio** a parte.

- **Prompt a tag**, separati da virgole, 8-15 tag al massimo. Prima il genere e
  il fatto che è per un gioco (`video game soundtrack, cozy game music`), poi gli
  strumenti, poi il mood, infine il tempo (`90 bpm`).
- **Niente frasi negative.** Udio non capisce "no drums" o "no mandolin": legge
  "drums" e "mandolin" e spesso li aggiunge. Scrivi solo quello che vuoi.
- **Modalità manuale** (Manual mode), così Udio non riscrive il prompt.
- **Strumentale** attivo. Se la tua versione lascia scrivere il testo anche in
  strumentale, metti solo i tag di struttura indicati (`[Intro]`, `[Outro]`...),
  senza parole.
- **Lavora a pezzi:** Udio genera clip brevi (circa 30 secondi). Generane 4-6,
  tieni la migliore e allungala con **Extend** (aggiungi una sezione alla volta),
  usando sempre lo stesso prompt.
- **Posizione d'inizio della clip** (Clip start, nelle impostazioni avanzate):
  0% se vuoi un vero inizio (menu); 30-50% per le musiche in loop, così il pezzo
  non suona come un'introduzione.
- **Prompt strength** alta (70-90%), così rispetta strumenti e mood.
- Se esce troppo "folk" o troppo pieno, togli tag invece di aggiungerne.

Cartelle: `assets/audio/music/`, `assets/audio/sfx/`, `assets/audio/ambience/`,
`assets/audio/voices/<abitante>/`.

---

## Musiche (4 tracce)

### Menu principale — `music/menu.ogg`
2-3 minuti, nostalgico e accogliente. Il messaggio è "Bentornato a casa".

```
Instrumental. Warm, nostalgic and welcoming theme for a cozy farming game main menu.
Gentle fingerpicked acoustic guitar and soft felt piano carry a simple, memorable
melody, with a light wooden flute answering it. Pizzicato upright bass, very soft
glockenspiel sparkles, a barely audible accordion pad in the background.
Italian countryside at golden hour, feeling of coming home after a long time.
Slow tempo around 75 BPM, major key with a touch of melancholy, intimate,
acoustic, warm analog recording. No drums, no vocals, no folk clichés.
Loopable, 2-3 minutes.
```

**Udio**
```
video game soundtrack, cozy game main menu theme, acoustic, fingerpicked acoustic guitar, soft felt piano, wooden flute, upright bass, glockenspiel, nostalgic, warm, welcoming, italian countryside, golden hour, 75 bpm
```
Testo (solo struttura): `[Intro]` `[Main Theme]` `[Bridge]` `[Main Theme]` `[Outro]`.
Clip start 0%. Allunga con Extend fino a 2-3 minuti, e chiudi con una sezione
Outro solo se non la usi in loop.

### Fattoria — `music/fattoria.ogg`
Sereno, produttivo, da ripetere per ore. 80-100 BPM. Melodia discreta.

```
Instrumental. Calm, steady background music for a relaxing farming game,
meant to be listened to for hours. Light acoustic guitar strumming pattern,
pizzicato upright bass, soft piano chords, occasional short flute phrases and
gentle glockenspiel. Sunny Italian countryside morning, peaceful and productive.
90 BPM, major key, simple repeating structure, the melody stays in the
background and never takes over. Very light brushed percussion or shaker only.
No accordion lead, no mandolin, no vocals. Seamless loop, about 3 minutes.
```

**Udio**
```
video game soundtrack, farming game background music, cozy, acoustic guitar, pizzicato upright bass, soft piano, flute, glockenspiel, shaker, peaceful, sunny morning, relaxed, minimal, 90 bpm
```
Testo (solo struttura): `[Instrumental]` `[Verse]` `[Instrumental Break]` `[Verse]`.
Clip start 40%. Allunga con Extend fino a circa 3 minuti, senza Outro: deve
girare in loop.

### Borgo — `music/borgo.ogg`
Più caldo e più umano. Qui la fisarmonica leggera e la chitarra danno personalità.

```
Instrumental. Warm, friendly theme for a small Italian hill village in a cozy
life-simulation game. Acoustic guitar with a gentle swing, a soft accordion
playing a short charming melody (light and sparse, not constant), pizzicato
upright bass, piano accents, a little flute and celesta. Feeling of neighbours
chatting in the piazza on a summer afternoon, human and welcoming.
95 BPM, major key, relaxed, acoustic, warm. No vocals, no exaggerated folk,
no tarantella. Seamless loop, about 3 minutes.
```

**Udio**
```
video game soundtrack, cozy village theme, acoustic guitar, light swing, soft accordion, pizzicato upright bass, piano, flute, celesta, warm, friendly, italian village piazza, summer afternoon, 95 bpm
```
Testo (solo struttura): `[Instrumental]` `[Verse]` `[Chorus]` `[Verse]`.
Clip start 40%. Allunga fino a circa 3 minuti, senza Outro. Se la fisarmonica
copre tutto, sostituisci `soft accordion` con `accordion accents`.

### Restauro edificio — `music/restauro.ogg`
10-15 secondi. Deve dare soddisfazione: una piccola fanfara giocosa.
(Meglio con ElevenLabs Sound Effects o Stable Audio, perché Suno fa brani più lunghi.)

```
Short triumphant celebration jingle for a cozy video game, 12 seconds.
A building has just been restored. Bright rising piano and glockenspiel
arpeggio, acoustic guitar strum, a cheerful flute melody, a soft accordion
chord swell and a final bright chime with a short warm reverb tail.
Joyful, rewarding, playful, orchestral-acoustic, major key, clear ending.
```

**Udio** (se vuoi provarci: genera una clip e tagliala a 12 secondi in Audacity)
```
video game soundtrack, victory fanfare, cozy game, short jingle, rising piano arpeggio, glockenspiel, acoustic guitar strum, cheerful flute, triumphant, joyful, major key, 120 bpm
```
Testo (solo struttura): `[Intro]` `[Outro]`. Clip start 0%.

---

## Jingle brevi

### Livello salito — `sfx/livello.ogg`
2-3 secondi. Il giocatore deve capire subito: "ho sbloccato qualcosa".

```
Short level-up jingle for a cozy game, 2.5 seconds. Quick ascending
glockenspiel and piano arpeggio ending on a bright sparkling chord with
a soft flute note. Cheerful, rewarding, clean, major key.
```

---

## Suoni della fattoria

Fai 3-4 varianti di ognuno: il gioco ne sceglie una a caso, così non stancano.

| File | Suono | Prompt |
|---|---|---|
| `sfx/pianta_1..3.wav` | "tup" corto | `Short soft "tup" sound of a seed pressed into soft soil, cartoon game sound, satisfying, warm, 0.3 seconds, no reverb` |
| `sfx/raccolta_1..3.wav` | "pop" vegetale | `Short juicy cartoon pop of a vegetable pulled from the ground with a tiny leafy rustle, satisfying, cozy game, 0.4 seconds` |
| `sfx/raccolta_foglie_1..3.wav` | "frrsh" | `Quick fresh leafy "frrsh" swish of picking herbs and leaves, soft and pleasant, cozy game sound, 0.4 seconds` |
| `sfx/monete_1..3.wav` | "cling" | `Bright pleasant coin "cling", two small coins touching, cozy game reward sound, sparkly but soft, 0.5 seconds` |
| `sfx/esperienza.wav` | "tin-din" crescente | `Two-note rising chime "tin-din", soft glockenspiel, gentle reward sound for a cozy game, 0.5 seconds` |

Altri utili da subito:

| File | Prompt |
|---|---|
| `sfx/click.wav` | `Soft wooden UI click, short and gentle, cozy game menu button, 0.1 seconds` |
| `sfx/zappa.wav` | `Soft hoe digging into dry earth, short cartoon thud with a little dirt crumble, 0.4 seconds` |
| `sfx/annaffia.wav` | `Short gentle watering can splash on soil, light and refreshing, cozy game, 0.8 seconds` |
| `sfx/ordine.wav` | `Small cheerful bell ding with paper rustle, delivery completed, cozy game, 0.8 seconds` |
| `sfx/errore.wav` | `Soft low wooden "bonk", gentle negative feedback, not harsh, cozy game, 0.3 seconds` |

---

## Animali

Niente realismo: versioni morbide, brevi e cartoonesche. 3 varianti ciascuno.

| File | Prompt |
|---|---|
| `sfx/gallina_1..3.wav` | `Single soft cute cartoon hen cluck, short, rounded and gentle, cozy game, not realistic, 0.4 seconds` |
| `sfx/mucca_1..3.wav` | `Short gentle cartoon cow moo, almost musical, soft and friendly, cozy game, not realistic, 1 second` |
| `sfx/pecora_1..3.wav` | `Short soft cute cartoon sheep baa, light and friendly, cozy game, not realistic, 0.7 seconds` |
| `sfx/cane_1..3.wav` | `Single happy small dog bark, cheerful and playful, cartoon style, cozy game, 0.3 seconds` |

---

## Ambienti (loop, volume bassissimo)

Generali da 20 secondi e uniscili con dissolvenze incrociate in Audacity per avere
un loop di 1-2 minuti.

### Fattoria — `ambience/fattoria.ogg`
```
Peaceful Italian countryside summer ambience, distant songbirds, gentle wind
through grass and olive leaves, soft rustling, faint cicadas in the distance.
Calm, sparse, no people, no music, seamless loop.
```

### Borgo — `ambience/borgo.ogg`
```
Quiet small Italian village piazza ambience on a summer afternoon, soft
trickling stone fountain, distant indistinct murmur of people chatting,
a few swallows, very far church bells. Calm and sparse, no music, seamless loop.
```

Suoni rari da far partire ogni tanto, separati dal loop:

| File | Prompt |
|---|---|
| `ambience/campane.ogg` | `Distant church bells ringing in an Italian hill village, heard from far away, soft, 8 seconds` |
| `ambience/vespa.ogg` | `Small vintage scooter passing by on a cobblestone street in the distance, from left to right, 5 seconds` |

---

## Voci degli abitanti (gibberish)

Niente frasi complete: per ogni abitante circa **10 clip brevi** (0,2-0,8 s).
Il gioco le mescola ("Eh-mm-mamma-mia-oh!") e varia leggermente l'intonazione.

**Come registrarle:**
- Con ElevenLabs: crea la voce con *Voice Design* usando la descrizione qui sotto,
  poi genera ogni parola da sola, con stabilità bassa per avere più espressività.
- Oppure registrale tu: telefono vicino alla bocca, stanza silenziosa, ogni clip
  in un file separato, poi tagli il silenzio in Audacity.

| Abitante | Descrizione voce (Voice Design) | Clip |
|---|---|---|
| Gino | `Elderly Italian man, deep warm gravelly voice, friendly farmer, speaks slowly` | "mmm", "eh", "mamma mia", "oh", "beh", "ah", "sì sì", "ehh", "uhm", "va bene" |
| Rosa | `Cheerful Italian woman in her forties, bright higher-pitched voice, warm and affectionate` | "tesoro", "ohh", "mmm", "ah!", "sì", "che bello", "eh", "oh oh", "brava", "dai" |
| Nonna Pina | `Very old Italian grandmother, thin shaky gentle voice, loving and a bit bossy` | "mangia", "eh eh", "ma dai", "oh", "mmm", "su", "bello", "ah", "uh", "figlio mio" |
| Beppe | `Young Italian postman, quick energetic voice, always in a hurry` | "arrivo", "eh", "oh", "ecco", "via", "ah", "sì", "ops", "allora", "ciao" |
| Zia Carmela | `Middle-aged Italian woman, lively gossiping voice, half whispering, curious` | "senti", "eh", "mmm", "ma no", "ohh", "pss", "sai", "ah", "uh", "davvero" |

File: `voices/gino/01.wav` ... `voices/gino/10.wav`, e così per gli altri.
