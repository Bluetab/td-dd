#!/bin/bash

rm ~/.ssh/truedat.pem
cp -f ~/.ssh/config.bk ~/.ssh/config
rm -f ~/datadictionary.prod.secret.exs
