#!/usr/bin/env python3
"""Wireframe v0 of the ฝนตกไหม app: low-fidelity, greyscale, numbered callouts.

Writes index.html (every screen on one sheet) and screens/<n>.html (one phone
each). `export.sh` turns those into PNGs for slides.

    python3 docs/wireframes/v0/build.py
"""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))

CSS = """
:root { --ink:#1b1f24; --mid:#6b7280; --line:#9aa1ab; --fill:#f1f3f5; --fill2:#e3e6ea; --paper:#fff; --accent:#1f2937; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Chakra Petch','Sarabun','Thonburi','Noto Sans Thai',system-ui,sans-serif; color:var(--ink); background:#fafafa; }
.sheet { padding:48px 48px 64px; }
.sheet h1 { font-size:34px; letter-spacing:.2px; }
.sheet .sub { color:var(--mid); margin:6px 0 36px; font-size:16px; }
.row { display:flex; flex-wrap:wrap; gap:48px 36px; align-items:flex-start; }
.cell { width:390px; }
.cell .phone { margin-top:6px; }
.cell h2 { font-size:18px; margin:0 0 4px; }
.cell .goal { color:var(--mid); font-size:13px; margin-bottom:12px; min-height:34px; }
.phone { width:390px; height:860px; border:2px solid var(--ink); border-radius:34px; background:var(--paper); position:relative; overflow:hidden; display:flex; flex-direction:column; }
.status { height:30px; display:flex; justify-content:space-between; padding:9px 22px 0; font-size:12px; color:var(--mid); }
.body { flex:1; padding:6px 16px 14px 26px; overflow:hidden; display:flex; flex-direction:column; gap:12px; position:relative; }
.nav { height:64px; border-top:2px solid var(--ink); display:flex; background:var(--paper); }
.nav div { flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px; font-size:12px; color:var(--mid); }
.nav div i { width:22px; height:22px; border:2px solid var(--line); border-radius:6px; display:block; }
.nav div.on { color:var(--ink); font-weight:700; } .nav div.on i { border-color:var(--ink); background:var(--fill2); }
.top { display:flex; align-items:center; gap:10px; min-height:40px; }
.top .back { width:30px; height:30px; border:2px solid var(--line); border-radius:50%; flex:none; }
.top b { font-size:20px; } .top small { color:var(--mid); display:block; font-size:12px; font-weight:400; }
.top .gear { margin-left:auto; width:30px; height:30px; border:2px solid var(--line); border-radius:8px; }
.h1 { font-size:22px; font-weight:700; line-height:1.25; }
.h2 { font-size:16px; font-weight:700; }
.t { font-size:13px; line-height:1.4; } .mut { color:var(--mid); }
.box { border:2px solid var(--line); border-radius:12px; padding:12px; background:var(--paper); }
.box.dark { border-color:var(--ink); background:var(--fill); }
.card { border:2px solid var(--ink); border-radius:14px; padding:14px; background:var(--fill); display:flex; flex-direction:column; gap:10px; }
.img { border:2px dashed var(--line); border-radius:10px; background:repeating-linear-gradient(45deg,var(--fill),var(--fill) 8px,var(--fill2) 8px,var(--fill2) 16px); display:flex; align-items:center; justify-content:center; color:var(--mid); font-size:12px; text-align:center; padding:6px; }
.btn { border:2px solid var(--ink); border-radius:10px; padding:10px 12px; text-align:center; font-size:14px; font-weight:700; background:var(--paper); }
.btn.fill { background:var(--ink); color:#fff; } .btn.ghost { border-color:var(--line); color:var(--mid); font-weight:400; }
.chips { display:flex; flex-wrap:wrap; gap:8px; }
.chip { border:2px solid var(--line); border-radius:20px; padding:6px 12px; font-size:13px; }
.chip.on { border-color:var(--ink); background:var(--ink); color:#fff; }
.seg { display:flex; gap:8px; } .seg div { flex:1; border:2px solid var(--line); border-radius:8px; padding:6px 4px; font-size:12px; text-align:center; background:var(--paper); }
.seg b { display:block; font-size:16px; } .seg span { color:var(--mid); }
.rb { height:54px; border:2px solid var(--line); border-radius:8px; position:relative; background:var(--paper); }
.rb .bars { position:absolute; left:6px; right:6px; bottom:6px; height:30px; display:flex; align-items:flex-end; gap:3px; }
.rb .bars i { flex:1; background:var(--fill2); border:1px solid var(--line); display:block; }
.rb .pin { position:absolute; top:2px; bottom:2px; width:0; border-left:2px solid var(--ink); }
.rb .pin::before { content:''; position:absolute; top:-2px; left:-6px; width:10px; height:10px; border-radius:50%; background:var(--ink); }
.rows { display:flex; flex-direction:column; gap:8px; }
.r { display:flex; align-items:center; gap:10px; border:2px solid var(--line); border-radius:10px; padding:10px; background:var(--paper); }
.r .ic { width:30px; height:30px; border:2px solid var(--line); border-radius:8px; flex:none; background:var(--fill); }
.r .grow { flex:1; } .r .tag { border:2px solid var(--ink); border-radius:12px; padding:2px 10px; font-size:12px; font-weight:700; }
.r .time { font-weight:700; font-size:16px; min-width:46px; }
.banner { border:2px solid var(--ink); border-radius:12px; padding:10px 12px; background:var(--paper); display:flex; gap:10px; align-items:center; font-size:13px; box-shadow:0 3px 0 var(--fill2); }
.banner .ic { width:28px; height:28px; border-radius:7px; background:var(--ink); flex:none; }
.ask { border:2px solid var(--line); border-radius:26px; padding:11px 16px; display:flex; justify-content:space-between; align-items:center; color:var(--mid); font-size:14px; background:var(--paper); }
.ask i { width:24px; height:24px; border-radius:50%; background:var(--fill2); border:2px solid var(--line); }
.trace { display:flex; flex-direction:column; }
.trace .s { display:flex; gap:10px; padding-bottom:10px; position:relative; }
.trace .s::before { content:''; position:absolute; left:11px; top:24px; bottom:0; border-left:2px solid var(--fill2); }
.trace .s:last-child::before { display:none; }
.trace .n { width:24px; height:24px; border-radius:50%; background:var(--fill2); display:flex; align-items:center; justify-content:center; font-size:12px; flex:none; }
.bubble { max-width:82%; padding:10px 12px; border-radius:14px; font-size:13px; line-height:1.4; }
.bubble.me { align-self:flex-end; background:var(--ink); color:#fff; border-bottom-right-radius:4px; }
.bubble.ai { align-self:flex-start; background:var(--fill); border:2px solid var(--line); border-bottom-left-radius:4px; }
.field { border:2px solid var(--line); border-radius:10px; padding:10px 12px; font-size:14px; color:var(--mid); display:flex; justify-content:space-between; }
.toggle { width:40px; height:22px; border:2px solid var(--ink); border-radius:12px; position:relative; flex:none; }
.toggle::after { content:''; position:absolute; top:2px; right:2px; width:14px; height:14px; border-radius:50%; background:var(--ink); }
.toggle.off::after { right:auto; left:2px; background:var(--line); } .toggle.off { border-color:var(--line); }
.anc { height:0; position:relative; margin:0 0 -12px; z-index:5; }
.anc .pinno { left:-25px; top:-2px; }
.pinno { position:absolute; width:22px; height:22px; border-radius:50%; background:#fff; color:var(--ink); border:2px solid var(--ink); font-weight:700; font-size:12px; display:flex; align-items:center; justify-content:center; z-index:5; box-shadow:0 0 0 3px rgba(255,255,255,.9); }
.legend { margin-top:14px; display:flex; flex-direction:column; gap:7px; }
.legend div { display:flex; gap:9px; font-size:13px; line-height:1.35; }
.legend b { flex:none; width:20px; height:20px; border-radius:50%; background:var(--ink); color:#fff; font-size:11px; display:flex; align-items:center; justify-content:center; margin-top:1px; }
.flow { display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin:0 0 40px; }
.flow .f { border:2px solid var(--ink); border-radius:10px; padding:8px 12px; font-size:14px; background:#fff; font-weight:700; }
.flow .a { color:var(--mid); font-size:20px; }
.page { padding:36px; display:inline-block; }
"""


def e(s):
    return html.escape(s, quote=False)


def pin(n):
    return f'<div class="anc"><div class="pinno">{n}</div></div>'


def phone(body, tab=None, status="16:10"):
    nav = ""
    if tab is not None:
        labels = [("เดินทาง", "trip"), ("รายงานน้ำท่วม", "report"), ("บ้าน", "home")]
        nav = '<div class="nav">' + "".join(
            f'<div class="{"on" if k == tab else ""}"><i></i>{l}</div>' for l, k in labels
        ) + "</div>"
    return (
        '<div class="phone"><div class="status"><span>%s</span><span>● ● ▮</span></div>'
        '<div class="body">%s</div>%s</div>' % (status, body, nav)
    )


def top(title, sub="", gear=False, back=True):
    return (
        '<div class="top">%s<div><b>%s</b>%s</div>%s</div>'
        % (
            '<span class="back"></span>' if back else "",
            e(title),
            f"<small>{e(sub)}</small>" if sub else "",
            '<span class="gear"></span>' if gear else "",
        )
    )


def pass_card(headline, summary, segs, band=True, rbpin=0):
    seg = "".join(f"<div><span>{e(a)}</span><b>{e(b)}</b></div>" for a, b in segs)
    bars = "".join(f'<i style="height:{h}%"></i>' for h in [8, 8, 10, 14, 30, 60, 85, 70, 40, 22, 12, 8])
    rb = (
        (pin(rbpin) if rbpin else '') + f'<div class="rb"><div class="bars">{bars}</div><div class="pin" style="left:34%"></div></div>'
        if band
        else ""
    )
    return (
        f'<div class="card"><div class="h1" style="font-size:30px">{e(headline)}</div>'
        f'<div class="t">{e(summary)}</div><div class="seg">{seg}</div>{rb}</div>'
    )


def mode_rows():
    rows = [("รถยนต์ · 50 นาที", "ถึงก่อนฝนตก ทันนัด 18:30", "ออกได้", "17:05"),
            ("รถไฟฟ้า · 42 นาที", "ไม่ต้องกางร่ม", "ออกได้", "16:52"),
            ("มอเตอร์ไซค์ · 45 นาที", "ฝนหนักระหว่างทาง งดมอไซค์", "งดไป", "—")]
    return '<div class="rows">' + "".join(
        f'<div class="r"><span class="ic"></span><div class="grow"><div class="h2" style="font-size:14px">{a}</div>'
        f'<div class="t mut">{b}</div></div><span class="tag">{c}</span><span class="time">{d}</span></div>'
        for a, b, c, d in rows
    ) + "</div>"


def screens():
    S = []

    # 1 Onboarding
    S.append(dict(
        id="01-onboarding", title="1 · Onboarding", goal="Two optional taps so the app can warn before you head home. Skippable: asking always works.",
        body=phone(
            '<div style="height:36px"></div>'
            '<div class="img" style="height:110px;border-radius:50%;width:110px;align-self:center">โลโก้<br>ฝนตกไหม</div>'
            '<div class="h1" style="text-align:center">ให้แอปเตือนก่อนกลับบ้าน</div>'
            '' + pin(1) + '<div class="box"><div class="h2">บ้าน</div><div class="t mut">ใช้เตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน</div>'
            '<div style="display:flex;gap:8px;margin-top:10px"><div class="btn" style="flex:1">ใช้ตำแหน่งตอนนี้</div><div class="btn" style="flex:1">ค้นหา</div></div></div>'
            '' + pin(2) + '<div class="box"><div class="h2">ที่ทำงาน <span class="mut" style="font-weight:400">· ไม่บังคับ</span></div>'
            '<div class="t mut">ทำให้เตือนตอนเลิกงานได้แม่นขึ้น</div>'
            '<div style="display:flex;gap:8px;margin-top:10px"><div class="btn" style="flex:1">ใช้ตำแหน่งตอนนี้</div><div class="btn" style="flex:1">ค้นหา</div></div></div>'
            '<div style="flex:1"></div><div class="btn fill">เริ่มใช้</div>' + pin(3) + '<div class="btn ghost">ข้ามไปก่อน</div>'
            '<div class="t mut" style="text-align:center">ใช้โปรไฟล์เดโม (มิว)</div>',
            status="09:00"),
        legend=["Home place: for the warning before you leave and flood risk at your door",
                "Work place (optional): makes the end-of-day warning accurate",
                "Skip is a first-class path: the ask bar works with nothing connected"]))

    # 2 Home / Travel
    S.append(dict(
        id="02-home", title="2 · Travel (home tab)", goal="Opens on a verdict, not a dashboard. The proactive push lands here.",
        body=phone(
            '' + pin(1) + '<div class="banner"><span class="ic"></span><div><b>ออกก่อน 16:45</b><div class="t mut">ทันนัดกินข้าวที่บ้าน 18:30</div></div></div>'
                        + pin(2) + pass_card("ออกก่อน 16:45", "ฝนถึงพระราม 4 ราว 17:30 ออกก่อนจะไม่เจอฝน", [("ออก", "16:45"), ("ถึง", "17:35"), ("โหมด", "รถยนต์"), ("มั่นใจ", "78%")], rbpin=3)
            + '' + pin(4) + '<div class="h2">เทียบวิธีเดินทาง</div>' + mode_rows()
            + '<div class="h2">ถามเร็ว</div><div class="chips"><span class="chip">กลับบ้านตอนนี้</span><span class="chip">ไปสยามตอนนี้</span><span class="chip">ไปทองหล่อตอนนี้</span></div>'
            + '<div style="flex:1"></div>' + pin(5) + '<div class="ask"><span>ไปไหน ตอนไหน เช่น “สยาม 5 โมงเย็น”</span><i></i></div>',
            tab="trip"),
        legend=["Push notification from Calendar trigger: proactive, one line",
                "Verdict first: leave-by time in big letters, one sentence of why",
                "Rain-along-route band: drag the pin to preview other departure times",
                "Three travel modes ranked: car / BTS-MRT / motorbike differ by flood clearance",
                "Ask bar: plain Thai or English, no menu needed"]))

    # 3 Verdict detail
    S.append(dict(
        id="03-verdict", title="3 · Verdict detail", goal="Why we say so: reasoning trace, flood spots on the route, sources, confidence.",
        body=phone(
            top("ไปบ้านลาดพร้าว", "สีลม ซอย 3 → บ้านลาดพร้าว")
            + pass_card("ออกก่อน 16:45", "ฝนถึงพระราม 4 ราว 17:30", [("ออก", "16:45"), ("ถึง", "17:35"), ("โหมด", "รถยนต์")], band=False)
            + '' + pin(1) + '<div class="h2">จุดน้ำท่วมบนเส้นทาง</div>'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">แยกรัชดา–ลาดพร้าว</b><div class="t mut">คาดว่าลึก 15 ซม. · ตอนนี้ยังแห้ง</div></div><span class="tag">เสี่ยงกลาง</span></div>'
            '' + pin(2) + '<div class="h2">ขั้นตอนที่ใช้ตัดสิน</div>'
            '<div class="trace">'
            '<div class="s"><span class="n">1</span><div><b class="t">เข้าใจคำถาม</b><div class="t mut">ไปบ้านลาดพร้าว</div></div></div>'
            '<div class="s"><span class="n">2</span><div><b class="t">เช็กฝนระหว่างทาง</b><div class="t mut">ฝนหนักสุด 18:15 ราว 16 มม./ชม.</div></div></div>'
            '<div class="s"><span class="n">3</span><div><b class="t">ประเมินความเสี่ยง</b><div class="t mut">รถยนต์เสี่ยงต่ำ ถ้าออกก่อน 16:45</div></div></div></div>'
            '' + pin(3) + '<div class="chips"><span class="chip">Google Weather</span><span class="chip">ThaiWater</span><span class="chip">BMA</span></div>',
            ),
        legend=["Flood spots on the actual route with expected depth for your vehicle",
                "“How we got here”: each tool the AI agent called, in plain words",
                "Sources and confidence on every answer"]))

    # 4 Ask
    S.append(dict(
        id="04-ask", title="4 · Ask a follow-up", goal="Re-plans from a plain sentence. Works with nothing connected.",
        body=phone(
            top("ถามต่อ", "")
            + '' + pin(1) + '<div class="bubble me">ถ้ารอถึงสองทุ่มล่ะ</div>'
            '<div class="bubble ai"><b>รอได้ ออก 20:00 ก็ถึงก่อนเที่ยงคืน</b><div class="t mut" style="margin-top:4px">ฝนซาหลัง 19:30 แต่แยกรัชดา–ลาดพร้าวยังมีน้ำขังราว 10 ซม.</div></div>'
            '' + pin(2) + '<div class="card" style="background:var(--paper)"><div class="h1" style="font-size:22px">รอถึง 20:00 ค่อยออก</div>'
            '<div class="seg"><div><span>ออก</span><b>20:00</b></div><div><span>ถึง</span><b>20:50</b></div><div><span>มั่นใจ</span><b>71%</b></div></div>'
            '<div class="t mut">วิเคราะห์โดย AI · ดูเหตุผลและทางเลือก ›</div></div>'
            '' + pin(3) + '<div class="chips"><span class="chip">ไปรถไฟฟ้าแทนดีไหม</span><span class="chip">ถ้ารอถึงสองทุ่มล่ะ</span></div>'
            '<div style="flex:1"></div><div class="ask"><span>พิมพ์คำถาม เช่น “แล้วมอไซค์ล่ะ”</span><i></i></div>',
            ),
        legend=["Natural language in (Thai or English)",
                "AI re-plans with real route, rain and flood data: new verdict card",
                "Suggested follow-ups keep the conversation one tap long"]))

    # 5 Place picker
    S.append(dict(
        id="05-place-picker", title="5 · Pick a place", goal="Used when a question names a place the app can't resolve, or to save home/work.",
        body=phone(
            top("ตั้งบ้าน", "ค้นหา หรือใช้ตำแหน่งตอนนี้")
            + '' + pin(1) + '<div class="field"><span>อารีย์</span><span>ล้าง</span></div>'
            '<div class="rows">'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">BTS อารีย์</b><div class="t mut">เขตพญาไท กรุงเทพมหานคร</div></div></div>'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">อารีย์ ซอย 1</b><div class="t mut">เขตพญาไท กรุงเทพมหานคร</div></div></div>'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">ตลาดอารีย์</b><div class="t mut">เขตพญาไท กรุงเทพมหานคร</div></div></div></div>'
            '<div class="t mut">ผลการค้นหาจาก Google Maps</div>'
            '' + pin(2) + '<div class="btn">ใช้ตำแหน่งตอนนี้</div>'
            '<div style="flex:1"></div>'
            '' + pin(3) + '<div class="box dark"><div class="img" style="height:110px">แผนที่ + หมุด · map + pin</div>'
            '<div class="h2" style="margin-top:8px">ยืนยันบ้าน</div><div class="t mut">BTS อารีย์ · อยู่ในพื้นที่ให้บริการ</div>'
            '<div class="btn fill" style="margin-top:8px">บันทึก</div></div>',
            ),
        legend=["Search by BTS, mall, soi or district",
                "Or use GPS: no typing at all",
                "Confirm on a map pin; the app says if it's outside the covered area"]))

    # 6 Report flood
    S.append(dict(
        id="06-report", title="6 · Report flooding", goal="Community loop: one photo warns everyone whose route crosses the spot.",
        body=phone(
            top("รายงานน้ำท่วม", "ถ่ายน้ำบนถนน เตือนคนที่กำลังจะผ่าน", back=False)
            + '' + pin(1) + '<div class="img" style="height:230px">กล้อง · ใส่ล้อรถหรือขอบทางในภาพ<br>camera · include a wheel or the curb</div>'
            '<div style="display:flex;gap:8px"><div class="btn fill" style="flex:1">ถ่ายภาพ</div><div class="btn" style="flex:1">เลือกจากคลัง</div></div>'
            '<div class="t mut">📍 ใช้ GPS ของเครื่อง · 18:52</div>'
            '' + pin(2) + '<div class="card" style="background:var(--paper)"><div class="h2">AI ดูภาพแล้ว</div>'
            '<div class="h1" style="font-size:24px">น้ำลึกราว 20–25 ซม.</div>'
            '<div class="seg"><div><span>รถยนต์</span><b>ผ่านช้า ๆ</b></div><div><span>รถไฟฟ้า</span><b>ผ่านได้</b></div><div><span>มอไซค์</span><b>ไม่ควรผ่าน</b></div></div>'
            '' + pin(3) + '<div class="t mut">แจ้งเตือน 27 คนที่เส้นทางผ่านจุดนี้ · ยืนยันกับอีก 2 รายงาน</div></div>',
            tab="report", status="18:52"),
        legend=["Photo with a reference object (wheel / curb)",
                "Vision AI estimates depth and which vehicles can pass",
                "Fan-out: only people whose route passes within ~300 m are notified"]))

    # 7 Flood mode
    S.append(dict(
        id="07-flood-mode", title="7 · Home · flood mode", goal="Same question, higher stakes. Screen goes dark and the actions are ordered.",
        body=phone(
            '' + pin(1) + '<div class="card" style="background:var(--ink);color:#fff;border-color:var(--ink)">'
            '<div class="t" style="color:#cbd5e1">โหมดน้ำท่วม · บ้านลาดพร้าว</div>'
            '<div class="h1" style="font-size:28px">น้ำจะถึงหน้าบ้านใน 40 นาที</div>'
            '<div class="seg"><div style="background:transparent;color:#fff;border-color:#64748b"><span style="color:#cbd5e1">ระดับคลอง</span><b>1.8/1.8 ม.</b></div>'
            '<div style="background:transparent;color:#fff;border-color:#64748b"><span style="color:#cbd5e1">ขึ้นใน 2 ชม.</span><b>+40 ซม.</b></div>'
            '<div style="background:transparent;color:#fff;border-color:#64748b"><span style="color:#cbd5e1">ฝนวันนี้</span><b>68 มม.</b></div></div></div>'
            '' + pin(2) + '<div class="h2">ทำตอนนี้ เรียงตามลำดับ</div>'
            '<div class="rows"><div class="r"><b>1</b><div class="grow t">ย้ายรถขึ้นที่สูง ลานจอดชั้น 2</div></div>'
            '<div class="r"><b>2</b><div class="grow t">ยกของมีค่าขึ้นชั้นบน ปิดไฟชั้นล่าง</div></div>'
            '<div class="r"><b>3</b><div class="grow t">วางกระสอบทรายหน้าประตู</div></div></div>'
            '' + pin(3) + '<div class="h2">เพื่อนบ้านในซอย</div><div class="box"><div class="t">11 คนได้รับการเตือนเดียวกัน · แจ้งผ่าน LINE / SMS</div></div>'
            '<div class="h2">จุดเสี่ยงน้ำท่วมใกล้บ้าน</div>'
            '<div class="r"><span class="ic"></span><div class="grow t"><b>ซอยลาดพร้าว 71</b> · 350 ม. จากบ้าน</div></div>',
            tab="home", status="21:40"),
        legend=["Countdown to the doorstep from canal level (ThaiWater) and rain",
                "Ordered checklist: what to do first, second, third",
                "Neighbours alerted, including people without the app (LINE / SMS)"]))

    # 8 Settings
    S.append(dict(
        id="08-settings", title="8 · Settings", goal="Everything stays on the device. Language, places, what feeds the agent.",
        body=phone(
            top("ตั้งค่า", "ข้อมูลเก็บไว้ในเครื่องนี้")
            + '' + pin(1) + '<div class="h2">ภาษา · Language</div><div class="seg"><div style="border-color:var(--ink);background:var(--fill2)"><b style="font-size:14px">ไทย</b></div><div><b style="font-size:14px">English</b></div></div>'
            '' + pin(2) + '<div class="h2">สถานที่ของฉัน</div>'
            '<div class="rows"><div class="r"><span class="ic"></span><div class="grow t"><b>บ้าน</b> · คอนโดลาดพร้าว</div></div>'
            '<div class="r"><span class="ic"></span><div class="grow t"><b>ที่ทำงาน</b> · จ–ศ ออก 18:00</div></div>'
            '<div class="r"><span class="ic"></span><div class="grow t mut">＋ เพิ่มสถานที่ (1 จาก 5)</div></div></div>'
            '' + pin(3) + '<div class="h2">ให้แอปหาทริปให้เอง</div>'
            '<div class="rows"><div class="r"><div class="grow t"><b>Google Calendar</b><div class="mut">เฉพาะนัดที่มีสถานที่</div></div><span class="toggle"></span></div>'
            '<div class="r"><div class="grow t"><b>Gmail</b><div class="mut">เฉพาะอีเมลยืนยันตั๋วและนัดหมาย</div></div><span class="toggle"></span></div></div>'
            '<div class="h2">ชุมชนและน้ำท่วม</div>'
            '<div class="rows"><div class="r"><div class="grow t"><b>แจ้งเตือนน้ำท่วมที่บ้าน</b><div class="mut">แม้ปิดแอปอยู่</div></div><span class="toggle"></span></div>'
            '<div class="r"><div class="grow t"><b>SMS สำรอง</b><div class="mut">เมื่อไม่มีอินเทอร์เน็ต</div></div><span class="toggle off"></span></div></div>',
            ),
        legend=["Interface language switch: Thai / English, including the AI's answers",
                "Saved places stay on-device",
                "Calendar and Gmail are what make the app proactive; each can be turned off"]))
    return S


def cell(s):
    legend = "".join(f"<div><b>{i + 1}</b><span>{e(t)}</span></div>" for i, t in enumerate(s["legend"]))
    return (
        f'<div class="cell"><h2>{e(s["title"])}</h2><div class="goal">{e(s["goal"])}</div>'
        f'{s["body"]}<div class="legend">{legend}</div></div>'
    )


def page(inner, title):
    return (
        f'<!doctype html><html lang="th"><head><meta charset="utf-8"><title>{e(title)}</title>'
        f'<meta name="viewport" content="width=device-width,initial-scale=1"><style>{CSS}</style></head><body>{inner}</body></html>'
    )


def main():
    S = screens()
    flow = (
        '<div class="flow"><span class="f">Push 16:10</span><span class="a">→</span><span class="f">2 Travel</span><span class="a">→</span>'
        '<span class="f">3 Verdict detail</span><span class="a">→</span><span class="f">4 Ask follow-up</span><span class="a">·</span>'
        '<span class="f">6 Report flood</span><span class="a">→</span><span class="f">7 Flood mode (home)</span></div>'
    )
    sheet = (
        '<div class="sheet"><h1>ฝนตกไหม · Wireframe v0</h1>'
        '<div class="sub">Should I leave now? Rain and flood decisions for Bangkok trips. Low-fidelity, 8 screens, Thai UI copy with English annotations.</div>'
        + flow + '<div class="row">' + "".join(cell(s) for s in S) + "</div></div>"
    )
    with open(os.path.join(HERE, "index.html"), "w", encoding="utf8") as f:
        f.write(page(sheet, "ฝนตกไหม wireframe v0"))
    os.makedirs(os.path.join(HERE, "screens"), exist_ok=True)
    for s in S:
        with open(os.path.join(HERE, "screens", s["id"] + ".html"), "w", encoding="utf8") as f:
            f.write(page('<div class="page">' + cell(s) + "</div>", s["title"]))
    print(f"wrote index.html and {len(S)} screens")


if __name__ == "__main__":
    main()
