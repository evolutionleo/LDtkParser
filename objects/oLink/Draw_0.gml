/// @desc

draw_self()

draw_set_color(c_yellow)

for(var i = 0; i < array_length(points); i++) {
	draw_arrow(x, y, points[i].x, points[i].y, 5)
}

draw_set_color(c_white)

if (instance_exists(p) and p != noone) {
	draw_arrow(x, y, p.x, p.y, 10)
}