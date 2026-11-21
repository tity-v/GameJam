extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var room=load("res://scenes/levels/chapter_01_room_04.tscn").instantiate()
 root.add_child(room)
 current_scene=room
 await physics_frame
 var echo=load("res://scenes/echo/echo.tscn").instantiate()
 room.add_child(echo)
 var trail=PackedVector2Array()
 for i in 31: trail.append(Vector2(680, 550-i*4))
 echo.setup(trail)
 echo.reset()
 for i in 30:
  await physics_frame
  echo.advance(1.0/60.0)
 print("EXPECTED ",trail[-1]," ACTUAL ",echo.global_position)
 quit(0 if echo.global_position.distance_to(trail[-1])<1 else 1)
