# Copyright 2017- joker1007
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require "oj"
require "redis"

module Fluent
  module Plugin
    class SidekiqMetricInput < ::Fluent::Plugin::Input
      Fluent::Plugin.register_input("sidekiq_metric", self)

      helpers :timer

      desc 'Tag of the output events.'
      config_param :tag, :string

      desc "redis URL that sidekiq uses"
      config_param :redis_url, :string

      desc "config for redis-namespace"
      config_param :namespace, default: nil

      desc "Password for redis authentication"
      config_param :password, :string, secret: true, default: nil

      desc "Other options for redis connection"
      config_param :connect_opts, :hash, default: {}

      desc "Interval for fetching to redis"
      config_param :fetch_interval, :time, default: 60

      desc "Queue names for length aggregation per queue"
      config_param :queue_names, :array, default: []

      def configure(conf)
        super
        @connect_opts = @connect_opts.map { |k, v| [k.to_sym, v] }.to_h
      end

      def start
        super
        @timer = timer_execute(:sidekiq_metric_timer, @fetch_interval, &method(:run))
      end

      def run
        stats = fetch_stats
        queue_lengths = fetch_queue_lengths
        record = stats.merge(queue_lengths)
        router.emit(@tag, Fluent::EventTime.now, record)
      end

      ## From sidekiq gem (lib/sidekiq/api.rb)
      def fetch_stats
        pipe1_res = redis.pipelined do
          redis.get('stat:processed'.freeze)
          redis.get('stat:failed'.freeze)
          redis.zcard('schedule'.freeze)
          redis.zcard('retry'.freeze)
          redis.zcard('dead'.freeze)
          redis.scard('processes'.freeze)
          redis.lrange('queue:default'.freeze,  -1,  -1)
          redis.smembers('processes'.freeze)
          redis.smembers('queues'.freeze)
        end

        pipe2_res = redis.pipelined do
          pipe1_res[7].each { |key| redis.hget(key, 'busy'.freeze) }
          pipe1_res[8].each { |queue| redis.llen("queue:#{queue}") }
        end

        s = pipe1_res[7].size
        workers_size = pipe2_res[0...s].map(&:to_i).inject(0, &:+)
        enqueued     = pipe2_res[s..-1].map(&:to_i).inject(0, &:+)

        default_queue_latency =
          if (entry = pipe1_res[6].first)
            job = Oj.load(entry) rescue {}
            now = Time.now.to_f
            thence = job['enqueued_at'.freeze] || now
            now - thence
          else
            0
          end

        {
          processed:             pipe1_res[0].to_i,
          failed:                pipe1_res[1].to_i,
          scheduled_size:        pipe1_res[2],
          retry_size:            pipe1_res[3],
          dead_size:             pipe1_res[4],
          processes_size:        pipe1_res[5],

          default_queue_latency: default_queue_latency,
          workers_size:          workers_size,
          enqueued:              enqueued
        }
      end

      ## From sidekiq gem (lib/sidekiq/api.rb)
      def fetch_queue_lengths
        return {} if @queue_names.empty?

        queues = redis.smembers('queues'.freeze) & @queue_names
        return {} if queues.empty?

        lengths = redis.pipelined do
          queues.each do |queue|
            redis.llen("queue:#{queue}")
          end
        end

        i = 0
        array_of_arrays = queues.inject({}) do |memo, queue|
          memo["#{queue}_length"] = lengths[i]
          i += 1
          memo
        end

        Hash[array_of_arrays]
      end

      def redis
        @redis ||=
          if @namespace
            client = Redis.new(url: @redis_url, **@connect_opts).tap do |cl|
              cl.auth(@password) if @password
            end
            Redis::Namespace.new(@namespace, redis: client)
          else
            Redis.new(url: @redis_url, **@connect_opts).tap do |cl|
              cl.auth(@password) if @password
            end
          end
      end

      def clear_redis
        @redis = nil
      end
    end
  end
end
