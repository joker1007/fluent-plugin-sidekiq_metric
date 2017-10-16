require "helper"
require "fluent/plugin/in_sidekiq_metric.rb"

class Sidekiq_metricInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  DEFAULT_CONF = %q{
    tag test
    redis_url redis://redis:6379
    fetch_interval 3s
    queue_names default
  }

  test "configure" do
    driver = create_driver(<<~CONF)
      tag test
      redis_url redis://redis:6379
      connect_opts {"foo": "bar", "hoge": "fuga"}
      queue_names queue1, queue2
    CONF
    assert { driver.instance.tag == "test" }
    assert { driver.instance.redis_url == "redis://redis:6379" }
    assert { driver.instance.connect_opts == {foo: "bar", hoge: "fuga"} }
    assert { driver.instance.queue_names == ["queue1", "queue2"] }
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
    keys = [:processed, :failed, :scheduled_size, :retry_size, :dead_size, :processes_size, :default_queue_latency, :workers_size, :enqueued]
    keys.each do |k|
      assert_kind_of(Integer, stats[k])
    end
  end

  test "fetch_queue_lengths" do
    driver = create_driver
    queue_lengths = driver.instance.fetch_queue_lengths
    assert_kind_of(Integer, queue_lengths["default_length"])
  end

  test "emit" do
    driver = create_driver
    driver.run(expect_emits: 2, timeout: 10)
    assert { driver.events.length > 0 }
    driver.events.each do |ev|
      assert_equal("test", ev[0])
      keys = [:processed, :failed, :scheduled_size, :retry_size, :dead_size, :processes_size, :default_queue_latency, :workers_size, :enqueued]
      keys.each do |k|
        assert_kind_of(Integer, ev[2][k])
      end
    end
  end

  private

  def create_driver(conf = DEFAULT_CONF)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SidekiqMetricInput).configure(conf)
  end
end
