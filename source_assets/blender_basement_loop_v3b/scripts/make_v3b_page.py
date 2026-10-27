# -*- coding: utf-8 -*-
"""Assemble the dreamcore 'v3b' review page: three-way comparison + close-ups + in-game captures."""
import base64, os, re, sys

WEB = 'D:/aphasia/outputs/basement_v3b_20261027/web'
GAME = 'D:/aphasia/outputs/ingame_loops_20261027/web'
OUT_HTML = sys.argv[1] if len(sys.argv) > 1 else 'C:/Users/15340/AppData/Local/Temp/claude/D--aphasia/aa528a79-827a-4c43-938a-e7b564473f3d/scratchpad/basement_v3_schematic.html'


def data_uri(folder, name):
    p = os.path.join(folder, name + '.jpg')
    if not os.path.exists(p):
        return ''
    with open(p, 'rb') as f:
        return 'data:image/jpeg;base64,' + base64.b64encode(f.read()).decode('ascii')


VIEWS = [
    ('View_TV_Stairs', '电视区望向楼梯', '同一机位三种状态。注意天花颗粒、楼梯侧板与平台下的封条门、踢脚线的高光。'),
    ('View_CRT_FromStairs', '楼梯脚望向 CRT', 'CRT 待机绿光成为房间里唯一的冷光，墙纸在暗部仍有纹理。'),
    ('View_RightPassage', '右侧通道', '通道只是个门洞，门洞以后可挂传送门视窗。'),
    ('View_NPC_Exit', 'NPC 区望向出口', '后灯只剩轮廓，出口门在暗处。'),
    ('View_Basement_Entrance', '楼梯顶俯视', '下楼第一眼：薄雾里的一盏灯。'),
    ('V3B_View_Low_CRT', '低机位看 CRT', '梦核式空房间：地毯、一盏灯、一台电视。'),
    ('V3B_View_Globe', '仰视主灯', '体积雾里的灯球与天花颗粒。'),
    ('V3B_View_Stair_Nook', '楼梯下的封条门', '三张纸封条：X 形封住锁边，一条封住门头；把手保留但不可用。'),
]
CLOSEUPS = [
    ('V3B_Closeup_Wallpaper', '墙纸与画框（曝光 +1.7 档，只为看材质）'),
    ('V3B_Closeup_Stairs', '踏步圆角、栏杆、楼梯侧板（曝光 +1.7 档）'),
    ('V3B_Closeup_Ceiling', '天花颗粒与灯球（曝光 +1.7 档）'),
]
GAME_SHOTS = [
    ('furniture', '第 1 轮 · 书桌与楼梯'), ('crt', '第 1 轮 · CRT 角'), ('rear', '第 1 轮 · NPC 区'),
    ('visit3_furniture', '第 3 轮 · 停电'), ('visit5_crt', '第 5 轮 · CRT 事件'), ('visit5_xray_crt', '第 5 轮 · X-ray 层'),
]

parts = []
P = parts.append
P('''<title>Aphasia 地下室质感版</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@600;700&family=Noto+Sans+SC:wght@400;500;700&display=swap">
<style>
/* layout: one reading column; three-way comparison rows; close-ups; in-game reference strip */
:root {
  --bg: #0F1512; --paper: #16201A; --fg: #E3E8DE; --muted: #96A397; --line: #27332B;
  --accent: #8FD3A6; --accent-ink: #0F1A13; --warn: #E0A456; --crt: #5FE08A;
  --display: "Noto Serif SC", "Songti SC", "SimSun", serif;
  --body: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", system-ui, sans-serif;
  --mono: "SFMono-Regular", Consolas, monospace;
  color-scheme: dark;
}
@media (prefers-color-scheme: light) { :root:not([data-theme="dark"]) {
  --bg: #ECEFE8; --paper: #F7F8F3; --fg: #1B221D; --muted: #5C675F; --line: #C9D0C4;
  --accent: #1F5A40; --accent-ink: #F2F7F1; --warn: #9A5B16; --crt: #2E8B57; color-scheme: light } }
:root[data-theme="light"] {
  --bg: #ECEFE8; --paper: #F7F8F3; --fg: #1B221D; --muted: #5C675F; --line: #C9D0C4;
  --accent: #1F5A40; --accent-ink: #F2F7F1; --warn: #9A5B16; --crt: #2E8B57; color-scheme: light }
* { box-sizing: border-box }
body { background: var(--bg); color: var(--fg); font-family: var(--body); line-height: 1.65; margin: 0;
  padding-block: 24px 64px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)) }
main { max-width: 1180px; margin: 0 auto; display: grid; gap: 40px }
h1, h2, h3 { font-family: var(--display); text-wrap: balance; margin: 0; line-height: 1.25 }
h1 { font-size: clamp(26px, 3.4vw, 38px); font-weight: 700 }
h2 { font-size: clamp(20px, 2.4vw, 26px); font-weight: 700; padding-bottom: 8px; border-bottom: 2px solid var(--accent) }
h3 { font-size: 16.5px; font-weight: 600 }
p { margin: 0 }
.eyebrow { font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--accent); font-weight: 700 }
.lede { color: var(--muted); max-width: 70ch }
header { display: grid; gap: 10px }
.facts { display: flex; flex-wrap: wrap; gap: 8px 18px; font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums }
.facts b { color: var(--fg); font-weight: 600 }
.cols { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px }
.cols figure, figure { margin: 0; min-width: 0 }
figure img { width: 100%; height: auto; display: block; border: 1px solid var(--line); background: #06090a }
.tag { font-size: 11.5px; letter-spacing: 0.08em; text-transform: uppercase; font-weight: 700; margin-bottom: 4px; color: var(--muted) }
.tag.hi { color: var(--accent) }
.row { display: grid; gap: 8px }
.row p { font-size: 14px; color: var(--muted); max-width: 90ch }
.rows { display: grid; gap: 24px }
.note { border-left: 3px solid var(--warn); padding: 8px 14px; background: var(--paper); font-size: 14px }
table { border-collapse: collapse; width: 100%; font-size: 13.5px }
th, td { text-align: left; padding: 7px 10px; border-bottom: 1px solid var(--line); vertical-align: top }
th { color: var(--muted); font-weight: 600; font-size: 12.5px; letter-spacing: 0.04em }
.tablewrap { overflow-x: auto }
ol.q { margin: 0; padding-left: 1.4em; display: grid; gap: 10px }
ol.q li b { display: block; font-weight: 600 }
ol.q li span { color: var(--muted); font-size: 14.5px }
.two { display: grid; grid-template-columns: 1fr 1fr; gap: 22px }
.two > div { min-width: 0 }
.game { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px }
@media (max-width: 820px) { .cols, .game, .two { grid-template-columns: 1fr } }
@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto } }
</style>
<main>
<header>
  <div class="eyebrow">Aphasia · 第一章地下室 · 质感版 v3b · 待确认</div>
  <h1>同一个地下室，只改材质、微几何和灯光</h1>
  <p class="lede">这版没有新增任何陈设。物件还是原来的：楼梯、书桌、两把椅子、电视柜与 CRT、边桌、画框、箱子。改的是三层："质感"（2K 烘焙法线/粗糙度、按米铺贴的 UV）、"边角"（倒角、楼梯侧板、楼梯井开口修正）和"光"（一盏偏绿的昏灯、薄雾、低曝光）。唯一的新物件是你要的那扇封条门。下面每一行都是同一台相机的三种状态，便于分辨哪一部分效果来自灯光、哪一部分来自材质。</p>
  <div class="facts"><span>源文件 <b>Basement_Loop_v2.blend</b> → <b>Basement_Loop_v3b.blend</b></span><span>Blender <b>5.2.3</b> Cycles/OptiX，128 采样</span><span>新增物件 <b>1</b>（封条门）</span><span>仓库 <b>未改动</b></span></div>
</header>

<section>
  <h2>八个机位：原样 / 只改灯光 / 材质 + 灯光</h2>
  <p class="note">左：v2 原材质原灯光（Blender 预览灯）。中：v2 原材质，换成新的昏暗灯光。右：新材质 + 新灯光（v3b）。中右两列灯光参数完全一致，差别只来自材质与倒角。所有图都是 Blender 预览，不是游戏画面；游戏里的灯光设置见方案文档 §2.3。</p>
  <div class="rows">
''')
for key, title, desc in VIEWS:
    P('''    <div class="row">
      <h3>%s <code style="font-family:var(--mono);font-size:12px;color:var(--muted);font-weight:400">%s</code></h3>
      <div class="cols">
        <figure><div class="tag">v2 原样</div><img src="{{W:v2_%s}}" alt="%s v2"></figure>
        <figure><div class="tag">只改灯光</div><img src="{{W:light_%s}}" alt="%s 只改灯光"></figure>
        <figure><div class="tag hi">材质 + 灯光 v3b</div><img src="{{W:v3b_%s}}" alt="%s v3b"></figure>
      </div>
      <p>%s</p>
    </div>
''' % (title, key, key, title, key, title, key, title, desc))
P('''  </div>
</section>

<section>
  <h2>材质近景（曝光提高，只为看清纹理）</h2>
  <div class="rows">
''')
for key, title in CLOSEUPS:
    P('''    <div class="row">
      <h3>%s</h3>
      <div class="cols">
        <figure><div class="tag">v2 原样</div><img src="{{W:v2_%s}}" alt="%s v2"></figure>
        <figure><div class="tag">只改灯光</div><img src="{{W:light_%s}}" alt="%s 只改灯光"></figure>
        <figure><div class="tag hi">材质 + 灯光 v3b</div><img src="{{W:v3b_%s}}" alt="%s v3b"></figure>
      </div>
    </div>
''' % (title, key, title, key, title, key, title))
P('''  </div>
</section>

<section>
  <h2>现在游戏里的样子（用项目截图工具抓取，Forward+，无 VHS）</h2>
  <p class="note">这是当前仓库分支真实运行时的画面：运行时用 256×256 程序贴图覆盖了墙纸和地毯，灯光均匀，没有雾和环境光遮蔽。这也是为什么 v3b 的关键不在建模而在"让运行时别再覆盖材质 + 调灯光"。</p>
  <div class="game">
''')
for key, title in GAME_SHOTS:
    P('    <figure><div class="tag">%s</div><img src="{{G:%s}}" alt="%s"></figure>\n' % (title, key, title))
P('''  </div>
</section>

<section class="two">
  <div>
    <h2>这版具体改了什么</h2>
    <div class="tablewrap"><table>
      <tr><th>层面</th><th>内容</th></tr>
      <tr><td>材质</td><td>以原有绿色墙纸、苔绿地毯、赭色天花为底色，叠加周期性 4D 噪声烘焙出无缝 2K 法线 + 1K 粗糙度：纸纹、地毯圈绒、天花颗粒、哑光漆橘皮纹；导出后 Godot 直接读图。</td></tr>
      <tr><td>UV</td><td>房壳、天花、地毯件、楼梯、踢脚线、门套改为按米投影（墙纸 1.6 m、地毯/天花 1 m、油漆 0.5 m），不再依赖运行时 triplanar。</td></tr>
      <tr><td>微几何</td><td>踏步前缘 12 mm 圆角；踢脚线/门套/门板 4–5 mm 倒角；栏杆、扶手、灯球平滑；楼梯侧板封住阶梯侧面与平台下空洞；楼梯井开口东边 −1.69 → −1.48 m（原由运行时现场重箱）并加开口饰边。</td></tr>
      <tr><td>封条门</td><td>平台下的门：三块门板、黄铜把手、三张纸封条，无交互；锚点 StairClosetDoorAnchor 供砸门事件。</td></tr>
      <tr><td>预览灯光</td><td>主灯 28 W、后灯 7 W、CRT 3.5 W；关闭所有补光；黑色世界 + 体积雾 0.010；AgX 中高对比，曝光 −0.1。</td></tr>
      <tr><td>没有动</td><td>平面布局、门轴、锚点、X-ray 标记、CRT 屏幕、全部现有家具；没有纸条、涂鸦、污渍、杂物。</td></tr>
    </table></div>
  </div>
  <div>
    <h2>请你定</h2>
    <ol class="q">
      <li><b>亮度档位</b><span>右列这个亮度（主灯 28 W 档）合适，还是回到更暗一档（15 W 档）？</span></li>
      <li><b>封条门</b><span>样式（纸封条 X 形 + 门头一条）可以吗？砸门放在第 4 轮、走近 2.6 m 触发，第 5 轮撕断一条封条。</span></li>
      <li><b>运行时杂物</b><span>进游戏时是否同步去掉运行时生成的堆箱、油漆罐、散书、桌面纸笔杯和墙面磨损，让房间更空？</span></li>
      <li><b>下一步</b><span>确认后我把 v3b 导出进游戏并改运行时与灯光参数，再用截图工具出五轮对照。</span></li>
    </ol>
  </div>
</section>
</main>
''')
html = ''.join(parts)
html = re.sub(r'\{\{W:([A-Za-z0-9_]+)\}\}', lambda m: data_uri(WEB, m.group(1)), html)
html = re.sub(r'\{\{G:([A-Za-z0-9_]+)\}\}', lambda m: data_uri(GAME, m.group(1)), html)
with open(OUT_HTML, 'w', encoding='utf-8') as f:
    f.write(html)
print('wrote', OUT_HTML, len(html.encode('utf-8')), 'bytes')
