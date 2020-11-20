#!/bin/bash

docker run --rm --name flextesa-sandbox -e block_time=5 --detach -p 20000:20000 tqtezos/flextesa:20200925 delphibox start


