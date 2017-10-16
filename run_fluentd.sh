#!/bin/sh

bundle install
exec bundle exec fluentd -c ./test/fluentd.conf 
