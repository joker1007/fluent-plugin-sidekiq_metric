require "helper"
require "fluent/plugin/in_sidekiq_metric.rb"

class Sidekiq_metricInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  DEFAULT_CONF = %q{
    tag test
    redis_url redis://redis:6379
  }

  test "configure" do
    driver = create_driver(<<~CONF)
      tag test
      redis_url redis://redis:6379
      connect_opts {"foo": "bar", "hoge": "fuga"}
      queue_names queue1, queue2
    CONF
    assert { driver.instance.instance_variable_get("@tag") == "test" }
    assert { driver.instance.instance_variable_get("@redis_url") == "redis://redis:6379" }
    assert { driver.instance.instance_variable_get("@connect_opts") == {foo: "bar", hoge: "fuga"} }
    assert { driver.instance.instance_variable_get("@queue_names") == ["queue1", "queue2"] }
  end

  test "redis" do
    driver = create_driver
    assert { driver.instance.redis.ping == "PONG" }
  end

  test "fetch_stats" do
    driver = create_driver
    Job.perform_async
    sleep 5
    stats = driver.instance.fetch_stats
    assert_operator(stats[:processed], ">", 0)
    keys = [:failed, :scheduled_size, :retry_size, :dead_size, :processes_size, :default_queue_latency, :workers_size, :enqueued]
    keys.each do |k|
      assert_kind_of(Integer, stats[k])
    end
  end

  test "fetch_queue_lengths" do
    driver = create_driver(<<~CONF)
      tag test
      redis_url redis://redis:6379
      queue_names default
    CONF
    queue_lengths = driver.instance.fetch_queue_lengths
    assert_kind_of(Integer, queue_lengths["default_length"])
  end

  private

  def create_driver(conf = DEFAULT_CONF)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SidekiqMetricInput).configure(conf)
  end
end
