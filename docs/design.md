> Copia di riferimento del documento di design (Claude Docs, rev 23, 2026-11-12). Se cambia il documento online, vale quello.


# Terra Mia — Documento di design

2026-11-12 · Riccardo


## Concept

Terra Mia è un gioco di fattoria a quadranti in cui, coltivando e allevando, riporti in vita un borgo italiano abbandonato.

- **Tema:** campagna italiana. Pomodori, grano, ulivi, uva; olio, vino, pane, pasta, formaggio. È quello che lo distingue dai mille idle farm generici.
- **Piattaforme:** prima browser (CrazyGames, Poki), poi Steam e mobile con lo stesso progetto Godot.
- **Giocatore tipo:** chi cerca un gioco tranquillo, da sessioni di 5–10 minuti più volte al giorno.
- **Obiettivo economico:** 1.000–2.000 € al mese.
- **Vincolo:** resta un progetto piccolo. Single-player, niente multiplayer, manutenzione di poche ore a settimana.


## Ciclo di gioco

_[diagramma: ciclo di gioco · 6 passi]_

Il giocatore coltiva per consegnare ordini, e con le monete restaura il borgo. Ogni restauro sblocca produzioni nuove, quindi il giro dopo è più ricco del precedente.


## Fattoria

La fattoria è una griglia isometrica che parte da 6×6 quadranti e si allarga comprando nuovi terreni. Ogni quadrante ospita una coltura, un albero, un recinto o una decorazione.

Colture, alberi e animali, in ordine di sblocco. Tempi e livelli sono una proposta da bilanciare con i test; il prototipo usa solo grano e pomodori.

| Elemento | Tipo | Tempo | Produce | Si sblocca |
| --- | --- | --- | --- | --- |
| Grano | coltura | 2 min | grano | subito |
| Lattuga | coltura | 5 min | lattuga | subito |
| Pomodoro | coltura | 10 min | pomodori | subito |
| Carota | coltura | 15 min | carote | livello 2 |
| Basilico | coltura | 30 min | basilico | livello 2 |
| Gallina | animale | 20 min | uova | livello 3 |
| Fragola | coltura | 40 min | fragole | livello 3 |
| Zucchina | coltura | 45 min | zucchine | livello 3 |
| Cipolla | coltura | 25 min | cipolle | livello 4 |
| Carciofo | coltura | 1 ora | carciofi | livello 4 |
| Ulivo | albero, resta piantato | 4 ore | olive | livello 4 |
| Mucca | animale | 1 ora | latte | livello 5 |
| Patata | coltura | 1 ora | patate | livello 5 |
| Melanzana | coltura | 1,5 ore | melanzane | livello 5 |
| Rovo di more | arbusto, resta piantato | 2 ore | more | livello 5 |
| Aglio | coltura | 1 ora | aglio | livello 6 |
| Peperoncino | coltura | 2 ore | peperoncini | livello 6 |
| Vite | albero, resta piantato | 8 ore | uva | livello 6 |
| Rucola | coltura | 20 min | rucola | livello 7 |
| Fagioli | coltura | 1,5 ore | fagioli | livello 7 |
| Fico | albero, resta piantato | 6 ore | fichi | livello 7 |
| Finocchio | coltura | 2 ore | finocchi | livello 8 |
| Rosmarino | arbusto, resta piantato | 3 ore | rosmarino | livello 8 |
| Nocciolo | albero, resta piantato | 10 ore | nocciole | livello 8 |
| Origano | coltura | 1 ora | origano | livello 9 |
| Zucca | coltura | 3 ore | zucche | livello 9 |
| Castagno | albero, resta piantato | 12 ore | castagne | livello 9 |
| Ciliegio | albero, resta piantato | 8 ore | ciliegie | livello 10 |
| Mandorlo | albero, resta piantato | 12 ore | mandorle | livello 10 |
| Anguria | coltura | 4 ore | angurie | livello 11 |
| Pesco | albero, resta piantato | 8 ore | pesche | livello 11 |
| Arancio | albero, resta piantato | 10 ore | arance | livello 12 |
| Zafferano | coltura rara | 1 giorno | zafferano | livello 12 |
| Pistacchio | albero raro, resta piantato | 1 giorno | pistacchi | livello 13 |

- Le colture si ripiantano a ogni raccolto; alberi e animali producono a ciclo continuo.
- Gli animali vanno nutriti con grano: è il primo collegamento tra campi e stalle.
- Il tempo scorre anche a gioco chiuso: al rientro si calcola il tempo passato e si applica in un colpo.


## Il borgo

Accanto alla fattoria c'è un borgo in rovina. Ogni edificio si restaura consegnando prodotti e monete, e una volta restaurato riporta un abitante e sblocca una nuova produzione.

| Edificio | Abitante | Trasforma | In | Livello |
| --- | --- | --- | --- | --- |
| Mulino | Gino, il mugnaio | grano | farina | 2 |
| Forno | Rosa, la fornaia | farina + uova | pane | 4 |
| Ufficio postale | Beppe, il postino | — | sblocca il carretto della città | 4 |
| Frantoio | Aldo, il frantoiano | olive | olio | 5 |
| Bottega delle conserve | Zia Carmela | pomodori, melanzane, peperoncini | passata e sottoli | 5 |
| Caseificio | Mario, il casaro | latte | formaggio | 6 |
| Cantina | Sergio, il vignaiolo | uva | vino | 7 |
| Gelateria | Luigi, il gelataio | latte + more o fichi | gelato | 7 |
| Pastificio | Nonna Pina | farina + uova | pasta | 8 |
| Campanile | Don Peppino, il parroco | — | sblocca le sagre stagionali | 8 |
| Bar della piazza | Totò, il barista | chicchi di caffè, latte, farina + uova | espresso, cappuccino e cornetti | 9 |
| Osteria | Franco, l'oste | pasta + pomodori + basilico | piatti per gli ordini migliori | 10 |
| Pasticceria | Lucia, la pasticcera | mandorle + nocciole + uova | cantucci e torrone | 11 |
| Caldarroste in piazza | Il caldarrostaio | castagne | caldarroste | 11 |
| Campo da bocce | I nonni del paese | — | bonus giornaliero di monete | 12 |

- Ogni abitante ha un nome, due battute di carattere e manda ordini legati al suo mestiere.
- Le filiere si allungano col tempo: dal grano alla farina, alla pasta, al piatto dell'osteria.
- La piazza al centro si decora con fontana, panchine, lampioni e fioriere.


## Ricette

Ogni coltura finisce almeno in una ricetta: le ricette sono gli ordini che rendono di più e danno un motivo per coltivare tutto.

| Piatto | Dove | Ingredienti |
| --- | --- | --- |
| Insalata mista | Osteria | lattuga, carote, pomodori, olio |
| Pizza margherita | Forno | farina, pomodori, formaggio, basilico |
| Pizza marinara | Forno | farina, pomodori, aglio, origano |
| Focaccia al rosmarino | Forno | farina, olio, rosmarino |
| Patate al forno | Forno | patate, rosmarino, olio |
| Confettura di fragole | Bottega delle conserve | fragole |
| Pesto alla trapanese | Bottega delle conserve | basilico, mandorle, pomodori, aglio |
| Minestrone | Osteria | zucchine, carote, patate, fagioli, cipolle |
| Carciofi alla romana | Osteria | carciofi, aglio, olio |
| Pasta aglio, olio e peperoncino | Osteria | pasta, aglio, olio, peperoncini |
| Insalata di rucola | Osteria | rucola, pomodori, formaggio |
| Insalata di finocchi e arance | Osteria | finocchi, arance, olio |
| Tortelli di zucca | Pastificio | pasta, zucche, formaggio |
| Tagliatelle al tartufo | Osteria | pasta, tartufo, formaggio |
| Castagnaccio | Pasticceria | castagne, rosmarino, olio |
| Crostata di ciliegie | Pasticceria | farina, uova, ciliegie |
| Crostata di pesche | Pasticceria | farina, uova, pesche |
| Crema di pistacchio | Pasticceria | pistacchi, latte |
| Granita all'arancia | Bar della piazza | arance |
| Sorbetto all'anguria | Gelateria | angurie |
| Gelato al pistacchio | Gelateria | latte, pistacchi |


## Gli abitanti

Gli abitanti sono caricature affettuose dell'italiano di paese e parlano in gibberish italianeggiante, come i personaggi di Animal Crossing. Il fumetto mostra la traduzione nella lingua del giocatore, quindi il gioco funziona anche all'estero.

**Come parlano**

- Ogni frase è un flusso di sillabe che suonano italiane, con una tonalità diversa per ogni abitante.
- Ogni tanto spunta una parola vera e riconoscibile: "Mamma mia!", "Allora...", "Ma dai!", "Perfetto!", "Mangia!".
- Costa poco da fare: 8–12 sillabe registrate per voce, montate a caso dal gioco e alzate o abbassate di tono.

**Chi sono**

| Abitante | Il suo cliché | Frase tipica |
| --- | --- | --- |
| Gino, il mugnaio | baffoni, si lamenta sempre del tempo | "Piove? Non piove? Mamma mia!" |
| Rosa, la fornaia | ti chiama "tesoro" e ti regala il pane | "Tesoro, sei pallido!" |
| Beppe, il postino | sempre in ritardo, gira in Vespa | "Arrivo, arrivo!" |
| Zia Carmela | sa tutti i pettegolezzi del borgo | "Non l'hai sentito da me, eh..." |
| Luigi, il gelataio | canta mentre lavora | "Gelato! Gelatooo!" |
| Nonna Pina | pensa che tu sia sempre troppo magro | "Mangia! Sei pelle e ossa!" |
| Don Peppino, il parroco | suona le campane sempre in ritardo | "Il Signore aspetta, ma io no." |
| Totò, il barista | gesticola e parla solo di calcio | "Hai visto la partita?!" |
| Franco, l'oste | offeso da chi mette il ketchup sulla pasta | "Ketchup? In casa mia?!" |
| I nonni del paese | giocano a bocce e commentano tutto | "Ai miei tempi..." |

- Gesti tipici nelle animazioni: mano a borsa, braccia al cielo, pacca sulla spalla.
- Il tono resta affettuoso: gli abitanti ridono di sé, nessuno è cattivo o ridicolo in modo offensivo.


## Navigazione e vita nel borgo

Fattoria e borgo sono due scene separate: due pulsanti fissi in basso, Fattoria e Borgo, e un secondo di transizione col carretto sulla strada.

- **Fattoria:** griglia libera, il giocatore piazza colture, alberi e recinti dove vuole.
- **Borgo:** disegno fisso, con la piazza al centro, gli edifici attorno e la strada verso la fattoria. Ogni restauro trasforma l'edificio sul posto, da rudere a bottega.
- **Routine degli abitanti** legata all'ora reale: la mattina al bar, a pranzo nelle botteghe, la sera in piazza e i nonni alle bocce.
- **Tocchi un abitante** e ti parla in gibberish, ti dà un ordine o ti chiede un caffè.
- **Visite in fattoria:** Beppe porta la posta, Nonna Pina passa a lasciare un regalo.

**Regola:** il giocatore non è mai costretto ad andare avanti e indietro. Il pulsante Borgo mostra un pallino quando c'è qualcosa da fare, e la bacheca degli ordini si apre anche dalla fattoria.


## Economia e progressione

Le monete si guadagnano con gli ordini e si spendono in semi, terreni e restauri; l'esperienza fa salire di livello e sblocca contenuti.

- **Monete:** la valuta normale, da ordini e vendite.
- **Lire d'oro****:** la valuta rara, vecchie lire d'oro da collezione. Si ottengono salendo di livello, dalle sagre e coi video premio; si usano per accelerare la produzione e per le decorazioni speciali.
- **Esperienza e livelli:** ogni livello sblocca una coltura, un animale o un edificio da restaurare.
- **Bacheca degli ordini:** in piazza ci sono 3–6 ordini degli abitanti. Completarli dà monete ed esperienza, e ogni ordine completato ne fa arrivare uno nuovo.
- **Il carretto:** ogni tanto arriva un ordine grande dalla città con una scadenza di qualche ora. Rende molto di più degli ordini normali.
- **Spazio:** magazzino e silo hanno una capienza che si amplia, così il giocatore deve scegliere cosa produrre.


## L'espresso

L'espresso è l'energia del gioco: non serve per coltivare, ma per le azioni speciali. Così il gioco base non si blocca mai, e il caffè è il di più.

**Come si ottiene**

- **La moka di casa:** 1 espresso ogni 2 ore, gratis, fino a un massimo di 3.
- **Il bar della piazza:** fa espressi in quantità con i chicchi di caffè, che arrivano col carretto della città o come premio degli ordini.
- **Video premio, livelli e sagre:** qualche tazzina in regalo.

**Cosa ci fai**

| Azione | Costo | Effetto |
| --- | --- | --- |
| Pausa caffè con un abitante | 1 espresso | il suo edificio produce più veloce per un'ora |
| Ripulire il terreno | 1 espresso | togli sassi, rovi e ceppi, allarghi la fattoria e a volte trovi monete |
| Raccolto di squadra | 1 espresso | raccogli tutta la fattoria con un tocco |
| Caccia al tartufo nel bosco | 2 espressi | col cane trovi tartufi, ingrediente raro per l'osteria |
| Mercato in città | 2 espressi | vendi un carico di prodotti a prezzo più alto |

L'espresso non si vende a pacchi: si ottiene giocando o coi video premio, così non diventa "paga per giocare".


## Sagre stagionali

Ogni 3–4 settimane parte una sagra di circa 10 giorni: ordini a tema, una coltura speciale e decorazioni esclusive. Coincidono con gli aggiornamenti, quindi ogni sagra è anche il contenuto nuovo del mese.

| Sagra | Stagione | Coltura speciale | Premio esclusivo |
| --- | --- | --- | --- |
| Sagra dell'uva | autunno | uva fragola | botte decorativa |
| Mercatino di Natale | dicembre | melograni | albero di Natale in piazza |
| Carnevale | febbraio | — | maschere e coriandoli |
| Sagra dei fiori | primavera | girasoli | aiuola fiorita |
| Sagra del limone | estate | limoni | pergolato di limoni |


## Monetizzazione

Si parte solo con la pubblicità e si aggiungono gli acquisti quando il gioco trattiene i giocatori. Regola fissa: niente è bloccato dietro un pagamento, si paga solo per comodità o estetica.

**Fase 1 — lancio su browser**

- Video premio a scelta del giocatore: raccolto pronto subito, ordine raddoppiato, Lire d'oro, un espresso.
- Interstiziali solo nelle pause naturali (dopo un livello), mai durante il gioco.

**Fase 2 — quando i numeri tengono**

- "Rimuovi pubblicità" una tantum a 3–5 €.
- Decorazioni per piazza e fattoria.
- Starter pack a prezzo basso per i nuovi giocatori.
- Terreni e slot di produzione in più.

Da evitare: il "paga per saltare l'attesa" spinto. Per quello ci sono i video premio.


## I primi 15 minuti

In 15 minuti il giocatore deve aver raccolto, completato un ordine e restaurato il primo edificio, così capisce il gioco e ha un motivo per tornare.

1. **Arrivo (0–1 min).** Una lettera dello zio: ti lascia la terra e il borgo vicino, ormai abbandonato. Titolo: Terra Mia.
2. **Primo raccolto (1–4 min).** Il tutorial fa piantare grano su 4 quadranti; cresce in 2 minuti. Si raccoglie e si piantano pomodori.
3. **Primo ordine (4–7 min).** Compare la bacheca con un ordine facile. Consegnandolo arrivano le prime monete e il livello 2.
4. **Primo video premio (7–9 min).** I pomodori impiegano 10 minuti: si propone il video per farli crescere subito, senza obbligo.
5. **Primo restauro (9–14 min).** Monete e grano bastano per il mulino. Torna il mugnaio e sblocca la farina.
6. **Il gancio (14–15 min).** Il mugnaio lascia un ordine grande per domani e si vede il forno in rovina: è il motivo per tornare.


## Tecnologia, roadmap e fuori scopo

**Tecnologia:** Godot 4 con export HTML5 per i portali, poi Steam e mobile dallo stesso progetto. Nel prototipo i salvataggi sono locali; Supabase arriva solo con gli acquisti in-app.

**Roadmap del prototipo**

- [ ] Griglia isometrica, piantare e raccogliere grano e pomodori
- [ ] Timer reali e progresso offline
- [ ] Bacheca ordini, monete, esperienza e livelli 1–3
- [ ] Mulino restaurabile con il mugnaio
- [ ] Tutorial dei primi 15 minuti
- [ ] Grafica SVG provvisoria e audio di base
- [ ] SDK CrazyGames con video premio
- [ ] Pubblicazione su CrazyGames e due settimane di dati

Si va avanti solo se i giocatori tornano il giorno dopo; la soglia esatta si decide guardando i primi dati.

**Fuori scopo per ora:** multiplayer, visite tra amici, scambi tra giocatori, classifiche, chat.

