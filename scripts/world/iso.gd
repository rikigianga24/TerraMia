class_name Iso
extends RefCounted
## Forma del quadrante isometrico, la stessa per fattoria e borgo.
##
## Rapporto 2:1 (isometria classica, circa 26,6 gradi), come gli edifici del
## nuovo stile (assets/graphics/source/edifici): così mattonelle ed edifici
## hanno lo stesso angolo. Le mattonelle in assets/graphics/tiles sono a doppia
## risoluzione (240x120): vedi tools/cut_sprites.py e tools/import_flux.py.

const TILE_W := 120.0
const TILE_H := 60.0
