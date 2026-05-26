/// <reference path="../pb_data/types.d.ts" />

// 테마(궁/탑/석탑/박물관) 중심으로 관광지 재구성.
// 기존 시드(1779300200) 중 테마에서 벗어난 것은 비활성화하고,
// 궁·석탑·박물관을 추가한다. (클라이언트 markerIcon 이 지원하는 icon 키만 사용)
//   - 궁    -> "castle"
//   - 탑    -> "tower"
//   - 석탑  -> "temple" (클라이언트에 전용 석탑 아이콘이 없어 가장 가까운 temple 사용)
//   - 박물관 -> "gate"  (account_balance = 기둥 있는 건물, 박물관에 적합)

const newSpots = [
  // 궁 (palace)
  {
    code: "CHANGDEOKGUNG",
    name: "창덕궁",
    description: "유네스코 세계유산. 후원이 아름다운 조선 궁궐.",
    category: "palace",
    icon: "castle",
    color: "#A93226",
    location: { lon: 126.991, lat: 37.5794 },
    radius_m: 300,
    sort_order: 11,
  },
  {
    code: "DEOKSUGUNG",
    name: "덕수궁",
    description: "근대 건축과 어우러진 도심 속 궁궐.",
    category: "palace",
    icon: "castle",
    color: "#B9533A",
    location: { lon: 126.9751, lat: 37.5658 },
    radius_m: 250,
    sort_order: 12,
  },
  {
    code: "CHANGGYEONGGUNG",
    name: "창경궁",
    description: "조선 왕실의 생활 공간이었던 궁궐.",
    category: "palace",
    icon: "castle",
    color: "#922B21",
    location: { lon: 126.9947, lat: 37.5789 },
    radius_m: 300,
    sort_order: 13,
  },
  // 석탑 (stone pagoda)
  {
    code: "WONGAKSA_PAGODA",
    name: "원각사지 십층석탑",
    description: "탑골공원에 있는 국보 대리석 십층석탑.",
    category: "pagoda",
    icon: "temple",
    color: "#5D6D7E",
    location: { lon: 126.9885, lat: 37.571 },
    radius_m: 200,
    sort_order: 31,
  },
  // 박물관 (museum)
  {
    code: "NAT_MUSEUM_KOREA",
    name: "국립중앙박물관",
    description: "한국 최대 규모의 국립 박물관.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 126.9803, lat: 37.524 },
    radius_m: 350,
    sort_order: 41,
  },
  {
    code: "NAT_PALACE_MUSEUM",
    name: "국립고궁박물관",
    description: "조선 왕실·대한제국 유물을 전시하는 박물관.",
    category: "museum",
    icon: "gate",
    color: "#8A6D3B",
    location: { lon: 126.977, lat: 37.5759 },
    radius_m: 250,
    sort_order: 42,
  },
  {
    code: "WAR_MEMORIAL",
    name: "전쟁기념관",
    description: "전쟁의 역사를 전시하는 대규모 기념관.",
    category: "museum",
    icon: "gate",
    color: "#566573",
    location: { lon: 126.9774, lat: 37.5371 },
    radius_m: 350,
    sort_order: 43,
  },
];

// 테마(궁/탑/석탑/박물관)에서 벗어나 비활성화할 기존 관광지.
const deactivateCodes = [
  "MYEONGDONG",
  "DDP",
  "HANGANG_YEOUIDO",
  "BANPO_BRIDGE",
  "BUKCHON_HANOK",
];

migrate((app) => {
  const collection = app.findCollectionByNameOrId("tourist_spots");

  // 1) 기존 경복궁 아이콘을 궁 테마(castle)로 통일.
  try {
    const gbg = app.findFirstRecordByData("tourist_spots", "code", "GYEONGBOKGUNG");
    gbg.set("icon", "castle");
    app.save(gbg);
  } catch (_) {}

  // 2) 테마 외 관광지 비활성화 (데이터는 보존, 지도에서만 숨김).
  for (const code of deactivateCodes) {
    try {
      const r = app.findFirstRecordByData("tourist_spots", "code", code);
      r.set("is_active", false);
      app.save(r);
    } catch (_) {}
  }

  // 3) 궁·석탑·박물관 추가 (멱등).
  for (const seed of newSpots) {
    let existing = null;
    try {
      existing = app.findFirstRecordByData("tourist_spots", "code", seed.code);
    } catch (_) {
      existing = null;
    }
    if (existing) continue;
    const record = new Record(collection, Object.assign({}, seed, { is_active: true }));
    app.save(record);
  }
}, (app) => {
  // 롤백: 추가분 삭제 + 비활성화/아이콘 원복.
  for (const seed of newSpots) {
    try {
      const r = app.findFirstRecordByData("tourist_spots", "code", seed.code);
      app.delete(r);
    } catch (_) {}
  }
  for (const code of deactivateCodes) {
    try {
      const r = app.findFirstRecordByData("tourist_spots", "code", code);
      r.set("is_active", true);
      app.save(r);
    } catch (_) {}
  }
  try {
    const gbg = app.findFirstRecordByData("tourist_spots", "code", "GYEONGBOKGUNG");
    gbg.set("icon", "gate");
    app.save(gbg);
  } catch (_) {}
});
