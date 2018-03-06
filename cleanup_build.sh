#!/bin/bash

rm ~/.ssh/truedat.pem
cp -f ~/.ssh/config.bk ~/.ssh/config
rm -f ~/td_dq.prod.secret.exs
