require 'cloud_controller/rest_controller'
require 'vcap/cloud_controller/controllers/v3/application_controller'

Dir[File.expand_path('../../app/controllers/**/*.rb', __dir__)].
  reject { |controller| controller.include? 'controllers/v3/application_controller' }.
  each { |file| require file }
