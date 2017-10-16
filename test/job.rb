class Job
  include Sidekiq::Worker

  def perform
    :done
  end
end
