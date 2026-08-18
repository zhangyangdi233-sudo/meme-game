class_name EchoQuoteContent
extends RefCounted
## 玩家投稿回流的措辞:每种语言各自母语化,不走 UI 翻译目录
## (与 pickup_char_pool.gd 同理:这是语言素材本身,不是界面文案)。

## 第三阶的归因反转模板:你的句子被安到别人头上。
const REATTRIBUTION_TEMPLATES := {
	"zh": "有人比你先写过这句:「%s」",
	"ja": "あの人が先に書いていた:「%s」",
	"en": "Someone else wrote it first: \"%s\"",
}

## 引用者的匿名代号。
const ANON_HANDLES := {
	"zh": "匿名",
	"ja": "名無し",
	"en": "anon",
}


static func reattribute(sentence: String, locale: String) -> String:
	var template := str(REATTRIBUTION_TEMPLATES.get(locale, REATTRIBUTION_TEMPLATES["zh"]))
	return template % sentence


static func anon_handle(locale: String) -> String:
	return str(ANON_HANDLES.get(locale, ANON_HANDLES["zh"]))
