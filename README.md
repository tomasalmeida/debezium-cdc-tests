# Debezium connectors and filters

## Proposal

Create a CDC debezium connector to read from a mysql db and check what happens when the a filter to remove the events with `"op": "r"` and others. The 

## Running the demo

### Case 1: no filter (all events are sent)

```bash
 ./start-cluster.sh
```

Check (Control Center)[http://localhost:29021/clusters] to see events type R, C and U in the `server1.mydb.team` topic. DB changes are tracked in `schema-changes.mydb`.

### Case 2: filter read events

```bash
 ./start-cluster.sh
```

Check (Control Center)[http://localhost:29021/clusters] to see events type C and U in the `server1.mydb.team` topic. DB changes are tracked in `schema-changes.mydb`. Events of type R are filter out and not sent to the topic.

### Clean-up

Clean the docker cluster `docker-compose down -v`


## references

Thanks [vdesabou](https://github.com/vdesabou) and his [kafka-docker-playground](https://github.com/vdesabou/kafka-docker-playground) who helped to start this demo properly. Some files (to create the db properly for example) were based from his [Debezium MySQL source connector](https://github.com/vdesabou/kafka-docker-playground/tree/master/connect/connect-debezium-mysql-source) demo.
