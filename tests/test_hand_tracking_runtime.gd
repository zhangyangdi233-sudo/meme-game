extends SceneTree

const ReceiverScript = preload("res://framework/integrations/hand_tracking_receiver.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("BABEL_TEST_CAMERA_RUNTIME") != "1":
		print("hand tracking runtime test skipped; set BABEL_TEST_CAMERA_RUNTIME=1 to access the camera")
		quit(0)
		return
	var receiver = ReceiverScript.new()
	receiver.port = 17842
	var requested_source := OS.get_environment("BABEL_TEST_CAMERA_SOURCE")
	receiver.camera_source = requested_source if requested_source in ["computer", "phone"] else "computer"
	if not receiver.start(true):
		push_error("runtime receiver could not bind localhost UDP port")
		quit(1)
		return
	for _attempt in 180:
		receiver.poll()
		if not receiver.get_last_frame().is_empty():
			break
		await create_timer(0.02).timeout
	receiver.poll()
	var frame: Dictionary = receiver.get_last_frame()
	var status := receiver.get_status()
	receiver.stop()
	if frame.is_empty():
		push_error("MediaPipe sidecar produced neither landmarks nor a camera status packet")
		quit(1)
		return
	if status not in ["等待手部进入画面", "已收到手部关键点", "摄像头不可用或权限被拒绝"]:
		push_error("unexpected runtime hand-tracking status: %s" % status)
		quit(1)
		return
	print("hand tracking runtime bridge passed with status: ", status)
	quit(0)
