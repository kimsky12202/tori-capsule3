/// <reference path="../pb_data/types.d.ts" />

// 전국 명소 추가분(2차): 강릉/안동/영주/양산/구례/순천/보은/진주/부여/천안.
// 기존 테마(궁/탑/석탑/박물관/사찰/명소) 유지.

const spots = [
  // 강릉
  {
    code: "OJUKHEON",
    name: "오죽헌",
    description: "신사임당·이이의 생가. 보물·사적.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 128.8775, lat: 37.78 },
    radius_m: 250,
    sort_order: 71,
  },
  {
    code: "GYEONGPODAE",
    name: "경포대",
    description: "관동팔경의 으뜸. 보름달 다섯 개를 본다는 누각.",
    category: "landmark",
    icon: "castle",
    color: "#8A6D3B",
    location: { lon: 128.907, lat: 37.7958 },
    radius_m: 300,
    sort_order: 72,
  },
  // 안동
  {
    code: "HAHOE_VILLAGE",
    name: "하회마을",
    description: "유네스코 세계유산 전통 민속마을.",
    category: "landmark",
    icon: "village",
    color: "#7E6B5A",
    location: { lon: 128.5189, lat: 36.5394 },
    radius_m: 400,
    sort_order: 73,
  },
  {
    code: "DOSAN_SEOWON",
    name: "도산서원",
    description: "퇴계 이황이 후학을 가르친 조선의 대표 서원.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 128.8451, lat: 36.7102 },
    radius_m: 300,
    sort_order: 74,
  },
  // 영주
  {
    code: "BUSEOKSA",
    name: "부석사",
    description: "유네스코 세계유산. 무량수전(국보)이 있는 사찰.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 128.6873, lat: 36.9846 },
    radius_m: 350,
    sort_order: 75,
  },
  // 양산
  {
    code: "TONGDOSA",
    name: "통도사",
    description: "불보(佛寶) 사찰. 부처의 진신사리를 모신 곳.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 129.0654, lat: 35.4854 },
    radius_m: 350,
    sort_order: 76,
  },
  // 구례
  {
    code: "HWAEOMSA",
    name: "화엄사",
    description: "지리산 자락의 천년 고찰. 각황전(국보).",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 127.5021, lat: 35.3604 },
    radius_m: 300,
    sort_order: 77,
  },
  // 순천
  {
    code: "SONGGWANGSA",
    name: "송광사",
    description: "승보(僧寶) 사찰. 한국 삼보사찰 중 하나.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 127.2787, lat: 35.0023 },
    radius_m: 300,
    sort_order: 78,
  },
  // 보은
  {
    code: "BEOPJUSA",
    name: "법주사",
    description: "속리산 자락. 팔상전(국보)이 있는 천년 사찰.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 127.8333, lat: 36.5413 },
    radius_m: 350,
    sort_order: 79,
  },
  // 진주
  {
    code: "JINJU_FORTRESS",
    name: "진주성",
    description: "임진왜란 격전지. 촉석루가 자리한 성곽.",
    category: "landmark",
    icon: "castle",
    color: "#8A6D3B",
    location: { lon: 128.0791, lat: 35.1893 },
    radius_m: 350,
    sort_order: 80,
  },
  // 부여
  {
    code: "BUSOSANSEONG",
    name: "부소산성",
    description: "백제 사비 도성의 배후 산성.",
    category: "landmark",
    icon: "castle",
    color: "#8A6D3B",
    location: { lon: 126.9106, lat: 36.281 },
    radius_m: 350,
    sort_order: 81,
  },
  // 천안
  {
    code: "INDEPENDENCE_HALL",
    name: "독립기념관",
    description: "한민족의 자주독립 역사를 전시.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 127.209, lat: 36.7794 },
    radius_m: 400,
    sort_order: 82,
  },
];

migrate((app) => {
  const collection = app.findCollectionByNameOrId("tourist_spots");
  for (const seed of spots) {
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
  for (const seed of spots) {
    try {
      const r = app.findFirstRecordByData("tourist_spots", "code", seed.code);
      app.delete(r);
    } catch (_) {}
  }
});
