#!/usr/bin/env python

import argparse
import boto.ec2
import json
import os
import pprint
import yaml

abspath = os.path.abspath(__file__)
dirname = os.path.dirname(abspath)
os.chdir(dirname)

f = open("group_vars/all.yml", "r")
default = yaml.load(f)
f.close()

region = default["aws_region"]
bench = default["bench"]
dbprofile = default["dbprofile"]
keypair = default["keypair"]

parser = argparse.ArgumentParser()
parser.add_argument("--hosts", help="List the hosts for the specified group")
parser.add_argument("--list", help="List the whole inventory", action="store_true")
args = parser.parse_args()

ec2 = boto.ec2.connect_to_region(region)
reservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag-key": "bench_role"})
instances = [i for r in reservations for i in r.instances]
dbreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "db", "tag:dbprofile": "*" + dbprofile + "*"})
dbinstances = [i for r in dbreservations for i in r.instances]
mongodbreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "db", "tag:dbprofile": "*mongodb*"})
mongodbinstances = [i for r in mongodbreservations for i in r.instances]
postgresreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "db", "tag:dbprofile": "*postgres*"})
postgresinstances = [i for r in postgresreservations for i in r.instances]
elasticreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "elastic"})
elasticinstances = [i for r in elasticreservations for i in r.instances]
kafkareservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "kafka"})
kafkainstances = [i for r in kafkareservations for i in r.instances]
monitorreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "monitor"})
monitorinstances = [i for r in monitorreservations for i in r.instances]
gatlingreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "gatling"})
gatlinginstances = [i for r in gatlingreservations for i in r.instances]
nuxeospotreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "nuxeospot"})
nuxeospotinstances = [i for r in nuxeospotreservations for i in r.instances]

hostvars = {}
groups = {}

allinstances = []
allids = []
for i in instances + dbinstances + mongodbinstances + postgresinstances + elasticinstances + kafkainstances + monitorinstances + gatlinginstances + nuxeospotinstances:
    if i.id not in allids:
        allinstances.append(i)
        allids.append(i.id)

for i in allinstances:
    #pprint.pprint (i.__dict__)
    state = i._state.name
    if state != "running":
        continue
    role = i.tags["bench_role"]
    if keypair == "Jenkins":
        address = i.private_ip_address
    else:
        address = i.ip_address
    if role not in groups:
        groups[role] = {"hosts": []}
    if role == "db" and i.tags["dbprofile"].find(dbprofile) == -1:
        pass
    else:
        groups[role]["hosts"].append(address)
    if role == "db" and i.tags["dbprofile"].find("mongodb") != -1:
        if "mongodb" not in groups:
            groups["mongodb"] = {"hosts": []}
        groups["mongodb"]["hosts"].append(address)
    if role == "db" and i.tags["dbprofile"].find("postgres") != -1:
        if "postgres" not in groups:
            groups["postgres"] = {"hosts": []}
        groups["postgres"]["hosts"].append(address)
    hvars = {}
    hvars["id"] = i.id
    hvars["state"] = state
    hvars["image_id"] = i.image_id
    hvars["public_ip"] = i.ip_address
    hvars["private_ip"] = i.private_ip_address
    hvars["bench"] = i.tags.get('bench', '')
    hvars["bench_tag"] = i.tags.get('bench_tag', 'unknown')
    hostvars[address] = hvars


inventory = {"_meta": {"hostvars": hostvars}}
inventory.update(groups)

if "nuxeo" not in inventory:
    inventory["nuxeo"] = {}
if "elastic" not in inventory:
    inventory["elastic"] = {}
if "mongodb" not in inventory:
    inventory["mongodb"] = {}
if "postgres" not in inventory:
    inventory["postgres"] = {}
if "kafka" not in inventory:
    inventory["kafka"] = {}
if "gatling" not in inventory:
    inventory["gatling"] = {}
if "nuxeospot" not in inventory:
    inventory["nuxeospot"] = {}
if "monitor" not in inventory:
    inventory["monitor"] = {}
inventory["nuxeo"]["vars"] = {"db_hosts": [], "elastic_hosts": [], "mongodb_hosts": [], "postgres_hosts": [], "kafka_hosts": [], "monitor_hosts": []}
inventory["nuxeospot"]["vars"] = {"db_hosts": [], "elastic_hosts": [], "mongodb_hosts": [], "postgres_hosts": [], "kafka_hosts": [], "monitor_hosts": []}
inventory["elastic"]["vars"] = {"monitor_hosts": []}
inventory["mongodb"]["vars"] = {"monitor_hosts": []}
inventory["postgres"]["vars"] = {"monitor_hosts": []}
inventory["kafka"]["vars"] = {"monitor_hosts": []}
inventory["monitor"]["vars"] = {"monitor_hosts": []}
inventory["gatling"]["vars"] = {"monitor_hosts": []}

if "db" in groups:
    for i in groups["db"]["hosts"]:
        inventory["nuxeo"]["vars"]["db_hosts"].append(hostvars[i]["private_ip"])
        inventory["nuxeospot"]["vars"]["db_hosts"].append(hostvars[i]["private_ip"])
if "elastic" in groups:
    for i in groups["elastic"]["hosts"]:
        inventory["nuxeo"]["vars"]["elastic_hosts"].append(hostvars[i]["private_ip"])
        inventory["nuxeospot"]["vars"]["elastic_hosts"].append(hostvars[i]["private_ip"])
if "mongodb" in groups:
    for i in groups["mongodb"]["hosts"]:
        inventory["nuxeo"]["vars"]["mongodb_hosts"].append(hostvars[i]["private_ip"])
        inventory["nuxeospot"]["vars"]["mongodb_hosts"].append(hostvars[i]["private_ip"])
if "postgres" in groups:
    for i in groups["postgres"]["hosts"]:
        inventory["nuxeo"]["vars"]["postgres_hosts"].append(hostvars[i]["private_ip"])
        inventory["nuxeospot"]["vars"]["postgres_hosts"].append(hostvars[i]["private_ip"])
if "kafka" in groups:
    for i in groups["kafka"]["hosts"]:
        inventory["nuxeo"]["vars"]["kafka_hosts"].append(hostvars[i]["private_ip"])
        inventory["nuxeospot"]["vars"]["kafka_hosts"].append(hostvars[i]["private_ip"])
if "monitor" in groups:
    for i in groups["monitor"]["hosts"]:
        inventory["nuxeo"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["nuxeospot"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["elastic"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["mongodb"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["postgres"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["kafka"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["monitor"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])
        inventory["gatling"]["vars"]["monitor_hosts"].append(hostvars[i]["private_ip"])

#print inventory

if args.hosts:
    print(" ".join(inventory[args.hosts]["hosts"]))
else:
    print(json.dumps(inventory, sort_keys=True, indent=2))

