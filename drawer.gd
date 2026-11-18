extends Node2D
## Draws through a callback, so main.gd can paint the glow layer and the HUD.

var fn: Callable


func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
