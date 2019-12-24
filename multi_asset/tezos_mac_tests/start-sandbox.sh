#!/bin/bash

docker run --rm --name flextesa-sandbox --detach -p 20000:20000 registry.gitlab.com/tezos/flextesa:image-babylonbox-run babylonbox start
