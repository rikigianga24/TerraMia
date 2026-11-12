class_name FarmerDrawer
extends RefCounted
## Disegno del contadino, condiviso da fattoria e borgo.
## action: "" (fermo o in cammino), "hoe" (zappa), "sow" (semina).

const WOOD := Color("9a6a3e")
const SHADOW := Color(0.18, 0.12, 0.05, 0.28)


static func draw(ci: CanvasItem, p: Vector2, clock: float, walking: bool, action: String, flip: bool, action_t := 0.0) -> void:
	var bob := absf(sin(clock * 10.0)) * -3.0 if walking else 0.0
	var step := sin(clock * 10.0) * 4.0 if walking else 0.0
	var dir := -1.0 if flip else 1.0
	var bend := 0.0
	if action == "sow":
		bend = sin(clamp(action_t, 0.0, 1.0) * PI) * 4.0  # si china per seminare
	# ombra
	ci.draw_set_transform(p + Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, 16.0, SHADOW)
	ci.draw_set_transform(Vector2.ZERO)
	# gambe (pantaloni blu) e scarponi
	ci.draw_line(p + Vector2(-4, -2 + step * 0.3), p + Vector2(-4, -16 + bob), Color("34507a"), 6.0)
	ci.draw_line(p + Vector2(4, -2 - step * 0.3), p + Vector2(4, -16 + bob), Color("2c4569"), 6.0)
	ci.draw_circle(p + Vector2(-4 + step * 0.5, 0), 3.5, Color("5a3a22"))
	ci.draw_circle(p + Vector2(4 - step * 0.5, 0), 3.5, Color("4a2e1a"))
	# camicia rossa con bretelle
	var torso := Rect2(p + Vector2(-10 + bend * dir, -38 + bob + bend), Vector2(20, 24))
	ci.draw_rect(torso, Color("c8463a"))
	ci.draw_rect(Rect2(torso.position, Vector2(10, 24)), Color("d65a4a"))
	ci.draw_line(torso.position + Vector2(5, 0), torso.position + Vector2(5, 24), Color("34507a"), 3.0)
	ci.draw_line(torso.position + Vector2(15, 0), torso.position + Vector2(15, 24), Color("34507a"), 3.0)
	# testa, baffi, cappello di paglia
	var head := p + Vector2(bend * 1.5 * dir, -47 + bob + bend * 1.5)
	ci.draw_circle(head, 9.0, Color("f0c9a0"))
	ci.draw_circle(head + Vector2(3 * dir, -1), 1.6, Color("3b2a17"))
	ci.draw_line(head + Vector2(-5 + 3 * dir, 4), head + Vector2(5 + 3 * dir, 4), Color("5a3a22"), 3.0)
	ci.draw_set_transform(head + Vector2(0, -7), 0.0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, 17.0, Color("d9b45a"))
	ci.draw_circle(Vector2.ZERO, 15.0, Color("e8c870"))
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_rect(Rect2(head + Vector2(-8, -16), Vector2(16, 9)), Color("e8c870"))
	ci.draw_rect(Rect2(head + Vector2(-8, -9), Vector2(16, 3)), Color("c0503a"))
	var hand := p + Vector2(10 * dir + bend * dir, -28 + bob + bend)
	match action:
		"hoe":
			# la zappa si alza e batte; a ogni colpo saltano le zolle
			var swing := sin(clock * 5.0) * 0.5 + 0.5
			var angle := lerpf(-1.2, 0.6, swing)
			var tip := hand + Vector2(cos(angle) * 30 * dir, sin(angle) * 30)
			ci.draw_line(hand, tip, WOOD, 3.5)
			ci.draw_line(tip, tip + Vector2(7 * dir, 8).rotated(angle * 0.3 * dir), Color("8e9aa6"), 5.0)
			ci.draw_circle(hand, 3.5, Color("f0c9a0"))
			if swing > 0.85:
				for i in 3:
					var o := Vector2((i - 1) * 6.0 * dir + 34 * dir, -6 - (swing - 0.85) * 60.0 - i * 2.0)
					ci.draw_circle(p + o, 2.2, Color("7a5230"))
		"sow":
			# sacchetto sotto il braccio, mano che lancia i semi a ventaglio
			ci.draw_circle(p + Vector2(-9 * dir, -24 + bob + bend), 7.0, Color("d7b98a"))
			ci.draw_circle(p + Vector2(-9 * dir, -30 + bob + bend), 3.0, Color("b8975f"))
			var throw := hand + Vector2(10 * dir, -6 + action_t * 10.0)
			ci.draw_line(hand, throw, Color("f0c9a0"), 4.0)
			for i in 6:
				var k := float(i) / 5.0
				var fall := clampf(action_t * 1.6 - k * 0.4, 0.0, 1.0)
				var seed_pos := throw + Vector2((k - 0.5) * 34.0 * dir + 10 * dir, fall * 26.0 + (k - 0.5) * 4.0)
				ci.draw_circle(seed_pos, 2.0, Color("8a5a2b"))
		_:
			# zappa in spalla
			var tip := hand + Vector2(cos(0.9) * 30 * dir, sin(0.9) * 30)
			ci.draw_line(hand, tip, WOOD, 3.5)
			ci.draw_line(tip, tip + Vector2(7 * dir, 8), Color("8e9aa6"), 5.0)
			ci.draw_circle(hand, 3.5, Color("f0c9a0"))
