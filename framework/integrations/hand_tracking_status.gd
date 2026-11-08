class_name HandTrackingStatus
extends RefCounted
## Typed hand-tracking lifecycle states. Logic compares enum values; UI uses display_text().

enum Status {
	DISABLED,
	PORT_UNAVAILABLE,
	STARTING,
	WAITING_FOR_HANDS,
	WAITING_FOR_DATA,
	PROTOCOL_MISMATCH,
	PERMISSION_DENIED,
	TRACKER_ERROR,
	RECEIVING_LANDMARKS,
	MISSING_HELPER,
	MISSING_MODEL,
	MISSING_MEDIAPIPE,
	SIDECAR_LAUNCH_FAILED,
	FINGERTIP_WINDOW_LOCKED,
	WAITING_FOR_FOUR_FINGERTIP_FRAME,
}

const _DISPLAY_TEXT := {
	Status.DISABLED: "摄像头未启用",
	Status.PORT_UNAVAILABLE: "手部追踪端口不可用",
	Status.STARTING: "正在启动手部追踪…",
	Status.WAITING_FOR_HANDS: "等待手部进入画面",
	Status.WAITING_FOR_DATA: "等待手部追踪数据",
	Status.PROTOCOL_MISMATCH: "手部追踪数据版本不匹配",
	Status.PERMISSION_DENIED: "摄像头不可用或权限被拒绝",
	Status.TRACKER_ERROR: "手部追踪程序发生错误",
	Status.RECEIVING_LANDMARKS: "已收到手部关键点",
	Status.MISSING_HELPER: "缺少手部追踪程序",
	Status.MISSING_MODEL: "缺少手部追踪模型",
	Status.MISSING_MEDIAPIPE: "缺少 MediaPipe 环境",
	Status.SIDECAR_LAUNCH_FAILED: "无法启动手部追踪程序",
	Status.FINGERTIP_WINDOW_LOCKED: "已锁定指尖窗口",
	Status.WAITING_FOR_FOUR_FINGERTIP_FRAME: "等待双手四指框选",
}

const _ERROR_STATUSES := [
	Status.PORT_UNAVAILABLE,
	Status.PROTOCOL_MISMATCH,
	Status.MISSING_HELPER,
	Status.MISSING_MODEL,
	Status.MISSING_MEDIAPIPE,
	Status.SIDECAR_LAUNCH_FAILED,
	Status.PERMISSION_DENIED,
	Status.TRACKER_ERROR,
]

const _CLEARS_READY_SOURCE_STATUSES := [
	Status.PERMISSION_DENIED,
	Status.TRACKER_ERROR,
	Status.SIDECAR_LAUNCH_FAILED,
]

const _LIVE_RECEIVER_ERROR_STATUSES := [
	Status.PERMISSION_DENIED,
	Status.TRACKER_ERROR,
]


static func display_text(status: Status) -> String:
	return str(_DISPLAY_TEXT.get(status, ""))


static func is_error(status: Status) -> bool:
	return status in _ERROR_STATUSES


static func clears_ready_source(status: Status) -> bool:
	return status in _CLEARS_READY_SOURCE_STATUSES


static func is_live_receiver_error(status: Status) -> bool:
	return status in _LIVE_RECEIVER_ERROR_STATUSES
