#!/bin/bash

echo foo
sleep 2
echo bar
sleep 2
log_out=$(curl -s --data-binary @log.out https://paste.rs/)

echo $log_out
