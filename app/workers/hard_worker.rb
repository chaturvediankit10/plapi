class HardWorker
  include Sidekiq::Worker

  def perform(id)
  end
end
