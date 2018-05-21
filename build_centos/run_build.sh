#!/bin/bash

docker run --rm -v $(pwd):/code:ro -v $(pwd)/dist:/code/dist -w /code --entrypoint=/code/build_centos/entrypoint.sh nachohidalgo89/centos-phoenix:20180508124817
