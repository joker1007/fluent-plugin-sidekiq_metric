#!/bin/sh

bundle install
exec bundle exec sidekiq -r ./test/sidekiq_config.rb
