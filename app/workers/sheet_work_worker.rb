require 'rake'
require 'rubygems'
PureLoan::Application.load_tasks
class SheetWorkWorker
  include Sidekiq::Worker

  def perform(*args)
    Rake::Task["sheet_operation:export_sheet"].invoke
  end
end
