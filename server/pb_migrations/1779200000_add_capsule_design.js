/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = app.findCollectionByNameOrId("capsules");

  // 이미 추가된 경우 스킵 (멱등성 — 기존 마이그레이션들과 동일한 방어 패턴)
  if (collection.fields.getByName("design")) return;

  collection.fields.add(new Field({
    name: "design",
    type: "select",
    required: false,
    maxSelect: 1,
    // design key = 단일 기준값. 클라이언트 CapsuleItem.id / 에셋 폴더명 / Flame design 과 동일.
    values: ["base", "seoul", "gyeongju"],
  }));

  return app.save(collection);
}, (app) => {
  // 롤백
  const collection = app.findCollectionByNameOrId("capsules");
  collection.fields.removeByName("design");
  return app.save(collection);
});