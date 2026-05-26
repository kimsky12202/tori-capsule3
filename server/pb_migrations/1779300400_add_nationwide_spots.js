/// <reference path="../pb_data/types.d.ts" />

// 전국 테마 관광지(궁/탑/석탑/박물관/사찰)를 추가한다.
// 사진은 클라이언트가 관광지 이름으로 위키백과에서 자동으로 불러오므로
// image_url 은 비워둔다(관리자에서 지정 시 그 값이 우선).
// 좌표는 잘 알려진 위치 기준이며, 필요 시 관리자에서 미세조정 가능.

const spots = [
  // 경주
  {
    code: "BULGUKSA",
    name: "불국사",
    description: "유네스코 세계유산. 다보탑·석가탑이 있는 천년 고찰.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 129.332, lat: 35.7903 },
    radius_m: 350,
    sort_order: 51,
  },
  {
    code: "GYEONGJU_NAT_MUSEUM",
    name: "국립경주박물관",
    description: "신라 천년의 유물을 모은 대표 박물관.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 129.2278, lat: 35.8312 },
    radius_m: 300,
    sort_order: 52,
  },
  {
    code: "CHEOMSEONGDAE",
    name: "첨성대",
    description: "동양에서 가장 오래된 천문 관측대.",
    category: "landmark",
    icon: "tower",
    color: "#6B7A8F",
    location: { lon: 129.219, lat: 35.8347 },
    radius_m: 200,
    sort_order: 53,
  },
  // 부여
  {
    code: "JEONGNIMSA_PAGODA",
    name: "정림사지 오층석탑",
    description: "백제를 대표하는 국보 오층석탑.",
    category: "pagoda",
    icon: "temple",
    color: "#5D6D7E",
    location: { lon: 126.912, lat: 36.2792 },
    radius_m: 200,
    sort_order: 54,
  },
  {
    code: "BUYEO_NAT_MUSEUM",
    name: "국립부여박물관",
    description: "백제 문화를 전시하는 박물관.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 126.9197, lat: 36.2745 },
    radius_m: 300,
    sort_order: 55,
  },
  // 익산
  {
    code: "MIREUKSA_PAGODA",
    name: "미륵사지 석탑",
    description: "현존 최고·최대의 백제 석탑(국보).",
    category: "pagoda",
    icon: "temple",
    color: "#5D6D7E",
    location: { lon: 127.0277, lat: 36.0114 },
    radius_m: 250,
    sort_order: 56,
  },
  // 공주
  {
    code: "GONGJU_NAT_MUSEUM",
    name: "국립공주박물관",
    description: "무령왕릉 유물로 유명한 박물관.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 127.1185, lat: 36.4699 },
    radius_m: 300,
    sort_order: 57,
  },
  // 수원
  {
    code: "HWASEONG_HAENGGUNG",
    name: "화성행궁",
    description: "정조가 머물던 조선 최대 규모의 행궁.",
    category: "palace",
    icon: "castle",
    color: "#A93226",
    location: { lon: 127.0134, lat: 37.2811 },
    radius_m: 300,
    sort_order: 58,
  },
  {
    code: "SUWON_HWASEONG",
    name: "수원화성",
    description: "유네스코 세계유산으로 등재된 성곽.",
    category: "landmark",
    icon: "castle",
    color: "#8A6D3B",
    location: { lon: 127.015, lat: 37.288 },
    radius_m: 400,
    sort_order: 59,
  },
  // 부산
  {
    code: "BUSAN_TOWER",
    name: "부산타워",
    description: "용두산공원에 자리한 부산의 전망 타워.",
    category: "tower",
    icon: "tower",
    color: "#C0392B",
    location: { lon: 129.0323, lat: 35.1006 },
    radius_m: 200,
    sort_order: 60,
  },
  {
    code: "BEOMEOSA",
    name: "범어사",
    description: "금정산 자락의 영남 3대 사찰.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 129.0689, lat: 35.2843 },
    radius_m: 300,
    sort_order: 61,
  },
  // 합천
  {
    code: "HAEINSA",
    name: "해인사",
    description: "팔만대장경을 품은 법보사찰.",
    category: "temple",
    icon: "temple",
    color: "#7E6B5A",
    location: { lon: 128.0978, lat: 35.8009 },
    radius_m: 350,
    sort_order: 62,
  },
  // 광주
  {
    code: "GWANGJU_NAT_MUSEUM",
    name: "국립광주박물관",
    description: "호남 지역 문화유산을 전시하는 박물관.",
    category: "museum",
    icon: "gate",
    color: "#2E6B8A",
    location: { lon: 126.8872, lat: 35.1873 },
    radius_m: 300,
    sort_order: 63,
  },
  // 대구
  {
    code: "DAEGU_83_TOWER",
    name: "대구 83타워",
    description: "두류공원 이월드의 전망 타워.",
    category: "tower",
    icon: "tower",
    color: "#C0392B",
    location: { lon: 128.5665, lat: 35.8528 },
    radius_m: 200,
    sort_order: 64,
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
