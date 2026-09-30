"""
Google Calendar OAuth 2.0 Ingestion & Bangkok Weather Resilience Matcher
Supports:
1. Google OAuth 2.0 Consent & Token Exchange Flow (calendar.readonly)
2. State token CSRF prevention and token lifecycle management (in-memory + Redis cache)
3. Deterministic Bangkok mock calendar scenarios (Asok, Bang Khen, Siam, Ladprao, Bangkok Kritha)
4. Comprehensive 50+ Bangkok landmark geocoding dictionary and robust multi-pass fuzzy parser
"""

import os
import re
import json
import time
import secrets
import difflib
import threading
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional, Tuple
import urllib.parse
import requests

from engine.config import settings

# Comprehensive Bangkok Landmark Geocoding Dictionary (50+ key hubs, commercial centers, transit stations, universities, hospitals, and corridors)
BANGKOK_PLACES_GEOCODE: Dict[str, Dict[str, Any]] = {
    # --- 1. Commercial Hubs & Major Malls ---
    "สยามพารากอน": {
        "lat": 13.7460, "lng": 100.5347,
        "name_th": "สยามพารากอน (ปทุมวัน)",
        "name_en": "Siam Paragon",
        "category": "commercial",
        "aliases": ["สยามพารากอน", "siam paragon", "paragon", "พารากอน", "สยาม สแควร์วัน"]
    },
    "เซ็นทรัลเวิลด์": {
        "lat": 13.7466, "lng": 100.5393,
        "name_th": "เซ็นทรัลเวิลด์ ราชประสงค์ (ปทุมวัน)",
        "name_en": "CentralWorld",
        "category": "commercial",
        "aliases": ["เซ็นทรัลเวิลด์", "centralworld", "central world", "เซ็นทรัลเวิลด์ราชประสงค์", "แยกราชประสงค์"]
    },
    "ไอคอนสยาม": {
        "lat": 13.7267, "lng": 100.5107,
        "name_th": "ไอคอนสยาม ถ.เจริญนคร (คลองสาน)",
        "name_en": "ICONSIAM",
        "category": "commercial",
        "aliases": ["ไอคอนสยาม", "iconsiam", "icon siam", "ไอคอน สยาม", "เจริญนคร"]
    },
    "เซ็นทรัลลาดพร้าว": {
        "lat": 13.8166, "lng": 100.5615,
        "name_th": "เซ็นทรัลลาดพร้าว ถ.พหลโยธิน (จตุจักร)",
        "name_en": "Central Ladprao",
        "category": "commercial",
        "aliases": ["เซ็นทรัลลาดพร้าว", "central ladprao", "central plaza ladprao", "เซ็นทรัล ลาดพร้าว"]
    },
    "เซ็นทรัลพระราม 9": {
        "lat": 13.7580, "lng": 100.5661,
        "name_th": "เซ็นทรัลพระราม 9 ถ.รัชดาภิเษก (ห้วยขวาง)",
        "name_en": "Central Rama 9",
        "category": "commercial",
        "aliases": ["เซ็นทรัลพระราม 9", "เซ็นทรัล พระราม 9", "central rama 9", "central grand rama 9", "เซ็นทรัลพระรามเก้า"]
    },
    "เอ็มควอเทียร์": {
        "lat": 13.7315, "lng": 100.5695,
        "name_th": "เอ็มควอเทียร์ สุขุมวิท (วัฒนา/คลองเตย)",
        "name_en": "EmQuartier",
        "category": "commercial",
        "aliases": ["เอ็มควอเทียร์", "emquartier", "em quartier", "em-quartier"]
    },
    "เอ็มโพเรียม": {
        "lat": 13.7303, "lng": 100.5688,
        "name_th": "เอ็มโพเรียม สุขุมวิท (คลองเตย)",
        "name_en": "Emporium",
        "category": "commercial",
        "aliases": ["เอ็มโพเรียม", "emporium", "the emporium"]
    },
    "เอ็มสเฟียร์": {
        "lat": 13.7328, "lng": 100.5662,
        "name_th": "เอ็มสเฟียร์ สุขุมวิท (คลองเตย)",
        "name_en": "Emsphere",
        "category": "commercial",
        "aliases": ["เอ็มสเฟียร์", "emsphere", "em sphere", "em district"]
    },
    "เทอร์มินอล 21 อโศก": {
        "lat": 13.7378, "lng": 100.5604,
        "name_th": "เทอร์มินอล 21 อโศก (วัฒนา)",
        "name_en": "Terminal 21 Asok",
        "category": "commercial",
        "aliases": ["เทอร์มินอล 21", "terminal 21", "terminal 21 asok", "terminal21", "เทอร์มินอล 21 อโศก"]
    },
    "อาคารเสริมมิตร": {
        "lat": 13.7372, "lng": 100.5638,
        "name_th": "อาคารเสริมมิตร ถ.อโศกมนตรี (วัฒนา)",
        "name_en": "Serm-Mit Tower Asoke",
        "category": "commercial",
        "aliases": ["อาคารเสริมมิตร", "serm-mit tower", "sermmit tower", "sermmit", "เสริมมิตรทาวเวอร์", "เสริมมิตร"]
    },
    "สีลมคอมเพล็กซ์": {
        "lat": 13.7282, "lng": 100.5345,
        "name_th": "สีลมคอมเพล็กซ์ ถ.สีลม (บางรัก)",
        "name_en": "Silom Complex",
        "category": "commercial",
        "aliases": ["สีลมคอมเพล็กซ์", "silom complex", "สีลม คอมเพล็กซ์"]
    },
    "สาทรสแควร์": {
        "lat": 13.7214, "lng": 100.5303,
        "name_th": "สาทรสแควร์ / เอ็มไพร์ทาวเวอร์ (สาทร)",
        "name_en": "Sathorn Square / Empire Tower",
        "category": "commercial",
        "aliases": ["สาทรสแควร์", "sathorn square", "empire tower", "เอ็มไพร์ทาวเวอร์", "อาคารสาทรสแควร์"]
    },
    "สามย่านมิตรทาวน์": {
        "lat": 13.7336, "lng": 100.5284,
        "name_th": "สามย่านมิตรทาวน์ ถ.พระราม 4 (ปทุมวัน)",
        "name_en": "Samyan Mitrtown",
        "category": "commercial",
        "aliases": ["สามย่านมิตรทาวน์", "samyan mitrtown", "สามย่าน มิตรทาวน์", "สามย่าน"]
    },
    "ซีคอนสแควร์ ศรีนครินทร์": {
        "lat": 13.6934, "lng": 100.6477,
        "name_th": "ซีคอนสแควร์ ถ.ศรีนครินทร์ (ประเวศ)",
        "name_en": "Seacon Square Srinakarin",
        "category": "commercial",
        "aliases": ["ซีคอนสแควร์", "ซีคอนสแควร์ ศรีนครินทร์", "seacon square", "ซีคอน", "ซีคอน ศรีนครินทร์"]
    },
    "เมกาบางนา": {
        "lat": 13.6467, "lng": 100.6802,
        "name_th": "เมกาบางนา ถ.บางนา-ตราด (บางนา)",
        "name_en": "Mega Bangna",
        "category": "commercial",
        "aliases": ["เมกาบางนา", "mega bangna", "megabangna", "เมกา บางนา", "ikea bangna"]
    },
    "ศูนย์การประชุมแห่งชาติสิริกิติ์": {
        "lat": 13.7235, "lng": 100.5590,
        "name_th": "ศูนย์การประชุมแห่งชาติสิริกิติ์ (คลองเตย)",
        "name_en": "Queen Sirikit National Convention Center (QSNCC)",
        "category": "commercial",
        "aliases": ["ศูนย์การประชุมแห่งชาติสิริกิติ์", "qsncc", "ศูนย์สิริกิติ์", "queen sirikit convention center"]
    },
    "ทรู ดิจิทัล พาร์ค": {
        "lat": 13.6865, "lng": 100.6110,
        "name_th": "ทรู ดิจิทัล พาร์ค สุขุมวิท 101 (พระโขนง)",
        "name_en": "True Digital Park",
        "category": "commercial",
        "aliases": ["ทรู ดิจิทัล พาร์ค", "true digital park", "101 true digital park", "true digital"]
    },
    "สนามกอล์ฟกรุงเทพกรีฑา": {
        "lat": 13.7475, "lng": 100.6698,
        "name_th": "สนามกอล์ฟกรุงเทพกรีฑา (สะพานสูง)",
        "name_en": "Krungthep Kreetha Golf Course",
        "category": "commercial",
        "aliases": ["สนามกอล์ฟกรุงเทพกรีฑา", "กรุงเทพกรีฑา", "krungthep kreetha golf", "กอล์ฟกรุงเทพกรีฑา"]
    },
    "เดอะมอลล์บางกะปิ": {
        "lat": 13.7644, "lng": 100.6433,
        "name_th": "เดอะมอลล์ไลฟ์สโตร์ บางกะปิ ถ.ลาดพร้าว (บางกะปิ)",
        "name_en": "The Mall Lifestore Bangkapi",
        "category": "commercial",
        "aliases": ["เดอะมอลล์บางกะปิ", "เดอะมอลล์ บางกะปิ", "the mall bangkapi"]
    },
    "เซ็นทรัลปิ่นเกล้า": {
        "lat": 13.7777, "lng": 100.4764,
        "name_th": "เซ็นทรัลปิ่นเกล้า ถ.บรมราชชนนี (บางกอกน้อย)",
        "name_en": "Central Pinklao",
        "category": "commercial",
        "aliases": ["เซ็นทรัลปิ่นเกล้า", "central pinklao", "เซ็นทรัล ปิ่นเกล้า", "ปิ่นเกล้า"]
    },

    # --- 2. BTS & MRT Interchange Hubs ---
    "สถานีรถไฟฟ้า BTS อโศก": {
        "lat": 13.7372, "lng": 100.5638,
        "name_th": "สถานีรถไฟฟ้า BTS อโศก / MRT สุขุมวิท (วัฒนา)",
        "name_en": "BTS Asok / MRT Sukhumvit Interchange",
        "category": "transit_hub",
        "aliases": ["bts asok", "bts อโศก", "mrt สุขุมวิท", "mrt sukhumvit", "แยกอโศก", "asok station", "asoke station", "asoke", "asok"]
    },
    "สถานีรถไฟฟ้า BTS สยาม": {
        "lat": 13.7460, "lng": 100.5347,
        "name_th": "สถานีรถไฟฟ้า BTS สยาม (ปทุมวัน)",
        "name_en": "BTS Siam Interchange",
        "category": "transit_hub",
        "aliases": ["bts siam", "bts สยาม", "siam station", "สยามสแควร์", "siam square", "สยาม", "siam"]
    },
    "สถานีรถไฟฟ้า BTS หมอชิต": {
        "lat": 13.8025, "lng": 100.5537,
        "name_th": "สถานีรถไฟฟ้า BTS หมอชิต / MRT สวนจตุจักร (จตุจักร)",
        "name_en": "BTS Mo Chit / MRT Chatuchak Park",
        "category": "transit_hub",
        "aliases": ["bts mo chit", "bts หมอชิต", "mrt สวนจตุจักร", "mrt chatuchak", "หมอชิต", "mo chit", "จตุจักร", "chatuchak"]
    },
    "สถานีรถไฟฟ้า BTS ศาลาแดง": {
        "lat": 13.7285, "lng": 100.5343,
        "name_th": "สถานีรถไฟฟ้า BTS ศาลาแดง / MRT สีลม (บางรัก)",
        "name_en": "BTS Sala Daeng / MRT Silom Interchange",
        "category": "transit_hub",
        "aliases": ["bts sala daeng", "bts ศาลาแดง", "mrt silom", "mrt สีลม", "แยกศาลาแดง", "sala daeng"]
    },
    "สถานีรถไฟฟ้า MRT พระราม 9": {
        "lat": 13.7578, "lng": 100.5654,
        "name_th": "สถานีรถไฟฟ้า MRT พระราม 9 (ห้วยขวาง)",
        "name_en": "MRT Phra Ram 9",
        "category": "transit_hub",
        "aliases": ["mrt พระราม 9", "mrt rama 9", "mrt phra ram 9", "แยกพระราม 9", "rama 9 intersection", "พระราม 9", "rama 9"]
    },
    "สถานีรถไฟฟ้า BTS พญาไท": {
        "lat": 13.7569, "lng": 100.5349,
        "name_th": "สถานีรถไฟฟ้า BTS พญาไท / ARL พญาไท (ราชเทวี)",
        "name_en": "BTS / ARL Phaya Thai",
        "category": "transit_hub",
        "aliases": ["bts phaya thai", "bts พญาไท", "arl phaya thai", "แอร์พอร์ตลิงก์พญาไท", "พญาไท", "phaya thai"]
    },
    "สถานีรถไฟฟ้า BTS ห้าแยกลาดพร้าว": {
        "lat": 13.8136, "lng": 100.5615,
        "name_th": "สถานีรถไฟฟ้า BTS ห้าแยกลาดพร้าว / MRT พหลโยธิน (จตุจักร)",
        "name_en": "BTS Ha Yaek Lat Phrao / MRT Phahon Yothin",
        "category": "transit_hub",
        "aliases": ["bts ห้าแยกลาดพร้าว", "ha yaek lat phrao", "mrt พหลโยธิน", "ห้าแยกลาดพร้าว", "พหลโยธิน"]
    },
    "สถานีกลางกรุงเทพอภิวัฒน์": {
        "lat": 13.8039, "lng": 100.5398,
        "name_th": "สถานีกลางกรุงเทพอภิวัฒน์ / บางซื่อ (จตุจักร)",
        "name_en": "Krung Thep Aphiwat Central Terminal (Bang Sue)",
        "category": "transit_hub",
        "aliases": ["สถานีกลางกรุงเทพอภิวัฒน์", "krung thep aphiwat", "บางซื่อ", "bang sue grand station", "mrt บางซื่อ", "bang sue"]
    },
    "สถานีรถไฟฟ้า BTS ช่องนนทรี": {
        "lat": 13.7236, "lng": 100.5293,
        "name_th": "สถานีรถไฟฟ้า BTS ช่องนนทรี (บางรัก/สาทร)",
        "name_en": "BTS Chong Nonsi",
        "category": "transit_hub",
        "aliases": ["bts ช่องนนทรี", "bts chong nonsi", "ช่องนนทรี", "chong nonsi"]
    },
    "สถานีรถไฟฟ้า BTS เอกมัย": {
        "lat": 13.7190, "lng": 100.5847,
        "name_th": "สถานีรถไฟฟ้า BTS เอกมัย / ขนส่งเอกมัย (คลองเตย)",
        "name_en": "BTS Ekkamai",
        "category": "transit_hub",
        "aliases": ["bts เอกมัย", "bts ekkamai", "เอกมัย", "ekkamai", "สุขุมวิท 63"]
    },
    "สถานีรถไฟฟ้า BTS อารีย์": {
        "lat": 13.7797, "lng": 100.5448,
        "name_th": "สถานีรถไฟฟ้า BTS อารีย์ ถ.พหลโยธิน (พญาไท)",
        "name_en": "BTS Ari",
        "category": "transit_hub",
        "aliases": ["bts อารีย์", "bts ari", "อารีย์", "ari"]
    },
    "สถานีรถไฟฟ้า MRT เตาปูน": {
        "lat": 13.8062, "lng": 100.5303,
        "name_th": "สถานีรถไฟฟ้า MRT เตาปูน อินเตอร์เชนจ์ (บางซื่อ)",
        "name_en": "MRT Tao Poon Interchange",
        "category": "transit_hub",
        "aliases": ["mrt เตาปูน", "เตาปูน", "tao poon", "tao poon station"]
    },

    # --- 3. Major Universities ---
    "จุฬาลงกรณ์มหาวิทยาลัย": {
        "lat": 13.7384, "lng": 100.5322,
        "name_th": "จุฬาลงกรณ์มหาวิทยาลัย (ปทุมวัน)",
        "name_en": "Chulalongkorn University",
        "category": "university",
        "aliases": ["จุฬาลงกรณ์มหาวิทยาลัย", "chulalongkorn university", "จุฬาฯ", "จุฬา", "chula", "cu"]
    },
    "มหาวิทยาลัยเกษตรศาสตร์": {
        "lat": 13.8479, "lng": 100.5724,
        "name_th": "มหาวิทยาลัยเกษตรศาสตร์ บางเขน (จตุจักร)",
        "name_en": "Kasetsart University (Bangkhen)",
        "category": "university",
        "aliases": ["มหาวิทยาลัยเกษตรศาสตร์", "kasetsart university", "ม.เกษตร", "เกษตรศาสตร์ บางเขน", "ku", "kasetsart", "บางเขน"]
    },
    "มหาวิทยาลัยธรรมศาสตร์ ท่าพระจันทร์": {
        "lat": 13.7557, "lng": 100.4930,
        "name_th": "มหาวิทยาลัยธรรมศาสตร์ ท่าพระจันทร์ (พระนคร)",
        "name_en": "Thammasat University (Tha Phra Chan)",
        "category": "university",
        "aliases": ["มหาวิทยาลัยธรรมศาสตร์", "thammasat university", "มธ. ท่าพระจันทร์", "มธ.", "tu tha phra chan", "thammasat"]
    },
    "มหาวิทยาลัยศรีนครินทรวิโรฒ ประสานมิตร": {
        "lat": 13.7455, "lng": 100.5652,
        "name_th": "มหาวิทยาลัยศรีนครินทรวิโรฒ ประสานมิตร (วัฒนา)",
        "name_en": "Srinakharinwirot University (SWU Prasarnmit)",
        "category": "university",
        "aliases": ["มหาวิทยาลัยศรีนครินทรวิโรฒ", "มศว", "มศว ประสานมิตร", "swu", "srinakharinwirot", "ประสานมิตร"]
    },
    "มหาวิทยาลัยรามคำแหง": {
        "lat": 13.7553, "lng": 100.6225,
        "name_th": "มหาวิทยาลัยรามคำแหง หัวหมาก (บางกะปิ)",
        "name_en": "Ramkhamhaeng University",
        "category": "university",
        "aliases": ["มหาวิทยาลัยรามคำแหง", "ramkhamhaeng university", "ม.รามคำแหง", "ม.ราม", "หัวหมาก"]
    },
    "มหาวิทยาลัยมหิดล ศิริราช": {
        "lat": 13.7588, "lng": 100.4857,
        "name_th": "คณะแพทยศาสตร์ศิริราชพยาบาล ม.มหิดล (บางกอกน้อย)",
        "name_en": "Mahidol University (Siriraj)",
        "category": "university",
        "aliases": ["มหาวิทยาลัยมหิดล", "mahidol university", "ม.มหิดล ศิริราช", "มหิดล"]
    },
    "สถาบันเทคโนโลยีพระจอมเกล้าเจ้าคุณทหารลาดกระบัง": {
        "lat": 13.7279, "lng": 100.7783,
        "name_th": "สถาบันเทคโนโลยีพระจอมเกล้าเจ้าคุณทหารลาดกระบัง (ลาดกระบัง)",
        "name_en": "KMITL Ladkrabang",
        "category": "university",
        "aliases": ["พระจอมเกล้าลาดกระบัง", "kmitl", "สจล.", "สจล", "ลาดกระบัง"]
    },
    "มหาวิทยาลัยหอการค้าไทย": {
        "lat": 13.7788, "lng": 100.5601,
        "name_th": "มหาวิทยาลัยหอการค้าไทย ถ.วิภาวดีรังสิต (ดินแดง)",
        "name_en": "University of the Thai Chamber of Commerce (UTCC)",
        "category": "university",
        "aliases": ["มหาวิทยาลัยหอการค้าไทย", "หอการค้า", "utcc", "ม.หอการค้า"]
    },

    # --- 4. Major Hospitals ---
    "โรงพยาบาลศิริราช": {
        "lat": 13.7588, "lng": 100.4857,
        "name_th": "โรงพยาบาลศิริราช (บางกอกน้อย)",
        "name_en": "Siriraj Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลศิริราช", "siriraj hospital", "รพ.ศิริราช", "ศิริราช"]
    },
    "โรงพยาบาลจุฬาลงกรณ์": {
        "lat": 13.7317, "lng": 100.5340,
        "name_th": "โรงพยาบาลจุฬาลงกรณ์ สภากาชาดไทย (ปทุมวัน)",
        "name_en": "King Chulalongkorn Memorial Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลจุฬาลงกรณ์", "chulalongkorn hospital", "รพ.จุฬาลงกรณ์", "รพ.จุฬาฯ", "รพ.จุฬา"]
    },
    "โรงพยาบาลรามาธิบดี": {
        "lat": 13.7670, "lng": 100.5270,
        "name_th": "โรงพยาบาลรามาธิบดี ถ.พระราม 6 (ราชเทวี)",
        "name_en": "Ramathibodi Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลรามาธิบดี", "ramathibodi hospital", "รพ.รามาธิบดี", "รพ.รามา", "รามาธิบดี"]
    },
    "โรงพยาบาลกรุงเทพ": {
        "lat": 13.7483, "lng": 100.5835,
        "name_th": "โรงพยาบาลกรุงเทพ ซอยศูนย์วิจัย (ห้วยขวาง)",
        "name_en": "Bangkok Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลกรุงเทพ", "bangkok hospital", "รพ.กรุงเทพ", "ศูนย์วิจัย"]
    },
    "โรงพยาบาลบำรุงราษฎร์": {
        "lat": 13.7463, "lng": 100.5528,
        "name_th": "โรงพยาบาลบำรุงราษฎร์ สุขุมวิท 3 (วัฒนา)",
        "name_en": "Bumrungrad International Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลบำรุงราษฎร์", "bumrungrad hospital", "bumrungrad", "รพ.บำรุงราษฎร์"]
    },
    "โรงพยาบาลพระมงกุฎเกล้า": {
        "lat": 13.7686, "lng": 100.5332,
        "name_th": "โรงพยาบาลพระมงกุฎเกล้า ถ.ราชวิถี (ราชเทวี)",
        "name_en": "Phramongkutklao Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลพระมงกุฎเกล้า", "phramongkutklao hospital", "รพ.พระมงกุฎ", "รพ.พระมงกุฎเกล้า"]
    },
    "โรงพยาบาลสมิติเวช สุขุมวิท": {
        "lat": 13.7353, "lng": 100.5768,
        "name_th": "โรงพยาบาลสมิติเวช สุขุมวิท 49 (วัฒนา)",
        "name_en": "Samitivej Sukhumvit Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลสมิติเวช", "samitivej hospital", "รพ.สมิติเวช", "สมิติเวช สุขุมวิท"]
    },
    "โรงพยาบาลราชวิถี": {
        "lat": 13.7654, "lng": 100.5372,
        "name_th": "โรงพยาบาลราชวิถี อนุสาวรีย์ชัยฯ (ราชเทวี)",
        "name_en": "Rajavithi Hospital",
        "category": "hospital",
        "aliases": ["โรงพยาบาลราชวิถี", "rajavithi hospital", "รพ.ราชวิถี", "ราชวิถี"]
    },

    # --- 5. Government & Major Public Hubs ---
    "ศูนย์ราชการแจ้งวัฒนะ": {
        "lat": 13.8863, "lng": 100.5658,
        "name_th": "ศูนย์ราชการแจ้งวัฒนะ (หลักสี่)",
        "name_en": "Government Complex Chaeng Watthana",
        "category": "government",
        "aliases": ["ศูนย์ราชการแจ้งวัฒนะ", "government complex", "ศูนย์ราชการ", "chaeng watthana government complex", "cwt", "ศูนย์ราชการเฉลิมพระเกียรติ"]
    },
    "ศาลอาญา รัชดา": {
        "lat": 13.8219, "lng": 100.5752,
        "name_th": "ศาลอาญา ถ.รัชดาภิเษก (จตุจักร)",
        "name_en": "Criminal Court Ratchada",
        "category": "government",
        "aliases": ["ศาลอาญา", "ศาลอาญารัชดา", "ศาลอาญา รัชดา", "criminal court ratchada"]
    },
    "ท่าอากาศยานดอนเมือง": {
        "lat": 13.9126, "lng": 100.6067,
        "name_th": "ท่าอากาศยานดอนเมือง (ดอนเมือง)",
        "name_en": "Don Mueang International Airport (DMK)",
        "category": "government",
        "aliases": ["ดอนเมือง", "สนามบินดอนเมือง", "ท่าอากาศยานดอนเมือง", "don mueang", "dmk", "dmk airport"]
    },
    "ท่าอากาศยานสุวรรณภูมิ": {
        "lat": 13.6900, "lng": 100.7501,
        "name_th": "ท่าอากาศยานสุวรรณภูมิ (สมุทรปราการ/ลาดกระบัง)",
        "name_en": "Suvarnabhumi International Airport (BKK)",
        "category": "government",
        "aliases": ["สุวรรณภูมิ", "สนามบินสุวรรณภูมิ", "suvarnabhumi", "bkk airport", "bkk"]
    },
    "กรมอุตุนิยมวิทยา บางนา": {
        "lat": 13.6678, "lng": 100.6053,
        "name_th": "กรมอุตุนิยมวิทยา ถ.สุขุมวิท (บางนา)",
        "name_en": "Thai Meteorological Department (Bangna)",
        "category": "government",
        "aliases": ["กรมอุตุนิยมวิทยา", "tmd", "กรมอุตุ", "กรมอุตุนิยมวิทยา บางนา"]
    },
    "ศาลาว่าการกรุงเทพมหานคร ดินแดง": {
        "lat": 13.7694, "lng": 100.5516,
        "name_th": "ศาลาว่าการกรุงเทพมหานคร 2 ดินแดง (ดินแดง)",
        "name_en": "Bangkok City Hall 2 (Din Daeng)",
        "category": "government",
        "aliases": ["ศาลาว่าการกรุงเทพมหานคร", "กทม. 2", "กทม ดินแดง", "ศาลาว่าการ กทม", "bma city hall"]
    },

    # --- 6. Major Corridors & Districts ---
    "อโศก": {
        "lat": 13.7372, "lng": 100.5638,
        "name_th": "ถนนสุขุมวิท 21 อโศกมนตรี (วัฒนา)",
        "name_en": "Asoke / Sukhumvit 21",
        "category": "district",
        "aliases": ["อโศก", "asok", "asoke", "อโศกมนตรี", "สุขุมวิท 21", "ถ.อโศกมนตรี"]
    },
    "สุขุมวิท 21": {
        "lat": 13.7372, "lng": 100.5638,
        "name_th": "ถนนสุขุมวิท 21 อโศกมนตรี (วัฒนา)",
        "name_en": "Sukhumvit 21 Road",
        "category": "district",
        "aliases": ["สุขุมวิท 21", "sukhumvit 21"]
    },
    "สุขุมวิท": {
        "lat": 13.7335, "lng": 100.5828,
        "name_th": "ถนนสุขุมวิท (วัฒนา/คลองเตย)",
        "name_en": "Sukhumvit Road",
        "category": "district",
        "aliases": ["สุขุมวิท", "sukhumvit", "ถนนสุขุมวิท"]
    },
    "ทองหล่อ": {
        "lat": 13.7335, "lng": 100.5828,
        "name_th": "ซอยทองหล่อ สุขุมวิท 55 (วัฒนา)",
        "name_en": "Thong Lo (Sukhumvit 55)",
        "category": "district",
        "aliases": ["ทองหล่อ", "thonglor", "thong lo", "สุขุมวิท 55", "ซอยทองหล่อ"]
    },
    "อุดมสุข": {
        "lat": 13.6798, "lng": 100.6083,
        "name_th": "ซอยอุดมสุข สุขุมวิท 103 (บางนา)",
        "name_en": "Udom Suk (Sukhumvit 103)",
        "category": "district",
        "aliases": ["อุดมสุข", "udom suk", "udomsuk", "สุขุมวิท 103", "ซอยอุดมสุข", "bts อุดมสุข"]
    },
    "บางนา": {
        "lat": 13.6682, "lng": 100.6042,
        "name_th": "สี่แยกบางนา ถ.สุขุมวิท-บางนาตราด (บางนา)",
        "name_en": "Bang Na Intersection",
        "category": "district",
        "aliases": ["บางนา", "bang na", "bangna", "สี่แยกบางนา", "แยกบางนา"]
    },
    "สีลม": {
        "lat": 13.7285, "lng": 100.5343,
        "name_th": "ถนนสีลม (บางรัก)",
        "name_en": "Silom Road",
        "category": "district",
        "aliases": ["สีลม", "silom", "ถนนสีลม"]
    },
    "สาทร": {
        "lat": 13.7214, "lng": 100.5303,
        "name_th": "ถนนสาทรเหนือ/ใต้ (สาทร/บางรัก)",
        "name_en": "Sathorn Road",
        "category": "district",
        "aliases": ["สาทร", "sathorn", "sathon", "ถนนสาทร"]
    },
    "ลาดพร้าว": {
        "lat": 13.8136, "lng": 100.5615,
        "name_th": "ถนนลาดพร้าว (จตุจักร)",
        "name_en": "Lat Phrao",
        "category": "district",
        "aliases": ["ลาดพร้าว", "ladprao", "lat phrao", "ถนนลาดพร้าว"]
    },
    "รัชดาภิเษก": {
        "lat": 13.8219, "lng": 100.5752,
        "name_th": "ถนนรัชดาภิเษก (จตุจักร/ห้วยขวาง)",
        "name_en": "Ratchadaphisek Road",
        "category": "district",
        "aliases": ["รัชดา", "รัชดาภิเษก", "ratchada", "ratchadaphisek", "ถนนรัชดา"]
    },
    "รามคำแหง": {
        "lat": 13.7601, "lng": 100.6453,
        "name_th": "ถนนรามคำแหง / ลำสาลี (บางกะปิ)",
        "name_en": "Ramkhamhaeng / Lam Sali",
        "category": "district",
        "aliases": ["รามคำแหง", "ramkhamhaeng", "ลำสาลี", "lam sali", "บางกะปิ", "bang kapi"]
    },
    "แจ้งวัฒนะ": {
        "lat": 13.8863, "lng": 100.5658,
        "name_th": "ถนนแจ้งวัฒนะ (หลักสี่)",
        "name_en": "Chaeng Watthana Road",
        "category": "district",
        "aliases": ["แจ้งวัฒนะ", "chaeng watthana", "หลักสี่", "lak si", "ถนนแจ้งวัฒนะ"]
    },
    "อนุสาวรีย์ชัยสมรภูมิ": {
        "lat": 13.7651, "lng": 100.5383,
        "name_th": "อนุสาวรีย์ชัยสมรภูมิ (ราชเทวี)",
        "name_en": "Victory Monument",
        "category": "district",
        "aliases": ["อนุสาวรีย์ชัยสมรภูมิ", "victory monument", "อนุสาวรีย์ชัยฯ", "อนุสาวรีย์", "bts อนุสาวรีย์ชัยสมรภูมิ"]
    },
    "ปทุมวัน": {
        "lat": 13.7460, "lng": 100.5347,
        "name_th": "สี่แยกปทุมวัน ถ.พระราม 1 (ปทุมวัน)",
        "name_en": "Pathum Wan Intersection",
        "category": "district",
        "aliases": ["ปทุมวัน", "pathum wan", "pathumwan", "สี่แยกปทุมวัน"]
    }
}


class TokenStore:
    """Thread-safe user token storage with Redis backing and in-memory fallback."""

    def __init__(self):
        self._lock = threading.Lock()
        self._tokens: Dict[str, Dict[str, Any]] = {}
        self._states: Dict[str, Dict[str, Any]] = {}
        self._redis_client = None

        redis_url = os.getenv("REDIS_URL", f"redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}")
        try:
            import redis
            client = redis.Redis.from_url(redis_url, socket_timeout=1.0, socket_connect_timeout=1.0)
            client.ping()
            self._redis_client = client
        except Exception:
            self._redis_client = None

    def save_state(self, state: str, data: Dict[str, Any], ttl_seconds: int = 600) -> None:
        with self._lock:
            data_with_exp = dict(data)
            data_with_exp["_expires_at"] = time.time() + ttl_seconds
            self._states[state] = data_with_exp

        if self._redis_client:
            try:
                self._redis_client.setex(f"gcal:state:{state}", ttl_seconds, json.dumps(data))
            except Exception:
                pass

    def pop_state(self, state: str) -> Optional[Dict[str, Any]]:
        if self._redis_client:
            try:
                val = self._redis_client.get(f"gcal:state:{state}")
                if val:
                    self._redis_client.delete(f"gcal:state:{state}")
                    with self._lock:
                        self._states.pop(state, None)
                    return json.loads(val.decode("utf-8"))
            except Exception:
                pass

        with self._lock:
            val = self._states.pop(state, None)
            if val and val.get("_expires_at", 0) >= time.time():
                val.pop("_expires_at", None)
                return val
            return None

    def save_tokens(self, user_id: str, tokens: Dict[str, Any]) -> None:
        with self._lock:
            self._tokens[user_id] = dict(tokens)

        if self._redis_client:
            try:
                self._redis_client.setex(f"gcal:token:{user_id}", 30 * 86400, json.dumps(tokens))
            except Exception:
                pass

    def get_tokens(self, user_id: str) -> Optional[Dict[str, Any]]:
        if self._redis_client:
            try:
                val = self._redis_client.get(f"gcal:token:{user_id}")
                if val:
                    data = json.loads(val.decode("utf-8"))
                    with self._lock:
                        self._tokens[user_id] = data
                    return data
            except Exception:
                pass

        with self._lock:
            return self._tokens.get(user_id)

    def delete_tokens(self, user_id: str) -> None:
        with self._lock:
            self._tokens.pop(user_id, None)

        if self._redis_client:
            try:
                self._redis_client.delete(f"gcal:token:{user_id}")
            except Exception:
                pass


class GoogleOAuthManager:
    """Manages Google OAuth 2.0 Web Application flow, tokens, and credentials."""

    AUTH_URI = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URI = "https://oauth2.googleapis.com/token"
    DEFAULT_SCOPE = "https://www.googleapis.com/auth/calendar.readonly"

    def __init__(self, token_store: Optional[TokenStore] = None):
        self.client_id = os.getenv("GOOGLE_CLIENT_ID", "")
        self.client_secret = os.getenv("GOOGLE_CLIENT_SECRET", "")
        self.redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/api/v1/calendar/auth/callback")
        self.store = token_store or TokenStore()

    @property
    def is_configured(self) -> bool:
        return bool(self.client_id and self.client_secret)

    def generate_auth_url(self, user_id: str = "U1001", redirect_uri: Optional[str] = None) -> Tuple[str, str]:
        """Generates Google OAuth 2.0 consent URL with CSRF state token."""
        state = secrets.token_urlsafe(32)
        target_redirect = redirect_uri or self.redirect_uri

        self.store.save_state(state, {
            "user_id": user_id,
            "redirect_uri": target_redirect,
            "created_at": datetime.now(timezone.utc).isoformat()
        }, ttl_seconds=600)

        params = {
            "client_id": self.client_id or "dummy-client-id.apps.googleusercontent.com",
            "redirect_uri": target_redirect,
            "response_type": "code",
            "scope": self.DEFAULT_SCOPE,
            "access_type": "offline",
            "prompt": "consent",
            "state": state
        }
        auth_url = f"{self.AUTH_URI}?{urllib.parse.urlencode(params)}"
        return auth_url, state

    def exchange_code(self, code: str, state: str) -> Dict[str, Any]:
        """Validates CSRF state and exchanges authorization code for tokens."""
        state_data = self.store.pop_state(state)
        if not state_data:
            raise ValueError("Invalid or expired OAuth state parameter (CSRF detected)")

        user_id = state_data["user_id"]
        redirect_uri = state_data.get("redirect_uri", self.redirect_uri)

        # High-fidelity mock/sandbox fallback if credentials are unconfigured or code is mock
        if not self.is_configured or code.startswith("mock_"):
            mock_tokens = {
                "access_token": f"mock_access_token_{secrets.token_hex(16)}",
                "refresh_token": f"mock_refresh_token_{secrets.token_hex(16)}",
                "expires_at": time.time() + 3600,
                "scope": self.DEFAULT_SCOPE,
                "token_type": "Bearer",
                "user_id": user_id
            }
            self.store.save_tokens(user_id, mock_tokens)
            return mock_tokens

        resp = requests.post(
            self.TOKEN_URI,
            data={
                "code": code,
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        if resp.status_code != 200:
            raise RuntimeError(f"Google token exchange failed ({resp.status_code}): {resp.text}")

        token_data = resp.json()
        expires_in = token_data.get("expires_in", 3600)
        stored_tokens = {
            "access_token": token_data.get("access_token"),
            "refresh_token": token_data.get("refresh_token"),
            "expires_at": time.time() + expires_in,
            "scope": token_data.get("scope", self.DEFAULT_SCOPE),
            "token_type": token_data.get("token_type", "Bearer"),
            "user_id": user_id
        }
        self.store.save_tokens(user_id, stored_tokens)
        return stored_tokens

    def refresh_user_token(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Refreshes expired access token using stored refresh_token."""
        tokens = self.store.get_tokens(user_id)
        if not tokens or not tokens.get("refresh_token"):
            return None

        refresh_token = tokens["refresh_token"]

        if not self.is_configured or refresh_token.startswith("mock_"):
            tokens["access_token"] = f"mock_refreshed_token_{secrets.token_hex(16)}"
            tokens["expires_at"] = time.time() + 3600
            self.store.save_tokens(user_id, tokens)
            return tokens

        resp = requests.post(
            self.TOKEN_URI,
            data={
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        if resp.status_code != 200:
            return None

        data = resp.json()
        tokens["access_token"] = data.get("access_token", tokens["access_token"])
        tokens["expires_at"] = time.time() + data.get("expires_in", 3600)
        self.store.save_tokens(user_id, tokens)
        return tokens

    def get_valid_access_token(self, user_id: str) -> Optional[str]:
        tokens = self.store.get_tokens(user_id)
        if not tokens:
            return None

        # Check expiration with 60-second buffer
        if time.time() >= tokens.get("expires_at", 0) - 60:
            refreshed = self.refresh_user_token(user_id)
            if refreshed:
                return refreshed.get("access_token")
            return None

        return tokens.get("access_token")


def geocode_bangkok_location(location_text: Optional[str]) -> Dict[str, Any]:
    """
    Robust multi-pass location parser for Bangkok calendar entries:
    - Pass 1: Canonical / Longest Substring Match (Case-Insensitive)
    - Pass 2: Acronym / Thai Abbreviation Translation
    - Pass 3: Fuzzy sequence matching for minor typos
    - Pass 4: Safe Bangkok Center Fallback
    """
    if not location_text or not str(location_text).strip():
        return {
            "lat": 13.7563,
            "lng": 100.5018,
            "name_th": "กรุงเทพมหานคร (พิกัดกลาง)",
            "name_en": "Bangkok Center",
            "match_type": "fallback_city_center",
            "confidence": 0.0
        }

    # Truncate input string to realistic maximum venue address length (500 characters)
    raw = str(location_text).strip()[:500]
    # Normalize noise: room numbers, floor levels, building prefixes
    cleaned = re.sub(r'(?i)\b(?:room|meeting\s*room|suite|fl(?:oor)?\.?|ชั้น|ห้อง(?:ประชุม)?)\s*[\w\d\-]+', ' ', raw)
    cleaned = re.sub(r'[\(\)\[\],#]', ' ', cleaned)
    query_lower = raw.lower()
    cleaned_lower = cleaned.lower()

    # Pre-compile flattened alias index ordered by alias length descending
    alias_candidates: List[Tuple[str, str, Dict[str, Any]]] = []
    for landmark_key, data in BANGKOK_PLACES_GEOCODE.items():
        all_names = set(data.get("aliases", []) + [landmark_key, data.get("name_th", ""), data.get("name_en", "")])
        for alias in all_names:
            if alias:
                alias_candidates.append((alias.lower(), landmark_key, data))

    alias_candidates.sort(key=lambda x: len(x[0]), reverse=True)

    # Pass 1: Longest Substring Matching on Query and Cleaned Query
    for alias_lower, landmark_key, data in alias_candidates:
        if alias_lower in query_lower or alias_lower in cleaned_lower:
            return {
                "lat": data["lat"],
                "lng": data["lng"],
                "name_th": data["name_th"],
                "name_en": data.get("name_en", landmark_key),
                "matched_key": landmark_key,
                "match_type": "exact_substring",
                "confidence": 1.0
            }

    # Pass 2: Acronym / Abbreviation Mapping
    acronym_map = {
        "มศว": "มหาวิทยาลัยศรีนครินทรวิโรฒ ประสานมิตร",
        "swu": "มหาวิทยาลัยศรีนครินทรวิโรฒ ประสานมิตร",
        "จุฬา": "จุฬาลงกรณ์มหาวิทยาลัย",
        "จุฬาฯ": "จุฬาลงกรณ์มหาวิทยาลัย",
        "chula": "จุฬาลงกรณ์มหาวิทยาลัย",
        "cu": "จุฬาลงกรณ์มหาวิทยาลัย",
        "ม.เกษตร": "มหาวิทยาลัยเกษตรศาสตร์",
        "เกษตร": "มหาวิทยาลัยเกษตรศาสตร์",
        "ku": "มหาวิทยาลัยเกษตรศาสตร์",
        "kasetsart": "มหาวิทยาลัยเกษตรศาสตร์",
        "มธ": "มหาวิทยาลัยธรรมศาสตร์ ท่าพระจันทร์",
        "มธ.": "มหาวิทยาลัยธรรมศาสตร์ ท่าพระจันทร์",
        "tu": "มหาวิทยาลัยธรรมศาสตร์ ท่าพระจันทร์",
        "รพ.จุฬา": "โรงพยาบาลจุฬาลงกรณ์",
        "รพ.จุฬาฯ": "โรงพยาบาลจุฬาลงกรณ์",
        "รพ.ศิริราช": "โรงพยาบาลศิริราช",
        "รพ.รามา": "โรงพยาบาลรามาธิบดี",
        "รพ.รามาธิบดี": "โรงพยาบาลรามาธิบดี",
        "รพ.กรุงเทพ": "โรงพยาบาลกรุงเทพ",
        "dmk": "ท่าอากาศยานดอนเมือง",
        "bkk": "ท่าอากาศยานสุวรรณภูมิ",
        "qsncc": "ศูนย์การประชุมแห่งชาติสิริกิติ์",
        "cwt": "ศูนย์ราชการแจ้งวัฒนะ",
        "kmitl": "สถาบันเทคโนโลยีพระจอมเกล้าเจ้าคุณทหารลาดกระบัง",
        "utcc": "มหาวิทยาลัยหอการค้าไทย"
    }
    tokens_query = re.split(r'\s+', query_lower)
    tokens_cleaned = re.split(r'\s+', cleaned_lower)
    for acr, target_key in acronym_map.items():
        if acr in tokens_query or acr in tokens_cleaned or acr in query_lower:
            target_data = BANGKOK_PLACES_GEOCODE.get(target_key)
            if target_data:
                return {
                    "lat": target_data["lat"],
                    "lng": target_data["lng"],
                    "name_th": target_data["name_th"],
                    "name_en": target_data.get("name_en", target_key),
                    "matched_key": target_key,
                    "match_type": "acronym_lookup",
                    "confidence": 0.95
                }

    # Pass 3: Fuzzy SequenceMatcher for Typos
    best_score = 0.0
    best_match = None
    # Limit tokens to first 20 tokens and only tokens with length between 4 and 40 characters
    tokens = [t for t in re.split(r'\s+', cleaned_lower) if 4 <= len(t) <= 40][:20]

    for alias_lower, landmark_key, data in alias_candidates:
        if len(alias_lower) >= 4:
            for token in tokens:
                ratio = difflib.SequenceMatcher(None, token, alias_lower).ratio()
                if ratio > 0.80 and ratio > best_score:
                    best_score = ratio
                    best_match = (landmark_key, data)

    if best_match and best_score >= 0.80:
        l_key, l_data = best_match
        return {
            "lat": l_data["lat"],
            "lng": l_data["lng"],
            "name_th": l_data["name_th"],
            "name_en": l_data.get("name_en", l_key),
            "matched_key": l_key,
            "match_type": "fuzzy_match",
            "confidence": round(best_score, 2)
        }

    # Pass 4: Safe Fallback to Bangkok Center
    return {
        "lat": 13.7563,
        "lng": 100.5018,
        "name_th": f"พิกัดระบุ: {raw[:30]}",
        "name_en": f"Specified location: {raw[:30]}",
        "match_type": "fallback_city_center",
        "confidence": 0.3
    }


class GoogleCalendarCollector:
    """
    Connects to Google Calendar API to fetch user events and appointments.
    Supports:
    - User OAuth 2.0 Access & Refresh Flow
    - Service Account credentials (if provided)
    - Realistic Bangkok scenario dataset simulation
    - Robust 50+ landmark geocoding
    """

    def __init__(
        self,
        mode: str = "mock",
        credentials_path: Optional[str] = None,
        oauth_manager: Optional[GoogleOAuthManager] = None
    ):
        self.mode = mode
        self.credentials_path = credentials_path or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        self.oauth_manager = oauth_manager or GoogleOAuthManager()
        self._service = None

        if self.mode == "live" and self.credentials_path and os.path.exists(self.credentials_path):
            try:
                from google.oauth2 import service_account
                from googleapiclient.discovery import build
                creds = service_account.Credentials.from_service_account_file(
                    self.credentials_path,
                    scopes=[GoogleOAuthManager.DEFAULT_SCOPE]
                )
                self._service = build("calendar", "v3", credentials=creds)
                print("[GoogleCalendarCollector] Connected to live Google Calendar API.")
            except Exception as e:
                print(f"[GoogleCalendarCollector] Failed to init live Google Calendar ({e}). Using mock.")

    def get_upcoming_events(
        self,
        calendar_id: str = "primary",
        max_results: int = 10,
        user_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieves upcoming events with standardized location and geocoded coordinates.
        Checks for user OAuth credentials if user_id is provided.
        """
        if user_id:
            token = self.oauth_manager.get_valid_access_token(user_id)
            if token and self.mode != "mock":
                try:
                    from google.oauth2.credentials import Credentials
                    from googleapiclient.discovery import build
                    creds = Credentials(token)
                    service = build("calendar", "v3", credentials=creds)
                    return self._fetch_live_events_with_service(service, calendar_id, max_results)
                except Exception:
                    pass

        if self._service and self.mode == "live":
            return self._fetch_live_events_with_service(self._service, calendar_id, max_results)

        return self._generate_simulated_events(user_id)

    def _fetch_live_events_with_service(self, service: Any, calendar_id: str, max_results: int) -> List[Dict[str, Any]]:
        now_iso = datetime.now(timezone.utc).isoformat()
        try:
            events_result = service.events().list(
                calendarId=calendar_id,
                timeMin=now_iso,
                maxResults=max_results,
                singleEvents=True,
                orderBy="startTime"
            ).execute()

            items = events_result.get("items", [])
            normalized = []
            for item in items:
                normalized.append(self.parse_google_event(item))
            return normalized
        except Exception as e:
            print(f"[GoogleCalendarCollector] Live fetch error ({e}), reverting to simulation.")
            return self._generate_simulated_events()

    def parse_google_event(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Parses a Google Calendar item into the normalized domain event structure."""
        loc_str = str(item.get("location") or "")
        coords = self.geocode_location(loc_str)
        
        start_dict = item.get("start") or {}
        end_dict = item.get("end") or {}
        start = start_dict.get("dateTime") or start_dict.get("date") or ""
        end = end_dict.get("dateTime") or end_dict.get("date") or ""

        desc = str(item.get("description") or "")
        summary = str(item.get("summary") or "นัดหมายไม่มีชื่อ")

        # Detect outdoor activity
        outdoor_keywords = ("กลางแจ้ง", "สนาม", "กอล์ฟ", "วิ่ง", "outdoor", "field", "golf")
        is_outdoor = any(kw in desc.lower() or kw in summary.lower() for kw in outdoor_keywords)

        # Detect online meeting
        online_keywords = ("meet.google.com", "zoom.us", "teams.microsoft.com", "online", "ออนไลน์")
        is_online = any(kw in loc_str.lower() or kw in desc.lower() for kw in online_keywords)

        return {
            "event_id": item.get("id", f"evt_{secrets.token_hex(4)}"),
            "title": summary,
            "description": desc,
            "location_raw": loc_str,
            "location_name": coords["name_th"],
            "latitude": coords["lat"],
            "longitude": coords["lng"],
            "start_time": start,
            "end_time": end,
            "is_outdoor": is_outdoor,
            "is_online": is_online
        }

    def _generate_simulated_events(self, user_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Generates realistic Bangkok appointments:
        1. GCAL-EVT-001: Chaeng Watthana (Afternoon peak monsoon storm, high flood risk)
        2. GCAL-EVT-002: Thonglor (Evening rush hour rain, sluggish traffic)
        3. GCAL-EVT-003: Bangkok Kritha (Midday outdoor golf, extreme heatwave index)
        4. GCAL-EVT-004: Asok / Serm-Mit (Afternoon executive board meeting, convective cloudburst)
        5. GCAL-EVT-005: Siam Paragon (Midday clear commute, transit accessible)
        """
        bkk_tz = timezone(timedelta(hours=7))
        now = datetime.now(bkk_tz)
        today = now.date()
        tomorrow = today + timedelta(days=1)

        t1_start = datetime(today.year, today.month, today.day, 16, 30, tzinfo=bkk_tz).isoformat()
        t1_end = datetime(today.year, today.month, today.day, 18, 0, tzinfo=bkk_tz).isoformat()

        t2_start = datetime(today.year, today.month, today.day, 17, 30, tzinfo=bkk_tz).isoformat()
        t2_end = datetime(today.year, today.month, today.day, 19, 30, tzinfo=bkk_tz).isoformat()

        t3_start = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 30, tzinfo=bkk_tz).isoformat()
        t3_end = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0, tzinfo=bkk_tz).isoformat()

        t4_start = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0, tzinfo=bkk_tz).isoformat()
        t4_end = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 30, tzinfo=bkk_tz).isoformat()

        t5_start = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 0, tzinfo=bkk_tz).isoformat()
        t5_end = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 30, tzinfo=bkk_tz).isoformat()

        return [
            {
                "event_id": "GCAL-EVT-001",
                "title": "นัดตรวจรับงานระบบและส่งมอบเอกสาร ณ ศูนย์ราชการแจ้งวัฒนะ",
                "description": "พบทีมวิศวกรผู้ตรวจการ บรรยายสรุปหน้างานอาคารบี",
                "location_raw": "ศูนย์ราชการแจ้งวัฒนะ อาคาร B ถ.แจ้งวัฒนะ หลักสี่ กทม.",
                "location_name": "ศูนย์ราชการแจ้งวัฒนะ (หลักสี่)",
                "latitude": 13.8863,
                "longitude": 100.5658,
                "start_time": t1_start,
                "end_time": t1_end,
                "is_outdoor": False,
                "is_online": False
            },
            {
                "event_id": "GCAL-EVT-002",
                "title": "ทานข้าวเย็นและคุยงานกับ Partner (ซอยทองหล่อ)",
                "description": "นัดพบที่ร้านอาหารญี่ปุ่น สุขุมวิท 55 นำเอกสารสัญญาไปด้วย",
                "location_raw": "ซอยทองหล่อ สุขุมวิท 55 วัฒนา กรุงเทพฯ",
                "location_name": "ซอยทองหล่อ สุขุมวิท 55 (วัฒนา)",
                "latitude": 13.7335,
                "longitude": 100.5828,
                "start_time": t2_start,
                "end_time": t2_end,
                "is_outdoor": False,
                "is_online": False
            },
            {
                "event_id": "GCAL-EVT-003",
                "title": "กิจกรรมกอล์ฟกระชับมิตรกลางแจ้ง",
                "description": "ออกรอบ 9 หลุมช่วงเที่ยงกับทีมบริหารกลางแจ้ง",
                "location_raw": "สนามกอล์ฟกรุงเทพกรีฑา ซ.กรุงเทพกรีฑา สะพานสูง กรุงเทพฯ",
                "location_name": "สนามกอล์ฟกรุงเทพกรีฑา (สะพานสูง)",
                "latitude": 13.7475,
                "longitude": 100.6698,
                "start_time": t3_start,
                "end_time": t3_end,
                "is_outdoor": True,
                "is_online": False
            },
            {
                "event_id": "GCAL-EVT-004",
                "title": "ประชุมสรุปแผนงานประจำไตรมาส ณ อาคารเสริมมิตร (อโศก)",
                "description": "ประชุมกับฝ่ายบริหารและผู้ถือหุ้น ชั้น 18 อาคารเสริมมิตร ถ.อโศกมนตรี",
                "location_raw": "อาคารเสริมมิตร ทาวเวอร์ ถ.อโศกมนตรี วัฒนา กรุงเทพฯ",
                "location_name": "อาคารเสริมมิตร ถ.อโศกมนตรี (วัฒนา)",
                "latitude": 13.7372,
                "longitude": 100.5638,
                "start_time": t4_start,
                "end_time": t4_end,
                "is_outdoor": False,
                "is_online": False
            },
            {
                "event_id": "GCAL-EVT-005",
                "title": "นัดพบลูกค้าเพื่อนำเสนอโครงการ ณ สยามพารากอน",
                "description": "คุยงานแผนงานโปรเจกต์ใหม่ ร้านอาหารชั้น G สยามพารากอน",
                "location_raw": "สยามพารากอน ถ.พระราม 1 ปทุมวัน กรุงเทพฯ",
                "location_name": "สยามพารากอน (ปทุมวัน)",
                "latitude": 13.7460,
                "longitude": 100.5347,
                "start_time": t5_start,
                "end_time": t5_end,
                "is_outdoor": False,
                "is_online": False
            }
        ]

    def geocode_location(self, location_text: Optional[str]) -> Dict[str, Any]:
        """
        Geocodes text string to lat/lng. Matches against Bangkok landmark database
        or falls back to Bangkok center.
        """
        return geocode_bangkok_location(location_text)
