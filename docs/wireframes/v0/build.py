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

.navbar { position:absolute; left:16px; right:16px; bottom:14px; height:58px; display:flex; gap:10px; z-index:3; }
.navbar .pill { flex:1; border:2px solid var(--ink); border-radius:30px; display:flex; background:var(--paper); }
.navbar .pill div { flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px; font-size:12px; color:var(--mid); }
.navbar .pill div i { width:20px; height:20px; border:2px solid var(--line); border-radius:6px; display:block; }
.navbar .pill div.on { color:var(--ink); font-weight:700; } .navbar .pill div.on i { border-color:var(--ink); background:var(--fill2); }
.navbar .spark { width:58px; border-radius:50%; background:var(--ink); color:#fff; display:flex; align-items:center; justify-content:center; font-size:22px; }
.phone .body { padding-bottom:84px; }
.dim { position:absolute; inset:0; background:rgba(27,31,36,.35); z-index:6; }
.bsheet { position:absolute; left:0; right:0; bottom:0; background:var(--paper); border-top:2px solid var(--ink); border-radius:24px 24px 0 0; padding:10px 16px 18px 26px; display:flex; flex-direction:column; gap:10px; z-index:7; }
.bsheet .grab { width:40px; height:5px; border-radius:3px; background:var(--line); align-self:center; margin-bottom:4px; }
.acts { margin-left:auto; display:flex; gap:8px; } .top .acts .gear, .acts .gear { margin-left:0; width:30px; height:30px; border:2px solid var(--line); border-radius:50%; display:block; }
.grow { flex:1; min-width:0; }
.stub { flex:none; border:2px solid var(--ink); border-radius:10px; background:var(--fill2); display:flex; flex-direction:column; align-items:center; justify-content:center; line-height:1.05; }
.stub b { font-size:18px; } .stub span { font-size:11px; color:var(--mid); }
.ticket { border:2px solid var(--ink); border-radius:16px; background:var(--fill); display:flex; flex-direction:column; flex:none; }
.tk-top, .tk-bot { padding:12px 14px; display:flex; flex-direction:column; gap:8px; }
.perf { border-top:2px dashed var(--line); margin:0 10px; position:relative; }
.perf::before, .perf::after { content:''; position:absolute; top:-9px; width:16px; height:16px; border-radius:50%; background:var(--paper); border:2px solid var(--ink); }
.perf::before { left:-21px; clip-path:inset(0 0 0 50%); } .perf::after { right:-21px; clip-path:inset(0 50% 0 0); }
.ring { width:76px; height:76px; border-radius:50%; border:6px solid var(--ink); border-right-color:var(--fill2); display:flex; flex-direction:column; align-items:center; justify-content:center; line-height:1.05; flex:none; }
.ring b { font-size:20px; } .ring span { font-size:9px; color:var(--mid); }
.sec { display:flex; flex-direction:column; gap:8px; }
.hscroll { display:flex; gap:10px; overflow:hidden; }
.mini { width:170px; flex:none; border:2px solid var(--line); border-radius:12px; padding:10px; background:var(--paper); display:flex; flex-direction:column; gap:3px; }
.tag { border:2px solid var(--ink); border-radius:12px; padding:2px 10px; font-size:12px; font-weight:700; white-space:nowrap; }
.tag.ok { border-color:var(--line); }
.ic { width:30px; height:30px; border:2px solid var(--line); border-radius:8px; flex:none; background:var(--fill); display:inline-block; }
.ic.round { border-radius:50%; } .ic.sq { width:26px; height:26px; }
.chip.ghost { color:var(--mid); border-style:dashed; }
.rb .bubble-t { position:absolute; top:2px; background:var(--ink); color:#fff; font-size:10px; border-radius:8px; padding:1px 6px; }
.rb .bracket { position:absolute; bottom:12px; height:6px; border:2px solid var(--ink); border-top:none; }
.rb .hours { position:absolute; left:6px; right:6px; bottom:0; display:flex; justify-content:space-between; font-size:9px; color:var(--mid); }
"""


def e(s):
    return html.escape(s, quote=False)


def pin(n):
    return f'<div class="anc"><div class="pinno">{n}</div></div>'


def phone(body, tab=None, status="16:10", overlay=""):
    nav = ""
    if tab is not None:
        labels = [("สรุป", "summary"), ("อีเวนต์", "events")]
        nav = (
            '<div class="navbar"><div class="pill">'
            + "".join(f'<div class="{"on" if k == tab else ""}"><i></i>{l}</div>' for l, k in labels)
            + '</div><div class="spark">✦</div></div>'
        )
    return (
        '<div class="phone"><div class="status"><span>%s</span><span>● ● ▮</span></div>'
        '<div class="body">%s</div>%s%s</div>' % (status, body, nav, overlay)
    )


def sheet(body, height):
    return f'<div class="dim"></div><div class="bsheet" style="height:{height}px"><div class="grab"></div>{body}</div>'


def top(title, sub="", back=True, actions=0):
    acts = "".join('<span class="gear"></span>' for _ in range(actions))
    return (
        '<div class="top">%s<div><b>%s</b>%s</div><div class="acts">%s</div></div>'
        % (
            '<span class="back"></span>' if back else "",
            e(title),
            f"<small>{e(sub)}</small>" if sub else "",
            acts,
        )
    )


def large_header(eyebrow, title, actions=2):
    acts = "".join('<span class="gear"></span>' for _ in range(actions))
    return (
        f'<div class="acts" style="justify-content:flex-end">{acts}</div>'
        f'<div class="t mut">{e(eyebrow)}</div><div class="h1" style="font-size:28px;margin-top:-8px">{e(title)}</div>'
    )


def stub(day, mon, w=52):
    return f'<div class="stub" style="width:{w}px;height:{w}px"><b>{day}</b><span>{mon}</span></div>'


def ticket(top_html, bottom_html):
    return f'<div class="ticket"><div class="tk-top">{top_html}</div><div class="perf"></div><div class="tk-bot">{bottom_html}</div></div>'


def section(title, inner, trail=""):
    t = f'<span class="mut t" style="margin-left:auto">{e(trail)}</span>' if trail else ""
    return f'<div class="sec"><div style="display:flex;align-items:baseline"><div class="h2">{e(title)}</div>{t}</div>{inner}</div>'


def rain_band(n):
    bars = "".join(f'<i style="height:{h}%"></i>' for h in [10, 12, 18, 30, 55, 80, 95, 90, 70, 45, 25, 15, 10, 8, 20, 40])
    return (
        pin(n)
        + '<div class="rb" style="height:78px"><div class="bubble-t" style="left:6%">ออก 16:10</div>'
        f'<div class="bars" style="bottom:20px;height:36px">{bars}</div>'
        '<div class="pin" style="left:8%;top:22px;bottom:18px"></div>'
        '<div class="bracket" style="left:8%;width:17%"></div>'
        '<div class="hours"><span>16:00</span><span>17:00</span><span>18:00</span><span>19:00</span></div></div>'
    )


def screens():
    S = []

    # 1 Onboarding
    S.append(dict(
        id="01-onboarding", title="1 · Onboarding", goal="First launch only. Set home and work on a pass, or skip: asking always works.",
        body=phone(
            '<div class="t" style="display:flex;gap:8px;align-items:center;margin-top:8px"><span class="ic sq"></span><b>ฝนตกไหม</b></div>'
            '<div class="h1" style="font-size:30px">ให้แอปเตือนก่อนกลับบ้าน</div>'
            '<div class="t mut">บอกว่าบ้านกับที่ทำงานอยู่ไหน แอปจะเช็กฝนและน้ำท่วมบนทางกลับให้ทุกเย็น และดูความเสี่ยงน้ำท่วมหน้าบ้าน</div>'
            + pin(1) + '<div class="ticket"><div class="tk-top"><div class="h2">บ้าน</div><div class="t mut">ใช้เตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน</div>'
            '<div style="display:flex;gap:8px;margin-top:8px"><div class="btn" style="flex:1">ใช้ตำแหน่งตอนนี้</div><div class="btn" style="flex:1">ค้นหา</div></div></div>'
            '<div class="perf"></div><div class="tk-bot">' + pin(2) + '<div style="display:flex;justify-content:space-between"><div class="h2">ที่ทำงาน</div><span class="tag ok">ตั้งแล้ว</span></div>'
            '<div class="t mut">สีลม ซอย 3 · จ–ศ ออก 18:00</div><div class="t" style="text-align:right">แก้ไข</div></div>'
            '<div class="perf"></div><div class="tk-bot t mut">🔒 ข้ามไปก่อนก็ได้ ถามเองได้เสมอ</div></div>'
            '<div style="flex:1"></div><div class="btn fill">เริ่มใช้</div>' + pin(3) + '<div class="btn ghost">ข้ามไปก่อน</div>',
            status="09:00"),
        legend=["Home slot: GPS or search, then confirm on a pin",
                "Work slot is optional; once set it shows the days and usual leave time",
                "Skip is a first-class path: the Ask button works with nothing set"]))

    # 2 Summary
    S.append(dict(
        id="02-summary", title="2 · Summary tab", goal="Opens on the next event's leave time, then what to know before going, then the rest of the day.",
        body=phone(
            large_header("อังคาร 29 ก.ย.", "วันนี้อีก 3 นัด", actions=2)
            + pin(1) + ticket(
                '<div style="display:flex;gap:10px">' + stub("29", "ก.ย.") +
                '<div class="grow"><div class="t mut">อีก 2 ชม. 20 นาที</div><div class="h2">กินข้าวเย็นกับที่บ้าน</div><div class="t mut">▢ 18:30 · บ้านลาดพร้าว</div></div><span class="mut">›</span></div>',
                '<div style="display:flex;justify-content:space-between;align-items:center"><div><div class="t mut">ควรออกก่อน</div><div class="h1" style="font-size:40px">16:45</div></div>'
                + pin(2) + '<div class="ring"><span>ต้องออกใน</span><b>35</b><span>นาที</span></div></div>'
                '<div class="t">ศาลาแดง → ลาดพร้าว 40 นาที ถึงราว 16:55 ก่อนฝนมา</div>'
                '<div class="seg"><div><span>ไปด้วย</span><b style="font-size:13px">BTS / MRT</b></div><div><span>ถึงราว</span><b>16:55</b></div><div><span>ฝนระหว่างทาง</span><b style="font-size:13px">เสี่ยงต่ำ</b></div></div>'
                + pin(3) + '<div class="chips"><span class="t mut">พกไปด้วย</span><span class="chip">☂ ร่มพับติดกระเป๋า</span></div>')
            + pin(4) + section("ต้องรู้ก่อนออก",
                '<div class="rows"><div class="r"><span class="ic round"></span><div class="grow t"><b>ฝน 85% ตอนออกไป กินข้าวเย็นกับที่บ้าน</b><div class="mut">ราว 17:00 เลือกทางที่ไม่ต้องเดินกลางฝน</div></div></div>'
                '<div class="r"><span class="ic round"></span><div class="grow t"><b>นัดทำฟัน ยังไม่มีสถานที่</b><div class="mut">17:00 · ระบุสถานที่เพื่อวางแผนเวลาออก</div></div></div></div>')
            + pin(5) + section("ถัดไป", '<div class="hscroll"><div class="mini"><b class="t">14:00 · ฝน 45%</b><div class="t">ประชุมลูกค้า Q4</div><div class="t mut">ออก 13:20 · รถไฟฟ้า</div></div>'
                '<div class="mini"><b class="t">20:30 · ฝน 85%</b><div class="t">เวทเทรนนิ่ง</div><div class="t mut">ออก 20:05 · มอไซค์</div></div></div>', "ดูทั้งหมด"),
            tab="summary"),
        legend=["Next-event ticket: date stub, countdown, title, time and place; tap opens the decision",
                "Leave answer in big type with a countdown ring (blue, amber under 15 min, red when due)",
                "Go by / arrive / rain risk, plus what to bring and why",
                "“Before you go” alerts: wet leave, wet return, tight or impossible hops, events with no place",
                "Up next: horizontal cards; below them (scroll) “Today at a glance” day strip and “Weather now”"]))

    # 3 Events
    S.append(dict(
        id="03-events", title="3 · Events tab", goal="Every synced Calendar and Gmail event, grouped by day, each with its leave time.",
        body=phone(
            large_header("จาก Google Calendar · miw.demo@gmail.com", "อีเวนต์", actions=2)
            + pin(1) + '<div class="chips" style="flex-wrap:nowrap"><span class="chip on">ทุกวัน</span><span class="chip">วันนี้</span><span class="chip">พรุ่งนี้</span><span class="chip">พฤ 1 ต.ค.</span></div>'
            '<div class="h2">วันนี้ <span class="mut" style="font-weight:400">29 ก.ย. · 3 อีเวนต์</span></div>'
            + pin(2) + ticket('<div style="display:flex;gap:10px">' + stub("29", "ก.ย.", 44) + '<div class="grow"><div class="t mut">▢ 14:00</div><b class="t">ประชุมลูกค้า Q4</b></div><span class="mut">›</span></div>',
                '<div class="t mut">⌖ สามย่านมิตรทาวน์</div><div style="display:flex;justify-content:space-between"><b class="t">ออก 13:20 · BTS / MRT</b><span class="tag">เสี่ยงต่ำ</span></div>')
            + ticket('<div style="display:flex;gap:10px">' + stub("29", "ก.ย.", 44) + '<div class="grow"><div class="t mut">▢ 18:30</div><b class="t">กินข้าวเย็นกับที่บ้าน</b></div><span class="mut">›</span></div>',
                '<div class="t mut">⌖ บ้านลาดพร้าว</div><div style="display:flex;justify-content:space-between"><b class="t">ออก 16:45 · BTS / MRT</b><span class="tag">เสี่ยงต่ำ</span></div>')
            + '<div class="h2">พรุ่งนี้ <span class="mut" style="font-weight:400">30 ก.ย. · 5 อีเวนต์</span></div>'
            + pin(3) + ticket('<div style="display:flex;gap:10px">' + stub("30", "ก.ย.", 44) + '<div class="grow"><div class="t mut">▢ 17:00</div><b class="t">นัดทำฟัน</b></div><span class="mut">›</span></div>',
                '<div class="t"><b>? ระบุสถานที่</b></div>')
            + ticket('<div style="display:flex;gap:10px">' + stub("30", "ก.ย.", 44) + '<div class="grow"><div class="t mut">▢ 11:00</div><b class="t">ซิงก์งานกับทีม (Google Meet)</b></div></div>',
                '<div class="t mut">ออนไลน์ · ไม่ต้องเดินทาง</div>'),
            tab="events"),
        legend=["Day filter chips; the calendar icon opens a month sheet that filters too",
                "Event ticket: time, title, place and the leave line with its risk",
                "No place yet: tap to pick one (also flagged by a dot on the Events tab)"]))

    # 4 Ask sheet
    S.append(dict(
        id="04-ask-sheet", title="4 · Ask (✦ button)", goal="One sentence from anywhere: the sparkle next to the tabs opens it.",
        body=phone(
            large_header("อังคาร 29 ก.ย.", "วันนี้อีก 3 นัด", actions=2)
            + '<div class="ticket" style="height:300px"></div>',
            tab="summary",
            overlay=sheet(
                '<div class="h1">อยากไปไหน</div>'
                + pin(1) + '<div class="ask"><span>✦ ไปไหน กี่โมง? เช่น ห้าโมงไปสยาม</span><i></i></div>'
                + pin(2) + '<div class="chips"><span class="chip">⌂ กลับบ้านตอนนี้</span><span class="chip">ไปสยามตอนนี้</span><span class="chip">ไปทองหล่อตอนนี้</span><span class="chip">พรุ่งนี้เช้าฝนตกไหม</span></div>',
                300)),
        legend=["Plain Thai or English; Gemini reads the place and time",
                "Suggestions from saved places; tapping one opens the decision right away"]))

    # 5 Verdict pass
    S.append(dict(
        id="05-verdict", title="5 · Decision (top)", goal="The answer as a boarding pass. Drag the pin to try other departure times.",
        body=phone(
            top("ไป บ้านลาดพร้าว", "สีลม ซอย 3 → บ้านลาดพร้าว ✎")
            + '<div class="ticket"><div class="tk-top">'
            '<div style="display:flex;justify-content:space-between" class="t"><span>▢ กินข้าวเย็นกับที่บ้าน</span><b>ถึงก่อน 18:30</b></div>'
            + pin(1) + '<div class="h1" style="font-size:40px">ไปได้เลย</div>'
            '<div style="display:flex;gap:8px;align-items:center"><span class="tag">ออกได้</span><span class="t mut">ใช้เวลา 40 นาที</span></div>'
            '<div class="t">ออกตอนนี้ถึงราว 16:55 ฝนเริ่ม 17:00 ไม่ต้องพกร่มก็ได้</div></div>'
            '<div class="perf"></div><div class="tk-bot">' + pin(2) + '<div class="seg"><div><span>ออก</span><b>ตอนนี้</b></div><div><span>ถึง</span><b>16:55</b></div><div><span>โหมด</span><b style="font-size:13px">รถไฟฟ้า</b></div><div><span>มั่นใจ</span><b>86%</b></div></div></div>'
            '<div class="perf"></div><div class="tk-bot"><div class="t mut">↔ ลากหมุดเพื่อลองเวลาออก</div>' + rain_band(3)
            + '<div class="t mut">✦ AI วิเคราะห์ให้</div><div class="chips"><span class="chip">เปลี่ยนจุดเริ่มต้น</span><span class="chip">บันทึกที่นี่ไว้</span></div></div></div>'
            '<div style="flex:1"></div>' + pin(4) + '<div class="btn fill">ถามต่อ</div>',
            status="16:10"),
        legend=["Headline in plain words, the verdict chip and travel time",
                "Leave / arrive / mode / confidence",
                "Rain band: 15-minute bars, the trip bracket and a draggable departure pin; release re-asks the agent",
                "Ask a follow-up about this trip"]))

    # 6 Verdict details
    S.append(dict(
        id="06-verdict-details", title="6 · Decision (scrolled)", goal="Why, the other ways to go, the real route, flood spots and every step the agent took.",
        body=phone(
            '<div class="h2">ทำไมถึงแนะนำแบบนี้ ✦</div>'
            + pin(1) + '<div class="t">รัชดามีน้ำรอระบายราว 25 ซม. ออกตอนนี้จะถึงราว 19:05 เลยนัด รอฝนซาหลัง 19:15 หรือเปลี่ยนเป็น BTS</div>'
            '<div class="chips"><span class="chip">เลี่ยง แยกรัชดา-ลาดพร้าว</span><span class="chip ghost">ดูปัจจัยที่ใช้ตัดสิน (4)</span></div>'
            + pin(2) + '<div class="h2">เทียบวิธีเดินทาง</div>'
            '<div class="seg"><div><span>รถยนต์</span><b style="font-size:12px">95 น. · รอก่อน</b></div><div style="border-color:var(--ink);background:var(--fill2)"><span>รถไฟฟ้า</span><b style="font-size:12px">50 น. · เผื่อเวลา</b></div><div><span>มอไซค์</span><b style="font-size:12px">60 น. · งดไป</b></div></div>'
            + pin(3) + '<div class="h2">เส้นทางที่ใช้คำนวณ</div>'
            '<div class="chips"><span class="chip on">สีลม ซอย 3</span><span class="t mut">→ MRT สีลม → MRT ลาดพร้าว →</span><span class="chip on">บ้านลาดพร้าว</span></div>'
            '<div class="r"><span class="tag">MRT สายสีน้ำเงิน</span><div class="grow t mut">ขึ้น สีลม → ลง ลาดพร้าว · 11 สถานี</div></div>'
            + pin(4) + '<div class="h2">จุดน้ำท่วมบนเส้นทาง</div>'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">แยกรัชดา-ลาดพร้าว</b><div class="t mut">คาดน้ำสูง 25 ซม.</div></div><span class="tag">เสี่ยงสูง</span></div>'
            + pin(5) + '<div class="h2">เหตุผลที่แนะนำแบบนี้ ✦</div>'
            '<div class="trace">'
            '<div class="s"><span class="n">1</span><div><b class="t">ดูทริปของคุณ</b><div class="t mut">นัด 18:30 = ต้องถึงก่อน 18:30</div></div></div>'
            '<div class="s"><span class="n">2</span><div><b class="t">เช็กฝนระหว่างทาง</b><div class="t mut">ฝนหนักสุด 18:15</div></div></div>'
            '<div class="s"><span class="n">3</span><div><b class="t">ประเมินความเสี่ยง</b><div class="t mut">รถยนต์เสี่ยงสูงจนถึง 19:15</div></div></div></div>'
            '<div class="chips"><span class="chip">Google Weather</span><span class="chip">Routes API</span><span class="chip">BMA</span></div>'
            '<div class="t mut" style="font-size:11px">ข้อมูลจาก AI อาจคลาดเคลื่อน โปรดตรวจสอบสภาพจริงก่อนออกเดินทาง</div>',
            status="18:52"),
        legend=["Why, in one paragraph, with spots to avoid and the factors behind it",
                "Three modes with time and verdict; tap one to re-decide",
                "The route the answer was computed on, with transit line and stations",
                "BMA flood spots on this route with expected depth",
                "Each tool the agent called, sources, confidence and the accuracy note"]))

    # 7 Ask follow-up
    S.append(dict(
        id="07-ask-chat", title="7 · Ask a follow-up", goal="Keeps the trip in context; every answer is a small pass with its own confidence.",
        body=phone(
            top("ถามต่อ", "กินข้าวเย็นกับที่บ้าน")
            + '<div class="bubble ai">✦ ตอนนี้แนะนำ “อย่าเพิ่งออก” นะ มีอะไรอยากถามต่อไหม</div>'
            + pin(1) + '<div class="bubble me">ถ้ารอถึงสองทุ่มค่อยกลับล่ะ</div>'
            + pin(2) + '<div class="ticket" style="max-width:90%"><div class="tk-top"><div class="h2" style="font-size:18px">ออกสองทุ่มได้ แต่เลยนัด</div><span class="tag" style="align-self:flex-start">รอก่อน</span>'
            '<div class="t">รัชดาน้ำเริ่มลดหลัง 20:00 ออกสองทุ่มถึงบ้านราว 21:05</div></div><div class="perf"></div>'
            '<div class="tk-bot t mut">มั่นใจ ▮▮▮▮▯ 71% · ✦ AI วิเคราะห์ให้</div></div>'
            '<div style="flex:1"></div>'
            + pin(3) + '<div class="chips"><span class="chip ghost">ถ้ารอถึงสองทุ่มค่อยกลับล่ะ</span><span class="chip">ไป BTS แทนดีไหม</span></div>'
            '<div class="ask"><span>พิมพ์คำถาม เช่น ถ้าไปมอเตอร์ไซค์ล่ะ</span><i></i></div>'
            '<div class="t mut" style="font-size:11px;text-align:center">ข้อมูลจาก AI อาจคลาดเคลื่อน</div>',
            status="18:52"),
        legend=["Natural language in, Thai or English",
                "Answer as a mini pass: headline, verdict, why, confidence",
                "Two suggestions; each greys out once used"]))

    # 8 Place picker
    S.append(dict(
        id="08-place-picker", title="8 · Pick a place", goal="For home, work, an event with no place, or a question the app can't place.",
        body=phone(
            top("เพิ่มสถานที่", "ค้นหา หรือใช้ตำแหน่งตอนนี้")
            + pin(1) + '<div class="field"><span>⌕ คลินิกทันตกรรมอารีย์</span><span>✕</span></div>'
            + pin(2) + '<div class="r"><span class="ic"></span><div class="grow t"><b>ใช้ตำแหน่งตอนนี้</b><div class="mut">หาจาก GPS แล้วให้ยืนยันก่อนบันทึก</div></div></div>'
            '<div class="rows">'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">BTS อารีย์</b><div class="t mut">เขตพญาไท · Ari</div></div></div>'
            '<div class="r"><span class="ic"></span><div class="grow"><b class="t">อารีย์ ซอย 1</b><div class="t mut">เขตพญาไท</div></div></div></div>'
            '<div class="t mut">ผลการค้นหาจาก Google Maps</div>',
            overlay=sheet(
                '<div class="h2">ยืนยันสถานที่</div>'
                + pin(3) + '<div class="img" style="height:90px">หมุด + วงความแม่นยำ · pin preview</div>'
                '<div class="t"><b>BTS อารีย์</b> <span class="mut">· Google Maps</span></div>'
                '<div class="field"><span>ชื่อที่เรียก: คลินิกทำฟัน</span></div>'
                '<div class="chips">' + "".join('<span class="ic sq"></span>' for _ in range(8)) + '</div>'
                '<div class="btn fill">บันทึก</div>',
                380)),
        legend=["Search prefilled from the event's own location text",
                "GPS row with every permission state spelled out (ask, denied, off, timeout)",
                "Confirm sheet: pin preview, name, icon; work adds days and usual leave time"]))

    # 9 Flood mode
    S.append(dict(
        id="09-flood-mode", title="9 · Flood near home", goal="When home is in danger the whole app turns flood-red and Summary leads with it.",
        body=phone(
            large_header("อังคาร 29 ก.ย.", "วันนี้ไม่มีนัดแล้ว", actions=2)
            + pin(1) + '<div class="card" style="background:var(--ink);color:#fff"><div class="t" style="color:#cbd5e1">น้ำท่วมใกล้บ้าน</div>'
            '<div class="h1">น้ำจะถึงหน้าบ้านใน 40 นาที</div><div class="btn" style="color:var(--ink)">ดูสิ่งที่ต้องทำ</div></div>',
            tab="summary", status="21:40",
            overlay=sheet(
                pin(2) + '<div class="ticket"><div class="tk-top"><div class="t mut">⌂ บ้านลาดพร้าว · 21:40</div><div class="h1" style="font-size:24px">น้ำจะถึงหน้าบ้านใน 40 นาที</div><span class="tag" style="align-self:flex-start">อันตราย</span></div>'
                '<div class="perf"></div><div class="tk-bot"><div class="seg"><div><span>ระดับคลอง</span><b>1.8/1.8 ม.</b></div><div><span>ขึ้นใน 2 ชม.</span><b>40 ซม.</b></div><div><span>ถึงตลิ่ง</span><b>ถึงแล้ว</b></div></div></div></div>'
                + pin(3) + '<div class="h2">ทำตอนนี้ เรียงตามลำดับ</div>'
                '<div class="rows"><div class="r"><b>1</b><div class="grow t">ย้ายรถไปลานจอดเซ็นทรัลลาดพร้าว ถนนยังแห้งอีก 25 นาที</div></div>'
                '<div class="r"><b>2</b><div class="grow t">ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม.</div></div>'
                '<div class="r"><b>3</b><div class="grow t">เตรียมกระสอบทรายหน้าประตู</div></div></div>',
                560)),
        legend=["Flood card on Summary, above everything else",
                "Home pass: canal level, rise in 2 h, distance to the bank (or rain, spots and reports when no gauge)",
                "Ordered checklist: what to do first, second, third"]))

    # 10 Settings
    S.append(dict(
        id="10-settings", title="10 · Settings", goal="From the gear on Summary. Language, places, default mode and the Google link.",
        body=phone(
            top("ตั้งค่า", "ข้อมูลเก็บไว้ในเครื่องนี้")
            + pin(1) + '<div class="h2">ภาษา</div><div class="seg"><div style="border-color:var(--ink);background:var(--fill2)"><b style="font-size:14px">ไทย</b></div><div><b style="font-size:14px">English</b></div></div>'
            + pin(2) + '<div class="h2">สถานที่ของฉัน</div>'
            '<div class="rows"><div class="r"><span class="ic"></span><div class="grow t"><b>บ้าน</b> · บ้านลาดพร้าว</div></div>'
            '<div class="r"><span class="ic"></span><div class="grow t"><b>ที่ทำงาน</b> · สีลม ซอย 3 · จ–ศ ออก 18:00</div></div>'
            '<div class="r"><span class="ic"></span><div class="grow t mut">＋ เพิ่มสถานที่ · ยิม โรงเรียนลูก บ้านพ่อแม่ · 3 จาก 5</div></div></div>'
            + pin(3) + '<div class="h2">การเดินทาง</div><div class="seg"><div><b style="font-size:13px">รถยนต์</b></div><div style="border-color:var(--ink);background:var(--fill2)"><b style="font-size:13px">รถไฟฟ้า</b></div><div><b style="font-size:13px">มอไซค์</b></div></div>'
            + pin(4) + '<div class="h2">ให้แอปหาทริปให้เอง</div>'
            '<div class="rows"><div class="r"><div class="grow t"><b>Google Calendar</b><div class="mut">miw.demo@gmail.com · เชื่อมต่อแล้ว</div></div><span class="btn ghost" style="padding:4px 10px">ยกเลิก</span></div>'
            '<div class="r"><div class="grow t"><b>Gmail</b><div class="mut">เฉพาะอีเมลยืนยันตั๋วและนัดหมาย ไม่เก็บเนื้ออีเมล</div></div></div></div>',
            ),
        legend=["Thai / English, including the AI's answers",
                "Home, work and up to five saved places, all on-device",
                "Default way to travel",
                "One Google sign-in, read-only, for Calendar and Gmail booking emails"]))
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
        '<div class="flow"><span class="f">1 Onboarding</span><span class="a">→</span><span class="f">2 Summary</span><span class="a">/</span><span class="f">3 Events</span><span class="a">→</span>'
        '<span class="f">5–6 Decision</span><span class="a">→</span><span class="f">7 Ask follow-up</span><span class="a">·</span>'
        '<span class="f">4 Ask (✦)</span><span class="a">→</span><span class="f">5 Decision</span><span class="a">·</span><span class="f">9 Flood near home</span></div>'
    )
    sheet = (
        '<div class="sheet"><h1>ฝนตกไหม · Wireframe v0</h1>'
        '<div class="sub">Should I leave now? Rain and flood decisions for Bangkok trips. Low-fidelity, 10 screens of the app as of 17 Oct 2026, Thai UI copy with English annotations.</div>'
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
