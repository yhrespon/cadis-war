class_name VehicleDef
extends Resource
## Définition d'un véhicule (taille à l'échelle des personnages : adulte 1,75 m).

@export var id := "sedan"
@export var display_name := "Berline"
@export var size := Vector3(1.8, 0.62, 4.2)      # carrosserie L x H x Lg
@export var body_color := Color(0.7, 0.1, 0.1)
@export var cabin_height := 0.55
@export var max_speed := 22.0
@export var max_reverse := 6.0
@export var accel := 9.0
@export var brake_force := 24.0
@export var steer_rate := 1.7
@export var max_hp := 220.0
@export var seat_x := 0.4
@export var seat_y := 0.62                       # hauteur du dessus de l'assise
@export var seat_z := -0.3
@export var price := 0
