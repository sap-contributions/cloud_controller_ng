require 'spec_helper'
require_relative '../client_shared'

module CloudController
  module Blobstore
    RSpec.describe DavClient do
      subject(:client) do
        DavClient.new(
          directory_key: directory_key,
          httpclient: httpclient,
          signer: signer,
          endpoint: 'http://localhost',
          user: user,
          password: password,
          root_dir: root_dir,
          min_size: min_size,
          max_size: max_size
        )
      end
      let(:httpclient) { instance_double(HTTPClient) }
      let(:response) { instance_double(HTTP::Message) }
      let(:signer) { instance_double(NginxSecureLinkSigner) }
      let(:directory_key) { 'droplets' }
      let(:root_dir) { nil }
      let(:min_size) { nil }
      let(:max_size) { nil }
      let(:user) { nil }
      let(:password) { nil }
      let(:logger) { instance_double(Steno::Logger, error: nil, info: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(DavBlob, key: nil) }

        before do
          allow(httpclient).to receive_messages(head: instance_double(HTTP::Message, status: 200))
          allow(httpclient).to receive_messages(put: instance_double(HTTP::Message, status: 201))
          allow(httpclient).to receive_messages(get: instance_double(HTTP::Message, status: 200))
          allow(httpclient).to receive_messages(delete: instance_double(HTTP::Message, status: 204))
          allow(httpclient).to receive_messages(request: instance_double(HTTP::Message, status: 201))
        end

        it_behaves_like 'a blobstore client'
      end

      describe 'basic auth' do
        let(:user) { 'username' }
        let(:password) { 'top-sekret' }

        it 'adds Authorization header when there is a user and password' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          client.exists?('foobar')

          expect(httpclient).to have_received(:head).with(anything, header: { 'Authorization' => 'Basic dXNlcm5hbWU6dG9wLXNla3JldA==' })
        end
      end

      describe '#exists?' do
        it 'returns true for an object that already exists' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          expect(client.exists?('foobar')).to be(true)
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'returns false for an object that does not exist' do
          allow(response).to receive_messages(status: 404)
          allow(httpclient).to receive_messages(head: response)

          expect(client.exists?('foobar')).to be(false)
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'raises a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')
          allow(httpclient).to receive_messages(head: response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object existence/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not get object existence/)
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:head).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.exists?('foobar') }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: /)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:head).and_raise(Errno::ECONNREFUSED.new)
            expect { client.exists?('foobar') }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with('Error with blobstore: Connection refused')
          end
        end
      end

      describe '#download_from_blobstore' do
        let(:ssl_config) { instance_double(HTTPClient::SSLConfig, :verify_mode= => nil, set_default_paths: nil, add_trust_ca: nil) }
        let(:httpclient) { instance_double(HTTPClient, ssl_config:) }
        let(:destination_path) { File.join(Dir.mktmpdir, SecureRandom.uuid) }

        before do
          allow(HTTPClient).to receive_messages(new: httpclient)
        end

        after do
          File.delete(destination_path) if File.exist?(destination_path)
        end

        it 'fetches an object' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive(:get).and_yield('content').and_return(response)

          client.download_from_blobstore('foobar', destination_path)

          expect(File.read(destination_path)).to eq('content')
          expect(httpclient).to have_received(:get).with('http://localhost/admin/droplets/fo/ob/foobar', {}, {})
        end

        it 'raises an exception when there is an error fetching an object' do
          allow(response).to receive_messages(status: 500, content: 'error message')
          allow(httpclient).to receive_messages(get: response)

          expect { client.download_from_blobstore('foobar', destination_path) }.to raise_error BlobstoreError, /Could not fetch object/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not fetch object/)
          expect(httpclient).to have_received(:get).with('http://localhost/admin/droplets/fo/ob/foobar', {}, {})
        end

        describe 'file permissions' do
          before do
            @original_umask = File.umask
            File.umask(0o022)
          end

          after do
            File.umask(@original_umask)
          end

          context 'when not specifying a mode' do
            it 'does not change permissions on the file' do
              allow(response).to receive_messages(status: 200)
              allow(httpclient).to receive(:get).and_yield('content').and_return(response)

              client.download_from_blobstore('foobar', destination_path)

              expect(sprintf('%<mode>o', mode: File.stat(destination_path).mode)).to eq('100644')
            end
          end

          context 'when specifying a mode' do
            it 'does change permissions on the file' do
              allow(response).to receive_messages(status: 200)
              allow(httpclient).to receive(:get).and_yield('content').and_return(response)

              client.download_from_blobstore('foobar', destination_path, mode: 0o753)

              expect(sprintf('%<mode>o', mode: File.stat(destination_path).mode)).to eq('100753')
            end
          end
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:get).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.download_from_blobstore('foobar', destination_path) }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:get).and_raise(Errno::ECONNRESET.new)
            expect { client.download_from_blobstore('foobar', destination_path) }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: Connection reset by peer/)
          end
        end
      end

      describe '#cp_to_blobstore' do
        let!(:tmpfile) do
          Tempfile.open('') do |tmpfile|
            tmpfile.write(content)
            tmpfile
          end
        end
        let(:content) { 'file content' }

        after do
          tmpfile.unlink
        end

        it 'creates an object' do
          allow(response).to receive_messages(status: 201, content: '')

          expect(httpclient).to receive(:put) do |*args|
            uri, body, = args
            expect(uri).to eq('http://localhost/admin/droplets/fo/ob/foobar')
            expect(body).to be_a(File)
            expect(body.read).to eq('file content')
            response
          end

          client.cp_to_blobstore(tmpfile.path, 'foobar')
        end

        it 'overwrites an existing file' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive(:put).and_return(response)

          expect(httpclient).to receive(:put) do |*args|
            uri, body, = args
            expect(uri).to eq('http://localhost/admin/droplets/fo/ob/foobar')
            expect(body).to be_a(File)
            expect(body.read).to eq('file content')
            response
          end

          client.cp_to_blobstore(tmpfile.path, 'foobar')
        end

        it 'raises an exception when there is an error creating an object' do
          allow(response).to receive_messages(status: 500, content: nil)
          allow(httpclient).to receive_messages(put: response)

          expect { client.cp_to_blobstore(tmpfile.path, 'foobar') }.to raise_error BlobstoreError, /Could not create object/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not create object/)
        end

        describe 'file size limits' do
          let(:min_size) { 20 }
          let(:max_size) { 50 }

          context 'too small file' do
            let(:content) { 'a' * (min_size - 1) }

            it 'does not copy files below the minimum size limit' do
              allow(httpclient).to receive_messages(put: nil)

              client.cp_to_blobstore(tmpfile.path, 'foobar')

              expect(httpclient).not_to have_received(:put)
            end
          end

          context 'too large file' do
            let(:content) { 'a' * (max_size + 1) }

            it 'does not copy files above the maximum size limit' do
              allow(httpclient).to receive_messages(put: nil)

              client.cp_to_blobstore(tmpfile.path, 'foobar')

              expect(httpclient).not_to have_received(:put)
            end
          end
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:put).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.cp_to_blobstore(tmpfile.path, 'foobar') }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:put).and_raise(Errno::ENETUNREACH.new)
            expect { client.cp_to_blobstore(tmpfile.path, 'foobar') }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: Network is unreachable/)
          end
        end
      end

      describe '#cp_r_to_blobstore' do
        let(:source_dir) { Dir.mktmpdir }
        let!(:tmpfile1) do
          Tempfile.open('', source_dir) do |tmpfile|
            tmpfile.write('file 1')
            tmpfile
          end
        end
        let!(:tmpfile2) do
          Tempfile.open('', source_dir) do |tmpfile|
            tmpfile.write('file 2')
            tmpfile
          end
        end
        let(:tmpfile1_sha) { Digester.new.digest_path(tmpfile1.path) }
        let(:tmpfile2_sha) { Digester.new.digest_path(tmpfile2.path) }
        let(:nested_dir) { Dir.mkdir(File.join(source_dir, 'nested')) }
        let!(:nested_tmpfile1) do
          Tempfile.open('', source_dir) do |tmpfile|
            tmpfile.write('nested file 1')
            tmpfile
          end
        end
        let(:nested_tmpfile1_sha) { Digester.new.digest_path(nested_tmpfile1.path) }

        before do
          allow(httpclient).to receive_messages(head: instance_double(HTTP::Message, status: 404))
        end

        after do
          FileUtils.rm_rf(source_dir)
        end

        it 'uploads all the files in the directory and nested directories' do
          allow(response).to receive_messages(status: 201, content: '')
          allow(httpclient).to receive(:put).and_return(response)

          client.cp_r_to_blobstore(source_dir)

          expect(httpclient).to have_received(:put).thrice
          expect(httpclient).to have_received(:put).with(
            "http://localhost/admin/droplets/#{tmpfile1_sha[0..1]}/#{tmpfile1_sha[2..3]}/#{tmpfile1_sha}", a_kind_of(File), {}
          )
          expect(httpclient).to have_received(:put).with("http://localhost/admin/droplets/#{tmpfile2_sha[0..1]}/#{tmpfile2_sha[2..3]}/#{tmpfile2_sha}", a_kind_of(File), {})
          expect(httpclient).to have_received(:put).with(
            "http://localhost/admin/droplets/#{nested_tmpfile1_sha[0..1]}/#{nested_tmpfile1_sha[2..3]}/#{nested_tmpfile1_sha}", a_kind_of(File), {}
          )
        end

        context 'when a file already exists in the blobstore' do
          before do
            success_response = instance_double(HTTP::Message, status: 200)
            allow(httpclient).to receive(:head).with(/#{nested_tmpfile1_sha}/, anything).and_return(success_response)
          end

          it 'does not re-upload it' do
            allow(response).to receive_messages(status: 201, content: '')
            allow(httpclient).to receive(:put).and_return(response)

            client.cp_r_to_blobstore(source_dir)

            expect(httpclient).to have_received(:put).twice
            expect(httpclient).not_to have_received(:put).with(
              "http://localhost/admin/droplets/#{nested_tmpfile1_sha[0..1]}/#{nested_tmpfile1_sha[2..3]}/#{nested_tmpfile1_sha}", a_kind_of(File), {}
            )
          end
        end

        describe 'file size limits' do
          let(:min_size) { 20 }
          let(:max_size) { 50 }

          context 'too small file' do
            let!(:small_file) do
              Tempfile.open('', source_dir) do |tmpfile|
                tmpfile.write('a' * (min_size - 1))
                tmpfile
              end
            end
            let(:small_file_sha) { Digester.new.digest_path(small_file.path) }

            it 'does not copy files below the minimum size limit' do
              allow(response).to receive_messages(status: 201, content: '')
              allow(httpclient).to receive(:put).and_return(response)

              client.cp_r_to_blobstore(source_dir)

              expect(httpclient).not_to have_received(:put).with(
                "http://localhost/admin/droplets/#{small_file_sha[0..1]}/#{small_file_sha[2..3]}/#{small_file_sha}", a_kind_of(File), {}
              )
            end
          end

          context 'too large file' do
            let!(:large_file) do
              Tempfile.open('', source_dir) do |tmpfile|
                tmpfile.write('a' * (max_size + 1))
                tmpfile
              end
            end
            let(:large_file_sha) { Digester.new.digest_path(large_file.path) }

            it 'does not copy files above the maximum size limit' do
              allow(response).to receive_messages(status: 201, content: '')
              allow(httpclient).to receive(:put).and_return(response)

              client.cp_r_to_blobstore(source_dir)

              expect(httpclient).not_to have_received(:put).with(
                "http://localhost/admin/droplets/#{large_file_sha[0..1]}/#{large_file_sha[2..3]}/#{large_file_sha}", a_kind_of(File), {}
              )
            end
          end
        end

        describe 'file permissions' do
          context 'sufficient file permissions' do
            let!(:sufficiently_permissioned_file) do
              Tempfile.open('', source_dir) do |tmpfile|
                File.chmod(0o600, tmpfile)
                tmpfile
              end
            end
            let(:sufficient_perm_file_sha) { Digester.new.digest_path(sufficiently_permissioned_file.path) }

            it 'copies files above the maximum size limit' do
              allow(response).to receive_messages(status: 201, content: '')
              allow(httpclient).to receive(:put).and_return(response)

              client.cp_r_to_blobstore(source_dir)

              expect(httpclient).to have_received(:put).with(
                "http://localhost/admin/droplets/#{sufficient_perm_file_sha[0..1]}/#{sufficient_perm_file_sha[2..3]}/#{sufficient_perm_file_sha}", a_kind_of(File), {}
              )
            end
          end

          context 'insufficient file permissions' do
            let!(:insufficiently_permissioned_file) do
              Tempfile.open('', source_dir) do |tmpfile|
                File.chmod(0o444, tmpfile)
                tmpfile
              end
            end
            let(:insufficient_perm_file_sha) { Digester.new.digest_path(insufficiently_permissioned_file.path) }

            it 'does not copy files above the maximum size limit' do
              allow(response).to receive_messages(status: 201, content: '')
              allow(httpclient).to receive(:put).and_return(response)

              client.cp_r_to_blobstore(source_dir)

              expect(httpclient).not_to have_received(:put).with(
                "http://localhost/admin/droplets/#{insufficient_perm_file_sha[0..1]}/#{insufficient_perm_file_sha[2..3]}/#{insufficient_perm_file_sha}", a_kind_of(File), {}
              )
            end
          end
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:put).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.cp_r_to_blobstore(source_dir) }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:put).and_raise(Errno::EHOSTUNREACH.new)
            expect { client.cp_r_to_blobstore(source_dir) }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: No route to host/)
          end
        end
      end

      describe '#cp_file_between_keys' do
        it 'creates an empty file at the destination location to ensure all folder paths are create before the copy' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive_messages(put: response, request: response)

          client.cp_file_between_keys('foobar', 'bazbar')

          expect(httpclient).to have_received(:put).with('http://localhost/admin/droplets/ba/zb/bazbar', '', {})
        end

        it 'copies the file from the source key to the destination key' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive_messages(put: response, request: response)

          client.cp_file_between_keys('foobar', 'bazbar')

          expect(httpclient).to have_received(:request).
            with(
              :copy,
              'http://localhost/admin/droplets/fo/ob/foobar',
              header: { 'Destination' => 'http://localhost/admin/droplets/ba/zb/bazbar' }
            )
        end

        it 'raises an exception when there is an error copying an object' do
          allow(response).to receive_messages(status: 500, content: 'Internal Server Error')
          allow(httpclient).to receive_messages(put: instance_double(HTTP::Message, status: 204, content: ''), request: response)

          expect { client.cp_file_between_keys('foobar', 'bazbar') }.to raise_error BlobstoreError, /Could not copy object/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not copy object/)
        end

        it 'raises an exception when there is an error creating the destination object' do
          allow(response).to receive_messages(status: 500, content: 'Internal Server Error')
          allow(httpclient).to receive(:put).and_return(response)

          expect { client.cp_file_between_keys('foobar', 'bazbar') }.to raise_error BlobstoreError, /Could not copy object/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not copy object/)
        end

        context 'when the source key has no file associated with it' do
          it 'raises a FileNotFound Error' do
            allow(response).to receive_messages(status: 404, content: 'Not Found')
            allow(httpclient).to receive_messages(put: instance_double(HTTP::Message, status: 204, content: ''), request: response)

            expect do
              client.cp_file_between_keys('foobar', 'bazbar')
            end.to raise_error(CloudController::Blobstore::FileNotFound, /Could not find object 'foobar'/)
          end
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          context 'when creating a destination' do
            it 'reraises a BlobstoreError' do
              allow(httpclient).to receive(:put).and_raise(OpenSSL::SSL::SSLError.new)
              expect { client.cp_file_between_keys('foobar', 'bazbar') }.to raise_error BlobstoreError, /SSL verification failed/
              expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
            end
          end

          context 'when an unknown error occurs with the blobstore' do
            it 'raises a BlobstoreError' do
              allow(httpclient).to receive(:put).and_raise(Errno::EBADF.new)
              expect { client.cp_file_between_keys('foobar', 'bazbar') }.to raise_error BlobstoreError
              expect(logger).to have_received(:error).with(/^Error with blobstore: Bad file descriptor/)
            end
          end

          context 'when copying files' do
            it 'reraises a BlobstoreError' do
              allow(response).to receive_messages(status: 204, content: '')
              allow(httpclient).to receive(:put).and_return(response)
              allow(httpclient).to receive(:request).and_raise(OpenSSL::SSL::SSLError.new)
              expect { client.cp_file_between_keys('foobar', 'bazbar') }.to raise_error BlobstoreError, /SSL verification failed/
              expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
            end
          end
        end
      end

      describe '#delete' do
        it 'deletes an object' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive(:delete).and_return(response)

          client.delete('foobar')

          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'raises FileNotFound error when the file is not found in blobstore during deleting' do
          allow(response).to receive_messages(status: 404, content: 'Not Found')
          allow(httpclient).to receive(:delete).and_return(response)

          expect do
            client.delete('foobar')
          end.to raise_error CloudController::Blobstore::FileNotFound, /Could not find object 'foobar'/
        end

        it 'raises an exception when there is an error deleting an object' do
          allow(response).to receive_messages(status: 500, content: '')
          expect(httpclient).to receive(:delete).and_return(response)

          expect { client.delete('foobar') }.to raise_error BlobstoreError, /Could not delete object/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not delete object/)
        end

        it 'raises a ConflictError when there is a conflict deleting an object' do
          allow(response).to receive_messages(status: 409, content: '')
          expect(httpclient).to receive(:delete).and_return(response)

          expect { client.delete('foobar') }.to raise_error ConflictError, /Conflict deleting object/
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:delete).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.delete('foobar') }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:delete).and_raise(Errno::EIO.new)
            expect { client.delete('and bingo was his name-o') }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(%r{^Error with blobstore: Input/output error})
          end
        end
      end

      describe '#delete_all' do
        let(:root_dir) { 'buildpack_cache' }

        it 'deletes the collection' do
          allow(httpclient).to receive(:delete).and_return(instance_double(HTTP::Message, status: 204, content: ''))
          client.delete_all
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/buildpack_cache/', header: {})
        end

        it 'raises FileNotfound when the server returns 404' do
          allow(httpclient).to receive(:delete).and_return(instance_double(HTTP::Message, status: 404, content: ''))
          expect do
            client.delete_all
          end.to raise_error(FileNotFound, /Could not find object/)
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/buildpack_cache/', header: {})
        end

        it 'raises an error when the server returns any other code' do
          allow(httpclient).to receive(:delete).and_return(instance_double(HTTP::Message, status: 500, content: ''))
          expect do
            client.delete_all
          end.to raise_error(BlobstoreError, /Could not delete all/)
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/buildpack_cache/', header: {})
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:delete).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.delete_all }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:delete).and_raise(Errno::EHOSTUNREACH.new)
            expect { client.delete_all }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: No route to host/)
          end
        end
      end

      describe '#delete_all_in_path' do
        let(:root_dir) { 'buildpack_cache' }

        it 'deletes the collection' do
          allow(httpclient).to receive(:delete).and_return(instance_double(HTTP::Message, status: 204, content: ''))
          client.delete_all_in_path('foobar')
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/buildpack_cache/fo/ob/foobar/', header: {})
        end

        it 'does not fail when the collection does not exist' do
          allow(httpclient).to receive(:delete).and_return(instance_double(HTTP::Message, status: 404, content: ''))
          client.delete_all_in_path('foobar')
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/buildpack_cache/fo/ob/foobar/', header: {})
        end

        it 'raises an error when the server returns any other code' do
          allow(httpclient).to receive(:delete).and_return(instance_double(HTTP::Message, status: 500, content: ''))
          expect do
            client.delete_all_in_path('foobar')
          end.to raise_error(BlobstoreError, /Could not delete all in path/)
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not delete all in path/)
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/buildpack_cache/fo/ob/foobar/', header: {})
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:delete).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.delete_all_in_path('foobar') }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:delete).and_raise(Errno::ECONNREFUSED.new)
            expect { client.delete_all_in_path('foobar') }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: Connection refused/)
          end
        end
      end

      describe '#blob' do
        it 'returns a blob' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          blob = client.blob('foobar')

          expect(blob).to be_a(DavBlob)
        end

        it 'returns nil if there is no object at the key' do
          allow(response).to receive_messages(status: 404)
          allow(httpclient).to receive_messages(head: response)

          blob = client.blob('foobar')

          expect(blob).to be_nil
        end

        it 'raises a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')
          allow(httpclient).to receive_messages(head: response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object/
          expect(logger).to have_received(:error).with(/^Error with blobstore: Could not get object/)
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            allow(httpclient).to receive(:head).and_raise(OpenSSL::SSL::SSLError.new)
            expect { client.blob('foobar') }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            allow(httpclient).to receive(:head).and_raise(Errno::ECONNREFUSED.new)
            expect { client.blob('foobar') }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: Connection refused/)
          end
        end
      end

      describe '#delete_blob' do
        it 'deletes the blobs key' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive_messages(delete: response)
          blob = DavBlob.new(httpmessage: instance_double(HTTPClient), key: 'fo/ob/foobar', signer: nil)

          client.delete_blob(blob)

          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'does not error if the object is already deleted' do
          allow(response).to receive_messages(status: 404, content: 'Not Found')
          allow(httpclient).to receive_messages(delete: response)
          blob = DavBlob.new(httpmessage: instance_double(HTTPClient), key: 'fo/ob/foobar', signer: nil)

          expect { client.delete_blob(blob) }.not_to raise_error
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        context 'when an OpenSSL::SSL::SSLError is raised' do
          it 'reraises a BlobstoreError' do
            blob = DavBlob.new(httpmessage: instance_double(HTTPClient), key: 'fo/ob/foobar', signer: nil)
            allow(httpclient).to receive(:delete).and_raise(OpenSSL::SSL::SSLError.new)

            expect { client.delete_blob(blob) }.to raise_error BlobstoreError, /SSL verification failed/
            expect(logger).to have_received(:error).with(/^SSL verification failed: OpenSSL::SSL::SSLError/)
          end
        end

        context 'when an unknown error occurs with the blobstore' do
          it 'raises a BlobstoreError' do
            blob = DavBlob.new(httpmessage: instance_double(HTTPClient), key: 'fo/ob/foobar', signer: nil)
            allow(httpclient).to receive(:delete).and_raise(Errno::ECONNREFUSED.new)

            expect { client.delete_blob(blob) }.to raise_error BlobstoreError
            expect(logger).to have_received(:error).with(/^Error with blobstore: Connection refused/)
          end
        end
      end

      describe '#files_for' do
        let(:root_xml_body) do
          <<-XML
            <?xml version="1.0" encoding="utf-8" ?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>always-ignore-first-obj</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>nested-dir-1</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>nested-dir-2</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
            </D:multistatus>
          XML
        end
        let(:nested_xml_body) do
          <<-XML
            <?xml version="1.0" encoding="utf-8" ?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>always-ignore-first-obj</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>some-blob</D:displayname>
                    <D:resourcetype></D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
            </D:multistatus>
          XML
        end
        let(:nested_xml_body_2) do
          <<-XML
            <?xml version="1.0" encoding="utf-8" ?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>always-ignore-first-obj</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>some-other-blob</D:displayname>
                    <D:resourcetype></D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
            </D:multistatus>
          XML
        end

        let(:fake_root_response) { double(:response, body: root_xml_body) }
        let(:fake_nested_response) { double(:response, body: nested_xml_body) }
        let(:fake_nested_response_2) { double(:response, body: nested_xml_body_2) }

        before do
          allow(httpclient).to receive(:request).
            with(:propfind, 'http://localhost/admin/droplets/', nil, nil, {}).
            and_return(fake_root_response)
          allow(httpclient).to receive(:request).
            with(:propfind, 'http://localhost/admin/droplets/nested-dir-2', nil, nil, {}).
            and_return(fake_nested_response_2)
          allow(httpclient).to receive(:request).
            with(:propfind, 'http://localhost/admin/droplets/nested-dir-1', nil, nil, {}).
            and_return(fake_nested_response)
        end

        it 'enumerates a web dav blobstore' do
          blob_keys = client.files_for('nested').first(2).map(&:key)

          expect(blob_keys).to match_array(%w[nested-dir-1/some-blob nested-dir-2/some-other-blob])
        end

        context 'when provided a path to ignore' do
          let(:root_xml_body) do
            <<-XML
            <?xml version="1.0" encoding="utf-8" ?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>always-ignore-first-obj</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>ignored-directory</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
            </D:multistatus>
            XML
          end

          it 'does not enumerate ignored directories' do
            blob_keys = client.files_for('', %w[some-directory ignored-directory])
            expect(blob_keys.first).to be_nil
          end
        end

        context 'when provided a prefix to enumerate' do
          let(:root_xml_body) do
            <<-XML
            <?xml version="1.0" encoding="utf-8" ?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>always-ignore-first-obj</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>ab-directory</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
              <D:response>
                <D:propstat>
                  <D:prop>
                    <D:displayname>cd-directory</D:displayname>
                    <D:resourcetype>
                      <D:collection/>
                    </D:resourcetype>
                  </D:prop>
                </D:propstat>
              </D:response>
            </D:multistatus>
            XML
          end

          before do
            allow(httpclient).to receive(:request).
              with(:propfind, 'http://localhost/admin/droplets/ab-directory', nil, nil, {}).
              and_return(fake_nested_response)
          end

          it 'only enumerates directories that start with the prefix' do
            blob_keys = client.files_for('ab').map(&:key)

            expect(blob_keys).to match_array(%w[ab-directory/some-blob])
          end
        end
      end

      context 'when root_dir is configured' do
        let(:root_dir) { 'root_dir' }

        it 'includes it in the key' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          expect(client.exists?('foobar')).to be(true)
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/root_dir/fo/ob/foobar', header: {})
        end
      end
    end
  end
end
