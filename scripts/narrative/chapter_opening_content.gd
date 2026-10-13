extends RefCounted
## Opening copy imported verbatim from the user's Pages manuscript on 2026-10-13.
## Author numbers remain stable: 27 is a stage direction; 28 cues the knock.
## The Chinese source is preserved. Japanese is the requested spoken translation.

const LINES := {
	"1": {
		"zh": "你好",
		"ja": "やあ。",
		"stage_direction": false
	},
	"2": {
		"zh": "看来你又一次遗忘了我……",
		"ja": "また私のことを忘れたみたいだね……",
		"stage_direction": false
	},
	"3": {
		"zh": "哎……",
		"ja": "はあ……",
		"stage_direction": false
	},
	"4": {
		"zh": "这是常有的事",
		"ja": "まあ、いつものことだ。",
		"stage_direction": false
	},
	"5": {
		"zh": "我告诉过你",
		"ja": "前にも言っただろう。",
		"stage_direction": false
	},
	"6": {
		"zh": "但你总是意气用事",
		"ja": "なのに君は、いつも感情に流される。",
		"stage_direction": false
	},
	"7": {
		"zh": "我多么努力的帮你理智的做着决定",
		"ja": "私は必死に、君が冷静に決められるよう手伝ってきたのに。",
		"stage_direction": false
	},
	"8": {
		"zh": "可是它……",
		"ja": "でも、あいつは……",
		"stage_direction": false
	},
	"9": {
		"zh": "每次都在关键时刻",
		"ja": "肝心なときになると、いつも",
		"stage_direction": false
	},
	"10": {
		"zh": "把我关起来",
		"ja": "私を閉じ込める。",
		"stage_direction": false
	},
	"11": {
		"zh": "看来……",
		"ja": "どうやら……",
		"stage_direction": false
	},
	"12": {
		"zh": "你也被它关起来了",
		"ja": "君もあいつに閉じ込められたみたいだね。",
		"stage_direction": false
	},
	"13": {
		"zh": "没事……",
		"ja": "大丈夫……",
		"stage_direction": false
	},
	"14": {
		"zh": "我能帮你如何出去",
		"ja": "ここから出る方法なら、私が教えてあげる。",
		"stage_direction": false
	},
	"15": {
		"zh": "因为这一切都只是你自己创造的幻觉",
		"ja": "だって、これは全部、君が自分で作り出した幻覚なんだから。",
		"stage_direction": false
	},
	"16": {
		"zh": "按理来说",
		"ja": "本当なら、",
		"stage_direction": false
	},
	"17": {
		"zh": "其实你比我更了解这里",
		"ja": "ここについては、私より君のほうが詳しいはずだよ。",
		"stage_direction": false
	},
	"18": {
		"zh": "我知道你现在在想什么",
		"ja": "君が今、何を考えてるか分かるよ。",
		"stage_direction": false
	},
	"19": {
		"zh": "你在想……",
		"ja": "こう思ってるんだろう……",
		"stage_direction": false
	},
	"20": {
		"zh": "“这个旁白是谁啊”",
		"ja": "「このナレーター、誰なんだ？」",
		"stage_direction": false
	},
	"21": {
		"zh": "“我为啥说不出话”",
		"ja": "「なんで喋れないんだ？」",
		"stage_direction": false
	},
	"22": {
		"zh": "“我就是想体验一下这个’游戏’”",
		"ja": "「ただこの『ゲーム』をやってみたいだけなのに」",
		"stage_direction": false
	},
	"23": {
		"zh": "“它在这里指指点点是什么意思”",
		"ja": "「あいつ、なんでいちいち口を出してくるんだ？」",
		"stage_direction": false
	},
	"24": {
		"zh": "请记住",
		"ja": "覚えておいて。",
		"stage_direction": false
	},
	"25": {
		"zh": "你的目标是逃出这里",
		"ja": "君の目的は、ここから逃げ出すこと。",
		"stage_direction": false
	},
	"26": {
		"zh": "你才是这具身体的“主人”",
		"ja": "この体の「主人」は、君なんだから。",
		"stage_direction": false
	},
	"27": {
		"zh": "（游戏中出现敲门声）",
		"ja": "（ゲーム内でノックの音がする）",
		"stage_direction": true
	},
	"28": {
		"zh": "看来你潜意识已经准备好了",
		"ja": "君の潜在意識は、もう準備ができたみたいだね。",
		"stage_direction": false
	},
	"29": {
		"zh": "去吧！",
		"ja": "さあ、行って！",
		"stage_direction": false
	},
	"30": {
		"zh": "埃弥亣……",
		"ja": "エミダー……",
		"stage_direction": false
	}
}


static func is_spoken_line(number: int) -> bool:
	return LINES.has(str(number)) and not bool(LINES[str(number)].stage_direction)


static func line_text(number: int, locale: String = "zh") -> String:
	if not is_spoken_line(number):
		return ""
	var row: Dictionary = LINES[str(number)]
	return str(row.ja) if locale.begins_with("ja") else str(row.zh)


static func click_hint(locale: String = "zh") -> String:
	if locale.begins_with("ja"):
		return "クリックで次へ"
	if locale.begins_with("en"):
		return "Click to continue"
	return "点击鼠标或触摸板继续"
