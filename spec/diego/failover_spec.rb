require 'spec_helper'
require 'diego/client'

module Diego
  RSpec.describe Client do
    let(:bbs_domain) { 'bbs.example.com' }
    let(:bbs_port) { '5000' }
    let(:bbs_uri) { "http://#{bbs_domain}:#{bbs_port}" }
    let(:ca_cert_file) { File.join(Paths::FIXTURES, 'certs/bbs_ca.crt') }
    let(:client_cert_file) { File.join(Paths::FIXTURES, 'certs/bbs_client.crt') }
    let(:client_key_file) { File.join(Paths::FIXTURES, 'certs/bbs_client.key') }
    let(:bbs_ip_1) { '172.17.0.2' }
    let(:bbs_ip_2) { '172.17.0.3' }
    let(:logger) { instance_double(Steno::Logger) }


    subject(:client) do
      Client.new(url: bbs_uri, ca_cert_file: ca_cert_file, client_cert_file: client_cert_file, client_key_file: client_key_file,
                 connect_timeout: 10, send_timeout: 10, receive_timeout: 10)
    end
    before do
      allow(Resolv).to receive(:getaddresses).with(bbs_domain).and_return([bbs_ip_1, bbs_ip_2])
      allow(Addrinfo).to receive(:getaddrinfo).and_return([Addrinfo.new(["AF_INET", bbs_port.to_i, "#{bbs_domain}:#{bbs_port}", bbs_ip_1])])
      allow(Steno).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
    end


    context 'can talk to fake server' do
      # let(:http_client) { Net::HTTP.new('localhost', 12345, open_timeout: 1, read_timeout: 1, write_timeout: 1) }

      before do
        puts("start container")
        `docker start ping1`
        sleep 5
        # WebMock.allow_net_connect!
      end

      it 'should something' do
        # first request is handled by first server

        threads = []
        1.times do |i|
          threads << Thread.new do
            puts("first ping from thread #{i}")
            client.ping
          end
        end

        threads.each(&:join)


        #
        # # puts("stop container")
        # `docker kill -s 9 ping1`
        #
        # puts("2nd ping")
        # # second request should be handled by second server
        # expect { client.ping }.not_to raise_error()
      end

    end

  end
end
