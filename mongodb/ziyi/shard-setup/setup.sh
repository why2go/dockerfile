#/bin/bash

CFGRS0_NAME=cfgrs0
CFGRS0_REPLICA_1=${CFGRS0_NAME}-1
CFGRS0_REPLICA_2=${CFGRS0_NAME}-2
CFGRS0_REPLICA_3=${CFGRS0_NAME}-3

CFGSVR_PORT=27019

DBRS0_NAME=dbrs0
DBRS0_REPLICA_1=${DBRS0_NAME}-1
DBRS0_REPLICA_2=${DBRS0_NAME}-2
DBRS0_REPLICA_3=${DBRS0_NAME}-3

DBRS1_NAME=dbrs1
DBRS1_REPLICA_1=${DBRS1_NAME}-1
DBRS1_REPLICA_2=${DBRS1_NAME}-2
DBRS1_REPLICA_3=${DBRS1_NAME}-3

DBSVR_PORT=27018

until mongosh --host ${CFGRS0_REPLICA_1} --port ${CFGSVR_PORT} --quiet <<EOF
exit
EOF
do
  sleep 5
done
mongosh --host ${CFGRS0_REPLICA_1} --port ${CFGSVR_PORT} --quiet <<EOF
rs.initiate(
  {
    _id: "${CFGRS0_NAME}",
    configsvr: true,
    members: [
      { _id : 0, host : "${CFGRS0_REPLICA_1}:${CFGSVR_PORT}", priority: 2 },
      { _id : 1, host : "${CFGRS0_REPLICA_2}:${CFGSVR_PORT}", priority: 1 },
      { _id : 2, host : "${CFGRS0_REPLICA_3}:${CFGSVR_PORT}", priority: 1 }
    ]
  }
)
EOF

for rs in 0 1
do
  until mongosh --host `eval echo '$'{DBRS"${rs}"_REPLICA_1}` --port ${DBSVR_PORT} --quiet <<EOF
exit
EOF
  do
    sleep 5
  done
mongosh --host `eval echo '$'{DBRS"${rs}"_REPLICA_1}` --port ${DBSVR_PORT} --quiet <<EOF
rs.initiate(
  {
    _id: "`eval echo '$'{DBRS"${rs}"_NAME}`",
    members: [
      { _id : 0, host : "`eval echo '$'{DBRS"${rs}"_REPLICA_1}`:${DBSVR_PORT}", priority: 2 },
      { _id : 1, host : "`eval echo '$'{DBRS"${rs}"_REPLICA_2}`:${DBSVR_PORT}", priority: 1 },
      { _id : 2, host : "`eval echo '$'{DBRS"${rs}"_REPLICA_3}`:${DBSVR_PORT}", priority: 1 }
    ]
  }
)
EOF
done

# mongos --configdb ${CFGRS0_NAME}/${CFGRS0_REPLICA_1}:${CFGSVR_PORT},\
# ${CFGRS0_REPLICA_2}:${CFGSVR_PORT},${CFGRS0_REPLICA_3}:${CFGSVR_PORT} \
# --bind_ip_all &

MONGOS=mongos-1

# 配置shard
until mongosh --host ${MONGOS} --quiet <<EOF
exit
EOF
do
  sleep 5
done

mongosh --host ${MONGOS} --quiet <<EOF
sh.addShard("${DBRS0_NAME}/${DBRS0_REPLICA_1}:${DBSVR_PORT},${DBRS0_REPLICA_2}:${DBSVR_PORT},${DBRS0_REPLICA_3}:${DBSVR_PORT}")
sh.addShard("${DBRS1_NAME}/${DBRS1_REPLICA_1}:${DBSVR_PORT},${DBRS1_REPLICA_2}:${DBSVR_PORT},${DBRS1_REPLICA_3}:${DBSVR_PORT}")
EOF
