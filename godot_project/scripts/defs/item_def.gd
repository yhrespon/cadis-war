class_name ItemDef
extends Resource
## Objet de magasin / inventaire. category : weapon | ammo | top | bottom | hair | heal | armor

@export var id := ""
@export var display_name := ""
@export var category := "weapon"
@export var price := 100
@export var ref_id := ""                # weapon : id d'arme ; ammo : type de munition
@export var amount := 0                 # ammo : quantité ; heal/armor : points
@export var color := Color.WHITE        # vêtements : couleur appliquée à la pastille d'atlas
@export_multiline var description := ""
