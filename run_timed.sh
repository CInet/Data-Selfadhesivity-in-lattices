#!/bin/bash

/usr/bin/time -f '%C: user=%U system=%S real=%E cpu=%P maxres=%MK' -- "$@";
