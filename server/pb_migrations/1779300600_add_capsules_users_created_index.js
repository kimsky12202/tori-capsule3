/// <reference path="../pb_data/types.d.ts" />

// capsules.created (autodate) 컬럼은 collection.save() 가 끝난 뒤에야
// 실제 SQL 컬럼이 잡히기 때문에, 같은 마이그레이션에서 인덱스를 만들면
// 'no such column: created' 로 실패한다. 그래서 인덱스만 별도 마이그레이션으로 분리.
migrate((app) => {
  const capsules = app.findCollectionByNameOrId("capsules");
  const indexName = "idx_capsules_users_created";

  const exists = (capsules.indexes || []).some((sql) =>
    sql.toLowerCase().includes(indexName.toLowerCase())
  );
  if (!exists) {
    capsules.indexes = [
      ...(capsules.indexes || []),
      `CREATE INDEX ${indexName} ON capsules (users, created)`,
    ];
    app.save(capsules);
  }
}, (app) => {
  try {
    const capsules = app.findCollectionByNameOrId("capsules");
    const indexName = "idx_capsules_users_created";
    capsules.indexes = (capsules.indexes || []).filter(
      (sql) => !sql.toLowerCase().includes(indexName.toLowerCase())
    );
    app.save(capsules);
  } catch (_) {}
});
