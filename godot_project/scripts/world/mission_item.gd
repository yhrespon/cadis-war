class_name MissionItem
extends Node3D
## Marqueur d'objectif interactif. kind = "collect" (objet à ramasser) | "talk" (contact à qui parler).
## Utilisé par MissionManager. interact() -> MissionManager.report_item(state) -> progression de l'objectif.
## « talk » est un MARQUEUR TEMPORAIRE (colonne lumineuse) : le vrai PNJ (personnage fourni, 1,75 m) reste à brancher.
## [NON TESTÉ]

var kind := "collect"
var label := ""
var state: Dictionary = {}
var prompt := ""
var interact_range := 1.8

func _ready() -> void:
	add_to_group("interactable")
	prompt = ("Ramasser : %s" % label) if kind == "collect" else ("Parler à %s" % label)
	var m := MeshInstance3D.new()
	var col := Color(1.0, 0.85, 0.2) if kind == "collect" else Color(0.3, 0.7, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.4
	if kind == "collect":
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 0.25, 0.25)    # petit colis tenu à une main (adulte 1,75 m)
		m.mesh = b
		m.position = Vector3(0, 0.55, 0)
	else:
		var c := CylinderMesh.new()
		c.top_radius = 0.25
		c.bottom_radius = 0.25
		c.height = 2.4
		m.mesh = c
		m.position = Vector3(0, 1.2, 0)
		mat.albedo_color.a = 0.45
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)

func _process(dt: float) -> void:
	if kind == "collect":
		rotate_y(dt * 1.5)

func interact(_p: Node) -> void:
	MissionManager.report_item(state)
	if kind == "collect" or bool(state.get("done", false)):
		queue_free()
