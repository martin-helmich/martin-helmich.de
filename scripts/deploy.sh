#!/bin/bash

eval $(ssh-agent)

ssh-add travis_rsa

rsync --delete -a travis@martin-helmich.de:/var/www/www.martin-helmich.de/
