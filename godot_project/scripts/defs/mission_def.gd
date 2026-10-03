class_name MissionDef
extends Resource
## Mission (ressource .tres). objectives : liste de dictionnaires, voir mission_manager.gd (types d'objectifs).

@export var id := ""
@export var title := ""
@export var category := "main"            # main | contract | side
@export var mission_type := "elimination"  # libellé (élimination, livraison, escorte...)
@export var city := "port_alpha"
@export var giver := ""
@export_multiline var briefing := ""
@export var requires: Array = []          # ids de missions à terminer avant
@export var time_limit := 0.0             # 0 = pas de limite
@export var reward_money := 500
@export var reward_item := ""             # id d'objet offert (optionnel)
@export var unlocks_city := ""            # ville débloquée à la réussite
@export var fail_on_death := true
@export var objectives: Array = []
