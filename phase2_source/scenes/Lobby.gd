extends Control
var salon_code: String = ""
var max_players: int = 2
var avec_ia: bool = false
func _on_creer_salon_pressed():
    salon_code = "CADIS-%04d" % (randi() % 9000 + 1000)
    $CodeLabel.text = salon_code
    print("SALON CREE: " + salon_code + " Joueurs:" + str(max_players) + " IA:" + str(avec_ia))
func _on_rejoindre_pressed():
    print("JOIN CODE: " + $JoinInput.text)
func _on_slider_value_changed(value):
    max_players = int(value)
func _on_ia_toggled(pressed):
    avec_ia = pressed
