#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

SEED_NODE_KEY=a52cb7fe64b154d192cebd35a0b129c80481f89dd94f2aa2978b71417304a858
SEED_PORT=9840
SEED_HOST=$(docker-machine ip starcoin-0)
SEED=/ip4/$SEED_HOST/tcp/$SEED_PORT/p2p/QmcejhDq4ubxLnx7sNENECJroAuepMiL6Zkjp63LMmwVaT

cfg_root=/mnt/volume_01/starcoin_cfg

function docker_rebuild(){
    echo  -e "*\n"'!'"starcoin"> $DIR/../target/debug/.dockerignore
    docker build -f $DIR/DockerfileCi -t starcoin:latest  $DIR/../target/debug/

}

function start_starcoin(){
    local host_name=$1
    local name=$2
    local port=$3
    local m_port=$4
    shift 4;
    eval $(docker-machine env $host_name)
    docker_rebuild
    docker rm -f $name 1>/dev/null
    docker-machine ssh $host_name rm -f $cfg_root/$name/*/starcoin.ipc
    docker run -td --restart=on-failure:1 -p $port:9840 -p $m_port:9101 -v $cfg_root/$name:/.starcoin --name $name starcoin -d /.starcoin $@
}

function start_halley_seed(){
    start_starcoin $1 $2 $3 $4 -n halley -s full --node-key $SEED_NODE_KEY
}

function start_halley_node(){
    start_starcoin $1 $2 $3 $4 -n halley -s full --seed $SEED
}

#TODO: start failed, clean all env and restart
start_halley_seed starcoin-0 starcoin-0 $SEED_PORT 9101
start_halley_node starcoin-0 starcoin-1 9841 9102
start_halley_node starcoin-0 starcoin-2 9842 9103