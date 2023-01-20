require 'webrick'

class FakeBBSServer
  attr_reader :thread, :server

  def initialize(port, host='localhost')
    @server = WEBrick::HTTPServer.new(
      BindAddress: host,
      Port: port,
      AccessLog: [],
      Logger: WEBrick::Log.new('/dev/null')
    )

    @fail_next_request = false

    server.mount_proc '/v1/ping' do |req, res|
      puts(req)
      if fail_next_request
        @fail_next_request = false
      end
      sleep 30
      res.status = 200
    end
  end

  def fail_next_request
    @fail_next_request = true
  end

  def start
    @thread = Thread.new do
      server.start
    ensure
      server.shutdown
    end
  end

  def stop
    server.shutdown
    thread.join(2)
    Thread.kill(thread)
  end
end
