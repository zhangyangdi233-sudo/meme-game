extends RefCounted

const LINES := {
	"zh": ["这个对你来说不陌生", "你之前可喜欢盯着这个发呆了", "现在被你遗忘也是情有可原", "但是现在这个东西对你来说……", "很有意思……是吧", "去看看这个老家伙吧", "你现在只能依靠它咯！"],
	"en": ["This should look familiar to you.", "You used to love staring at it, lost in thought.", "It's understandable that you've forgotten it now.", "But now, to you, this thing…", "It's interesting… isn't it?", "Go and take a look at the old fellow.", "It's all you can rely on now!"],
	"ja": ["これは君にとって見覚えのあるものだ", "前はこれを見つめて、ぼんやりするのが好きだったね", "今は忘れてしまっていても、無理はない", "でも今の君にとって、このものは……", "面白い……だろう？", "この古い相棒を見に行ってごらん", "今の君には、これだけが頼りだよ！"],
}
const HINTS := {
	"zh": {"post": "先打开这一条\n亮着的帖子。", "collect": "点亮的三个字：\n%s。\n把它们拾进笔记本。", "compose": "把 %s\n从右侧字盘拖到\n上面的句子栏。", "publish": "点击\n「发布」", "click": "点击继续"},
	"en": {"post": "Open the\nhighlighted post.", "collect": "Pick up these three words:\n%s.", "compose": "Drag %s\nfrom the right tray\nto the sentence above.", "publish": "Click\nPublish", "click": "Click to continue"},
	"ja": {"post": "光っている投稿を\n開こう。", "collect": "光る三つの言葉\n%s\nを拾おう。", "compose": "右のトレイから\n%s を\n上の文へドラッグ。", "publish": "「投稿」\nを押そう", "click": "クリックで次へ"},
}

static func line(number: int, locale: String) -> String:
	return LINES.get(locale, LINES.zh)[clampi(number - 1, 0, 6)]

static func hint(phase: String, locale: String, units: Array = []) -> String:
	var text: String = HINTS.get(locale, HINTS.zh).get(phase, "")
	return text % " / ".join(units) if "%s" in text else text
