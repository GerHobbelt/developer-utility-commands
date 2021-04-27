#! /bin/bash
#
# KILL all running apache instances
#

kill -9 $( ps ax | grep http | sed -e 's/\(\d*\) .*/\1/' )

