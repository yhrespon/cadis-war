class_name WeaponDef
extends Resource
## Définition d'une arme (ressource .tres). Tout le gameplay d'arme lit ces valeurs.

@export var id := "pistol"
@export var display_name := "Pistolet"
@export var model := "pistol"          # pistol | smg | shotgun | bat
@export var melee := false
@export var damage := 25.0              # par balle (ou par plomb)
@export var pellets := 1
@export var rate := 3.0                 # tirs par seconde
@export var auto_fire := false
@export var range_m := 60.0
@export var spread_deg := 1.0           # dispersion de base (degrés)
@export var spread_move := 1.5          # dispersion ajoutée en mouvement
@export var aim_spread_mult := 0.4      # multiplicateur en visée (ADS)
@export var recoil_deg := 1.2           # recul vertical par tir (caméra)
@export var mag_size := 12
@export var ammo_type := "9mm"
@export var noise_radius := 45.0        # rayon sonore (alerte IA)
@export var price := 0
@export var fov_aim := 48.0
