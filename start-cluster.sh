#!/bin/bash

#clean
docker compose down -v

# Start cluster
docker compose up -d

# Wait mainZookeeper is UP
ZOOKEEPER_STATUS=""
while [[ $ZOOKEEPER_STATUS != "imok" ]]; do
  echo "Waiting zookeeper UP..."
  sleep 1
  ZOOKEEPER_STATUS=$(echo ruok | docker compose exec mainZookeeper nc localhost 2181)
done
echo "Zookeeper ready!!"

# Wait brokers is UP
FOUND=''
while [[ $FOUND != "yes" ]]; do
  echo "Waiting Broker UP..."
  sleep 1
  FOUND=$(docker compose exec mainZookeeper zookeeper-shell mainZookeeper get /brokers/ids/1 &>/dev/null && echo 'yes')
done
echo "Broker ready!!"

while ! docker exec mysql mysqladmin --user=root --password=password ping --silent &> /dev/null ; do
    echo "Waiting for mysql to be ready..."
    sleep 2
done

echo "Create table"
docker exec -i mysql mysql --user=root --password=password --database=mydb << EOF
USE mydb;

CREATE TABLE team (
  id            INT          NOT NULL PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(255) NOT NULL,
  email         VARCHAR(255) NOT NULL,
  last_modified DATETIME     NOT NULL
);


INSERT INTO team (
  name,
  email,
  last_modified
) VALUES (
  'kafka',
  'kafka@apache.org',
  NOW()
);

ALTER TABLE team AUTO_INCREMENT = 101;
describe team;
select * from team;
EOF

echo "Adding an element to the table"
docker exec -i mysql mysql --user=root --password=password --database=mydb << EOF
USE mydb;

INSERT INTO team (
  name,
  email,
  last_modified
) VALUES (
  'another',
  'another@apache.org',
  NOW()
);
EOF

echo "select an element to the table"
docker exec -i mysql mysql --user=root --password=password --database=mydb << EOF
USE mydb;

SELECT * FROM team;
EOF


HEADER="Content-Type: application/json"
DATA=$(cat data/mysql-cdc.json)

RETCODE=1
while [ $RETCODE -ne 0 ]
do
  curl -f -X POST -H "${HEADER}" --data "${DATA}" http://localhost:8083/connectors
  RETCODE=$?
  if [ $RETCODE -ne 0 ]
  then
    echo "Failed to submit connector to Connect. This could be because the Connect worker is not yet started. Will retry in 10 seconds"
  fi
  #backoff
  sleep 10
done
echo "mysql cdc connector configured"

echo "Adding an element to the table"
docker exec -i mysql mysql --user=root --password=password --database=mydb << EOF
USE mydb;

INSERT INTO team (
  name,
  email,
  last_modified
) VALUES (
  'another-other',
  'another@apache.org',
  NOW()
);
EOF

echo "select an element to the table"
docker exec -i mysql mysql --user=root --password=password --database=mydb << EOF
USE mydb;

ALTER TABLE team AUTO_INCREMENT = 201;
describe team;
select * from team;
EOF


# update mail where name = kafka
docker exec -i mysql mysql --user=root --password=password --database=mydb << EOF
USE mydb;

UPDATE team 
  SET 
    email = 'updatedmail@apache.org',
    last_modified = NOW() 
  WHERE 
    name = 'kafka';
EOF


# docker exec -i mainSchemaregistry kafka-avro-console-consumer --topic server1.mydb.team --from-beginning --bootstrap-server mainKafka:9092 --property schema.registry.url=http://localhost:8081 