extends Control
func _on_profil_pressed(): print("PROFIL OFFLINE_LOCAL")
func _on_arsenal_pressed(): print("ARSENAL OFFLINE_LOCAL")
func _on_jouer_pressed(): get_tree().change_scene_to_file("res://level/level.tscn")
func _on_multi_pressed(): get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
func _on_carte_pressed(): print("CARTE OFFLINE_LOCAL Ville/Maisons/Routes/Zones Militaires")
func _on_online_pressed(): OS.shell_open("https://arcadiax.up.railway.app/")
func _on_parametres_pressed(): print("PARAMETRES")
func _on_quit_pressed(): get_tree().quit()
