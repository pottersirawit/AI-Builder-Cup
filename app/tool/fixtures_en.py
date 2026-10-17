"""Writes assets/fixtures/en/*.json: the bundled sample answers in English.

The app shows these when the backend is unreachable and the app language is
English. Every Thai string in a fixture must have an entry below, so a new
fixture line fails here instead of leaking Thai into the English UI.

    python3 tool/fixtures_en.py
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "fixtures"
# Landmarks are search data: Thai queries must still find them.
SKIP = {"places_local.json"}
THAI = re.compile("[฀-๿]")

ENGLISH = {
    # decide_car
    "ออกก่อน 16:45": "Leave by 16:45",
    "ฝนถึงพระราม 4 ประมาณ 17:30 ถ้าออกตอนนี้ถึงบ้านราว 17:00 ก่อนฝนพอดี และทันกินข้าว 18:30 สบาย":
        "Rain reaches Rama IV around 17:30. Leave now and you are home around 17:00, just ahead of the rain and in good time for dinner at 18:30.",
    "ถึงราว 17:05 ก่อนฝน ทันนัด 18:30": "Arrive around 17:05, before the rain, in time for 18:30",
    "ศาลาแดง → ลาดพร้าว ไม่ต้องพกร่มถ้าออกตอนนี้": "Sala Daeng → Lat Phrao, no umbrella needed if you leave now",
    "ทันพอดี ถ้าช้ากว่านี้ 15 นาทีจะโดนฝนกลางทาง": "Just in time; 15 minutes later and the rain catches you on the way",
    "แยกรัชดา-ลาดพร้าว": "Ratchada-Lat Phrao Intersection",
    "ถ.พระราม 4 หน้าศูนย์สิริกิติ์": "Rama IV Rd at Queen Sirikit Centre",
    "นัด 18:30 กินข้าวที่บ้าน (Calendar) = ต้องถึงก่อน 18:30": "Dinner at home at 18:30 (Calendar) = be there by 18:30",
    "สีลม → พระราม 4 → รัชดา → ลาดพร้าว 32 รถยนต์ 50 นาที การจราจรคล่อง":
        "Silom → Rama IV → Ratchada → Lat Phrao 32 by car, 50 min, traffic is light",
    "ฝนถึงพระราม 4 ราว 17:30 หนักสุด 18:15 ราว 16 มม./ชม.": "Rain reaches Rama IV around 17:30, peaking at 18:15 at about 16 mm/h",
    "แยกรัชดา-ลาดพร้าว ฝนเกิน 40 มม. จะขัง ตอนนี้ยังแห้ง": "Ratchada-Lat Phrao floods above 40 mm of rain; dry for now",
    "ยังไม่มีรายงานน้ำขังบนเส้นทางใน 1 ชั่วโมงล่าสุด": "No flooding reported on the route in the last hour",
    "ฝนจะถึงพระราม 4 ราว 17:30 ถ้าออกก่อน 16:45 ด้วยรถยนต์ จะถึงบ้านราว 17:05 ก่อนฝนหนัก และทันนัด 18:30":
        "Rain reaches Rama IV around 17:30. Leave by car before 16:45 and you are home around 17:05, ahead of the heavy rain and in time for 18:30.",
    "นัดกินข้าวที่บ้าน 18:30 จาก Calendar": "Dinner at home at 18:30, from Calendar",
    "ฝนบนพระราม 4 เริ่มราว 17:30 หนักสุดราว 18:15": "Rain on Rama IV starts around 17:30 and peaks around 18:15",
    "แยกรัชดา-ลาดพร้าวยังแห้ง ต้องฝนเกิน 40 มม. น้ำจึงขัง": "Ratchada-Lat Phrao is dry; it floods only above 40 mm of rain",
    "ถ้าออกหลัง 17:15 ให้ระวังแยกรัชดา-ลาดพร้าว ซึ่งน้ำขังเร็วเมื่อฝนหนัก":
        "If you leave after 17:15, watch out for Ratchada-Lat Phrao, which floods quickly in heavy rain.",
    # decide_car_storm
    "อย่าเพิ่งออก": "Don't leave yet",
    "ฝนหนักและรัชดามีน้ำรอระบายถึงประมาณ 20:00 ออกตอนนี้ใช้เวลา 95 นาที ถึงราว 19:05 เลยนัด 18:30 รอฝนซาหลัง 19:15 หรือเปลี่ยนเป็น BTS ดีกว่า":
        "Heavy rain, and Ratchada has standing water until about 20:00. Leaving now takes 95 min and gets you there around 19:05, past 18:30. Better to wait for the rain to ease after 19:15 or take the BTS.",
    "รัชดาน้ำรอระบายถึงครึ่งล้อ รถติดสะสม": "Ratchada water is half a wheel deep; traffic is backing up",
    "ขบวนไม่สนฝน แต่ชานชาลาแน่น เผื่อรอ 2 ถึง 3 ขบวน": "Trains ignore the rain, but platforms are packed; allow for 2 to 3 trains",
    "น้ำท่วมรัชดาถึงครึ่งล้อ มอเตอร์ไซค์ผ่านไม่ได้": "Ratchada is flooded half a wheel deep; motorbikes can't get through",
    "ฝนหนักบนเส้นทาง 17:45 ถึง 19:00 สูงสุด 16 มม./ชม.": "Heavy rain on the route 17:45 to 19:00, up to 16 mm/h",
    "แยกรัชดา-ลาดพร้าว เกินเกณฑ์ฝน คาดน้ำขัง 25 ซม. เกินระยะพ้นน้ำของรถเก๋ง 15 ซม.":
        "Ratchada-Lat Phrao is past its rain threshold: about 25 cm of water expected, above a sedan's 15 cm clearance",
    "ผู้ใช้ 3 คนรายงานน้ำถึงครึ่งล้อที่รัชดา ใน 20 นาที": "3 users reported half-wheel water at Ratchada in 20 min",
    "Routes API คาดรถติดหนัก ใช้เวลา 95 นาที": "Routes API expects heavy traffic, 95 min",
    "รัชดามีน้ำรอระบายราว 25 ซม. ถึงครึ่งล้อรถเก๋ง ออกตอนนี้จะติดสะสมและถึงราว 19:05 เลยนัด 18:30 รอฝนซาหลัง 19:15 หรือเปลี่ยนเป็น BTS":
        "Ratchada has about 25 cm of standing water, half a sedan wheel. Leave now and you sit in traffic and arrive around 19:05, past 18:30. Wait for the rain to ease after 19:15 or take the BTS.",
    "น้ำที่แยกรัชดา-ลาดพร้าวคาดสูง 25 ซม.": "Water at Ratchada-Lat Phrao expected at 25 cm",
    "พระราม 4 หน้าศูนย์สิริกิติ์คาดสูง 10 ซม.": "Rama IV at Queen Sirikit Centre expected at 10 cm",
    "ถ้าจำเป็นต้องขับ ให้เลี่ยงแยกรัชดา-ลาดพร้าว หรือนั่งรถไฟฟ้าซึ่งไม่ผ่านน้ำบนถนน":
        "If you must drive, avoid Ratchada-Lat Phrao, or take the train, which skips the water on the roads.",
    # decide_moto
    "ออกตอนนี้ ทันพอดี": "Leave now, just in time",
    "ถึงบ้านราว 16:45 ฝนถึงเส้นทางตอน 17:30 ถ้าช้ากว่านี้ 15 นาทีจะโดนกลางทาง":
        "Home around 16:45. Rain reaches the route at 17:30; 15 minutes later and it catches you on the way.",
    "มอเตอร์ไซค์ 30 นาที ผ่านพระราม 4 และรัชดา": "Motorbike 30 min via Rama IV and Ratchada",
    "ฝนถึงพระราม 4 ราว 17:30 ออกตอนนี้ยังแห้ง": "Rain reaches Rama IV around 17:30; dry if you leave now",
    "มอเตอร์ไซค์เสี่ยงลมกระโชกเกิน 45 กม./ชม. ช่วงฝนหนัก": "Motorbikes risk gusts above 45 km/h in the heavy rain",
    # decide_moto_storm
    "เปลี่ยนเป็น BTS ดีกว่า": "Take the BTS instead",
    "ฝนหนัก น้ำท่วมรัชดาถึงครึ่งล้อ มอเตอร์ไซค์ผ่านไม่ได้ รอถึงหลัง 20:00 หรือเปลี่ยนเป็น BTS":
        "Heavy rain and Ratchada is flooded half a wheel deep; motorbikes can't get through. Wait until after 20:00 or take the BTS.",
    "ฝนหนักบนเส้นทาง มองไม่เห็นทาง ถนนลื่น": "Heavy rain on the route: poor visibility, slippery roads",
    "แยกรัชดา-ลาดพร้าว คาดน้ำขัง 25 ซม. มอเตอร์ไซค์ผ่านไม่ได้": "Ratchada-Lat Phrao expects 25 cm of water; motorbikes can't get through",
    "ผู้ใช้ 3 คนรายงานน้ำถึงครึ่งล้อที่รัชดา": "3 users reported half-wheel water at Ratchada",
    # decide_needs_place
    "เซ็นทรัล": "Central",
    "เซ็นทรัลเวิลด์": "CentralWorld",
    "ถ.ราชดำริ เขตปทุมวัน": "Ratchadamri Rd, Pathum Wan",
    "เซ็นทรัล ลาดพร้าว": "Central Ladprao",
    "ถ.พหลโยธิน เขตจตุจักร": "Phahonyothin Rd, Chatuchak",
    "เซ็นทรัล เวสต์เกต": "Central WestGate",
    "บางใหญ่ นนทบุรี": "Bang Yai, Nonthaburi",
    # decide_question
    "ออกสองทุ่มได้ แต่เลยนัด": "You can leave at 20:00, but you'll be late",
    'ได้นะ แต่จะเจอรถติดสะสม รัชดาน้ำเริ่มลดหลัง 20:00 ออกสองทุ่มถึงบ้านราว 21:05 เลยนัด 18:30 ไป 2 ชั่วโมงครึ่ง ถ้าเอาแบบนี้บอกที่บ้านว่า "ฝนหนัก กลับสามทุ่ม กินก่อนได้เลย" ดีไหม':
        'You can, but traffic will have built up. Ratchada starts draining after 20:00; leave at 20:00 and you are home around 21:05, two and a half hours after 18:30. If so, tell your family "Heavy rain, home by 21:00, eat without me"?',
    "เข้าใจว่า: กลับบ้านลาดพร้าว ออก 20:00 รถยนต์": "Understood: home to Lat Phrao, leaving 20:00 by car",
    "ฝนซาหลัง 19:45 เหลือไม่ถึง 1 มม./ชม.": "Rain eases after 19:45 to under 1 mm/h",
    "แยกรัชดา-ลาดพร้าว น้ำเริ่มลดหลัง 20:00 ยังขังบางจุด": "Ratchada-Lat Phrao starts draining after 20:00; some spots still flooded",
    "รถติดสะสมหลังฝน ใช้เวลา 65 นาที ถึงราว 21:05": "Traffic builds after the rain: 65 min, arriving around 21:05",
    # decide_transit
    "ไปได้เลย": "Good to go",
    "ศาลาแดง → ลาดพร้าว 40 นาที ถึงราว 16:55 ก่อนฝนมา ไม่ต้องพกร่มก็ได้ ทันนัด 18:30":
        "Sala Daeng → Lat Phrao, 40 min, arriving around 16:55 before the rain. No umbrella needed, in time for 18:30.",
    "เดิน 8 นาที → BTS ศาลาแดง → MRT ลาดพร้าว → เดิน 7 นาทีเข้าซอย":
        "Walk 8 min → BTS Sala Daeng → MRT Lat Phrao → walk 7 min into the soi",
    "ไม่มีฝนช่วงเดินเข้าออกสถานีถ้าออกก่อน 17:15": "No rain on the walks to and from the stations if you leave before 17:15",
    "รถไฟฟ้าไม่กระทบน้ำขังบนถนน": "Trains are not affected by water on the roads",
    # home_status_*
    "น้ำจะถึงหน้าบ้านใน 40 นาที": "Water reaches your door in 40 min",
    "คลองลาดพร้าว": "Lat Phrao Canal",
    "ย้ายรถไปจอดที่ลานจอดเซ็นทรัลลาดพร้าว 1.2 กม. ถนนยังแห้งอีก 25 นาที":
        "Move the car to the Central Ladprao car park, 1.2 km away; the road stays dry for 25 more min",
    "ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม.": "Lift plugs and ground-floor things above 50 cm",
    "เตรียมกระสอบทรายหน้าประตู จุดแจก: สำนักงานเขตจตุจักร เปิดถึงเที่ยงคืน":
        "Put sandbags at the door. Pick-up: Chatuchak District Office, open until midnight",
    "ThaiWater (HII) ระดับคลอง 5 นาที/ครั้ง": "ThaiWater (HII) canal levels every 5 min",
    "รายงานผู้ใช้ 11 คนในซอย": "Reports from 11 users in the soi",
    "คืนนี้ยังไม่น่าห่วงเรื่องน้ำท่วม": "No flood worries tonight",
    "ฝนวันนี้ยังน้อย และไม่มีรายงานน้ำขังใกล้บ้าน": "Little rain today and no flooding reported near home",
    "ถ้าฝนหนักเกิน 60 มม. ในชั่วโมงเดียว ให้เช็กหน้านี้อีกครั้ง": "If more than 60 mm falls in an hour, check this page again",
    "จุดเสี่ยงน้ำท่วม กทม.": "BMA flood spots",
    "รายงานจากผู้ใช้": "User reports",
    "ฝนวันนี้เบา ยังไม่ต้องเตรียมอะไร": "Light rain today, nothing to prepare yet",
    "บ้านอยู่นอกพื้นที่ที่แอปรองรับ จึงมีเฉพาะข้อมูลฝน": "Home is outside the area the app covers, so there is rain data only",
    "คืนนี้เสี่ยงน้ำท่วม: ปานกลาง": "Flood risk tonight: medium",
    "ถ้ากลับบ้านค่ำ จอดรถไว้ที่สูงก่อนสองทุ่ม": "If you get home late, park on high ground before 20:00",
    "เตรียมยกของชั้นล่างไว้ล่วงหน้า": "Get ready to lift ground-floor things",
    "รายงานจากผู้ใช้ 3 คนใน 20 นาที": "Reports from 3 users in 20 min",
    # outlook
    "ฟ้าโปร่ง": "Clear",
    "ท้องฟ้าแจ่มใส": "Clear sky",
    "มีเมฆบางส่วน": "Partly cloudy",
    "แดดจัด": "Sunny",
    "แดดจัด มีเมฆบางส่วน": "Sunny, partly cloudy",
    "มีเมฆเป็นส่วนมาก": "Mostly cloudy",
    "ฝนตก": "Rain",
    "พายุฝนฟ้าคะนอง": "Thunderstorms",
    "เมฆมาก": "Cloudy",
    "ท้องฟ้าโปร่งเป็นส่วนใหญ่": "Mostly clear",
    # report(s)
    "น้ำถึงประมาณครึ่งล้อรถเก๋ง เห็นทางเท้าจมแล้ว รถเก๋งผ่านได้ช้า ๆ ทางเลนขวา มอเตอร์ไซค์ไม่ควรผ่าน":
        "Water is about halfway up a car wheel and the pavement is under. Cars can pass slowly in the right lane; motorbikes should not.",
    "น้ำขังเลนซ้าย รถเก๋งผ่านได้ช้า ๆ": "Water in the left lane; cars can pass slowly",
    # trips: มิว's demo calendar, as the server's scenario names them
    "กินข้าวเย็นกับที่บ้าน": "Dinner with family",
    "สีลม ซอย 3": "Silom Soi 3",
    "บ้านลาดพร้าว": "Home (Lat Phrao)",
    "ตั๋วคอนเสิร์ต อิมแพ็ค": "Concert ticket, IMPACT",
    "อิมแพ็ค เมืองทองธานี": "IMPACT Muang Thong Thani",
    "ประชุมลูกค้า Q4": "Q4 client meeting",
    "สามย่านมิตรทาวน์": "Samyan Mitrtown",
    "เวทเทรนนิ่ง": "Weight training",
    "ฟิตเนส เซ็นทรัลลาดพร้าว": "Fitness, Central Ladprao",
    "Daily standup ที่ออฟฟิศ": "Daily standup at the office",
    "กินข้าวกับพี่เบียร์": "Lunch with Beer",
    "สยามพารากอน": "Siam Paragon",
    "นัดทำฟัน": "Dentist",
    "คลินิกทันตกรรมอารีย์ ชั้น 2": "Ari Dental Clinic, 2nd floor",
    "ทรู ดิจิทัล พาร์ค": "True Digital Park",
    "โยคะสวนลุม": "Yoga at Lumphini Park",
    "สวนลุมพินี": "Lumphini Park",
    "เที่ยวบิน FD3433 ไปเชียงใหม่": "Flight FD3433 to Chiang Mai",
    "ท่าอากาศยานดอนเมือง": "Don Mueang Airport",
    "ตรวจสุขภาพประจำปี": "Annual health check-up",
    "โรงพยาบาลพระราม 9": "Praram 9 Hospital",
    "ซิงก์งานกับทีม (Google Meet)": "Team sync (Google Meet)",
    "ออนไลน์": "Online",
    "รีวิวงานที่ทองหล่อ": "Work review in Thong Lo",
    "ทองหล่อ": "Thong Lo",
}


def translate(v, missing):
    if isinstance(v, str):
        if not THAI.search(v):
            return v
        if v not in ENGLISH:
            missing.add(v)
        return ENGLISH.get(v, v)
    if isinstance(v, list):
        return [translate(e, missing) for e in v]
    if isinstance(v, dict):
        return {k: translate(e, missing) for k, e in v.items()}
    return v


def main():
    out_dir = ROOT / "en"
    out_dir.mkdir(exist_ok=True)
    missing = set()
    for src in sorted(ROOT.glob("*.json")):
        if src.name in SKIP:
            continue
        data = translate(json.loads(src.read_text(encoding="utf-8")), missing)
        (out_dir / src.name).write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    if missing:
        sys.exit("No English for:\n" + "\n".join(sorted(missing)))


if __name__ == "__main__":
    main()
