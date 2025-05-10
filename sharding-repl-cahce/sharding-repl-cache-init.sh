#!/bin/bash

echo "Инициализация конфигурационного сервера"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id : "configReplSet",
  configsvr: true,
  members: [{ _id : 0, host : "configSrv:27017" }]
})
EOF

echo "Инициализация shard1 репликации"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id : "shard1ReplSet",
  members: [
    { _id : 0, host : "shard1:27018" },
    { _id : 1, host : "shard1_replica2:27021" },
    { _id : 2, host : "shard1_replica3:27022" }
  ]
})
EOF

echo "Инициализация shard2 репликации"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id : "shard2ReplSet",
  members: [
    { _id : 0, host : "shard2:27019" },
    { _id : 1, host : "shard2_replica2:27023" },
    { _id : 2, host : "shard2_replica3:27024" }
  ]
})
EOF

echo "Настройка mongos_router и добавление шардов"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27018");
sh.addShard("shard1ReplSet/shard1_replica2:27021");
sh.addShard("shard1ReplSet/shard1_replica3:27022");

sh.addShard("shard2ReplSet/shard2:27019");
sh.addShard("shard2ReplSet/shard2_replica2:27023");
sh.addShard("shard2ReplSet/shard2_replica3:27024");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });

use somedb;
for (var i = 0; i < 1000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i });

db.helloDoc.countDocuments();
EOF

echo "Кластер Mongo инициализирован и заполнен данными."