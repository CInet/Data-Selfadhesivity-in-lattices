#!/bin/bash

perl mod.pl 4 sg4sa/all | while read G;
  do grep -q "$G" pr4/all || echo "$G";
  done >sg4sasa/sg4sa-minus-pr4
perl sg4sasa/sasa.pl sg4sasa/sg4sa-minus-pr4 >sg4sasa/all 2>sg4sasa/sasa.log
cat pr4/all >>sg4sasa/all
