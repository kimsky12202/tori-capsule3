/// <reference path="../pb_data/types.d.ts" />

const touristSpotSeeds = [
  {
    code: "GYEONGBOKGUNG",
    name: "경복궁",
    description: "조선 왕조의 법궁. 광화문과 근정전을 둘러보세요.",
    category: "palace",
    icon: "gate",
    color: "#C0392B",
    location: { lon: 126.977, lat: 37.5796 },
    radius_m: 300,
    sort_order: 10,
  },
  {
    code: "NSEOUL_TOWER",
    name: "N서울타워",
    description: "남산 정상의 서울 전망 명소.",
    category: "landmark",
    icon: "tower",
    color: "#8E44AD",
    location: { lon: 126.9882, lat: 37.5512 },
    radius_m: 300,
    sort_order: 20,
  },
  {
    code: "BUKCHON_HANOK",
    name: "북촌한옥마을",
    description: "전통 한옥이 모여 있는 골목 마을.",
    category: "village",
    icon: "village",
    color: "#D68910",
    location: { lon: 126.983, lat: 37.5826 },
    radius_m: 250,
    sort_order: 30,
  },
  {
    code: "MYEONGDONG",
    name: "명동거리",
    description: "쇼핑과 길거리 음식의 중심지.",
    category: "shopping",
    icon: "street",
    color: "#E84393",
    location: { lon: 126.985, lat: 37.5636 },
    radius_m: 300,
    sort_order: 40,
  },
  {
    code: "DDP",
    name: "동대문디자인플라자",
    description: "자하 하디드가 설계한 미래형 건축물.",
    category: "modern",
    icon: "modern",
    color: "#2C3E50",
    location: { lon: 127.0095, lat: 37.5669 },
    radius_m: 250,
    sort_order: 50,
  },
  {
    code: "HANGANG_YEOUIDO",
    name: "여의도한강공원",
    description: "한강변 산책과 피크닉 명소.",
    category: "park",
    icon: "park",
    color: "#27AE60",
    location: { lon: 126.9337, lat: 37.5283 },
    radius_m: 400,
    sort_order: 60,
  },
  {
    code: "BONGEUNSA",
    name: "봉은사",
    description: "강남 도심 속 천년 고찰.",
    category: "temple",
    icon: "temple",
    color: "#B9770E",
    location: { lon: 127.0577, lat: 37.515 },
    radius_m: 250,
    sort_order: 70,
  },
  {
    code: "BANPO_BRIDGE",
    name: "반포대교 달빛무지개분수",
    description: "밤에 펼쳐지는 한강 분수쇼.",
    category: "bridge",
    icon: "bridge",
    color: "#2980B9",
    location: { lon: 126.9961, lat: 37.513 },
    radius_m: 250,
    sort_order: 80,
  },
];

migrate((app) => {
  const collection = app.findCollectionByNameOrId("tourist_spots");

  for (const seed of touristSpotSeeds) {
    let existing = null;
    try {
      existing = app.findFirstRecordByData("tourist_spots", "code", seed.code);
    } catch (_) {
      existing = null;
    }

    if (existing) {
      continue;
    }

    const record = new Record(collection, Object.assign({}, seed, { is_active: true }));
    app.save(record);
  }
}, (app) => {
  for (const seed of touristSpotSeeds) {
    try {
      const record = app.findFirstRecordByData("tourist_spots", "code", seed.code);
      app.delete(record);
    } catch (_) {
      // ignore if record is already deleted
    }
  }
});
