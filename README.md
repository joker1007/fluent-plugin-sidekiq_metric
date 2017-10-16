# fluent-plugin-sidekiq_metric

[Fluentd](http://fluentd.org/) input plugin to collect sidekiq metrics.

## Output example

```json
{
  "processed": 12,
  "failed": 1,
  "scheduled_size": 3,
  "retry_size": 1,
  "dead_size": 0,
  "processes_size":1,
  "default_queue_latency": 0,
  "workers_size": 1,
  "enqueued": 0
}
```

If queue_names is set, output becomes following.
ex: `queue_names queue1, queue2`

```
{
  "processed": 12,
  "failed": 1,
  "scheduled_size": 3,
  "retry_size": 1,
  "dead_size": 0,
  "processes_size":1,
  "default_queue_latency": 0,
  "workers_size": 1,
  "enqueued": 0,
  "queue1_length": 1,
  "queue2_length": 10
}
```

## Installation

### RubyGems

```
$ gem install fluent-plugin-sidekiq_metric
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-sidekiq_metric"
```

And then execute:

```
$ bundle
```

## Configuration

### tag (string) (required)

Tag of the output events.

### redis_url (string) (required)

redis URL that sidekiq uses

### namespace (string) (optional)

config for redis-namespace

### password (string) (optional)

Password for redis authentication

### connect_opts (hash) (optional)

Other options for redis connection

Default value: `{}`.

### fetch_interval (time) (optional)

Interval for fetching to redis

Default value: `60`.

### queue_names (array) (optional)

Queue names for length aggregation per queue

Default value: `[]`.

You can copy and paste generated documents here.

## Config Example

## Copyright

* Copyright(c) 2017- joker1007
* License
  * Apache License, Version 2.0
