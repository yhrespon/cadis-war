class_name CityDef
extends Resource
## Ville procédurale par blocs/secteurs. Tout est dimensionné pour des personnages de 1,75 m.

@export var id := "port_alpha"
@export var display_name := "Port-Alpha"
@export var seed_value := 1
@export var blocks_x := 6
@export var blocks_z := 6
@export var block_size := 46.0
@export var road_width := 11.0           # 2 voies de 3,4 m + trottoirs de 2,1 m
@export var floors_min := 2
@export var floors_max := 5
@export var industrial := false
@export var wall_color := Color(0.62, 0.58, 0.52)
@export var wall_color_b := Color(0.55, 0.5, 0.46)
@export var roof_color := Color(0.32, 0.3, 0.3)
@export var road_color := Color(0.17, 0.17, 0.19)
@export var ground_color := Color(0.38, 0.4, 0.36)
@export var sky_color := Color(0.55, 0.65, 0.78)
@export var civilians := 10
@export var traffic := 4
@export var pois: Dictionary = {}        # nom -> Vector2i(bloc x, bloc z)
