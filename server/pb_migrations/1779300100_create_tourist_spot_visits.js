/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  try {
    app.findCollectionByNameOrId("tourist_spot_visits");
    return;
  } catch (_) {}

  const usersCollection = app.findCollectionByNameOrId("users");
  const spotsCollection = app.findCollectionByNameOrId("tourist_spots");
  const capsulesCollection = app.findCollectionByNameOrId("capsules");

  const visitsCollection = new Collection({
    name: "tourist_spot_visits",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "user",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "spot",
        type: "relation",
        required: true,
        collectionId: spotsCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "capsule",
        type: "relation",
        required: false,
        collectionId: capsulesCollection.id,
        maxSelect: 1,
        cascadeDelete: false,
      },
      {
        name: "source",
        type: "text",
        required: false,
      },
      {
        name: "visited_at",
        type: "date",
        required: false,
      },
      {
        name: "latitude",
        type: "number",
        required: false,
      },
      {
        name: "longitude",
        type: "number",
        required: false,
      },
      {
        name: "created",
        type: "autodate",
        onCreate: true,
        onUpdate: false,
      },
      {
        name: "updated",
        type: "autodate",
        onCreate: true,
        onUpdate: true,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_tsv_user_spot ON tourist_spot_visits (user, spot)",
      "CREATE INDEX idx_tsv_user ON tourist_spot_visits (user)",
    ],
  });

  return app.save(visitsCollection);
}, (app) => {
  try {
    const visitsCollection = app.findCollectionByNameOrId("tourist_spot_visits");
    return app.delete(visitsCollection);
  } catch (_) {
    return;
  }
});
