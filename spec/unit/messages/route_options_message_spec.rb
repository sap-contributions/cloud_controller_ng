require 'spec_helper'
require 'messages/route_options_message'

module VCAP::CloudController
  RSpec.describe RouteOptionsMessage do
    describe 'validations' do
      context 'when loadbalancing is round-robin' do
        it 'is valid' do
          message = RouteOptionsMessage.new({ loadbalancing: 'round-robin' })
          expect(message).to be_valid
        end
      end

      context 'when loadbalancing is least-connection' do
        it 'is valid' do
          message = RouteOptionsMessage.new({ loadbalancing: 'least-connection' })
          expect(message).to be_valid
        end
      end

      context 'when loadbalancing is hash' do
        context 'with hash_header present' do
          it 'is valid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID'
                                              })
            expect(message).to be_valid
          end
        end

        context 'with hash_header and hash_balance present' do
          it 'is valid with integer hash_balance' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 50
                                              })
            expect(message).to be_valid
            expect(message.hash_balance).to eq(50.0)
          end

          it 'is valid with float hash_balance' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 50.5
                                              })
            expect(message).to be_valid
            expect(message.hash_balance).to eq(50.5)
          end

          it 'is valid with string hash_balance' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: '50.5'
                                              })
            expect(message).to be_valid
            expect(message.hash_balance).to eq(50.5)
          end

          it 'is valid with hash_balance 0' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 0
                                              })
            expect(message).to be_valid
            expect(message.hash_balance).to eq(0.0)
          end

          it 'is valid with hash_balance 100' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 100
                                              })
            expect(message).to be_valid
            expect(message.hash_balance).to eq(100.0)
          end
        end

        context 'without hash_header' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({ loadbalancing: 'hash' })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('is required when load balancing algorithm is hash')
          end
        end

        context 'with empty hash_header' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: ''
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('is required when load balancing algorithm is hash')
          end
        end

        context 'with invalid hash_balance' do
          it 'is invalid with negative value' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: -1
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('must be between 0.0 and 100.0')
          end

          it 'is invalid with value > 100' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 101
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('must be between 0.0 and 100.0')
          end

          it 'is invalid with non-numeric string' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 'abc'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('hash_balance must be a valid number')
          end

          it 'is invalid with empty string' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: ''
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('hash_balance must be a valid number')
          end
        end
      end

      context 'when loadbalancing is not hash' do
        context 'with hash_header present' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'round-robin',
                                                hash_header: 'X-User-ID'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('can only be set when load balancing algorithm is hash')
          end
        end

        context 'with hash_balance present' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'round-robin',
                                                hash_balance: 50
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('can only be set when load balancing algorithm is hash')
          end
        end

        context 'with both hash_header and hash_balance present' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'least-connection',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 50
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('can only be set when load balancing algorithm is hash')
            expect(message.errors[:hash_balance]).to include('can only be set when load balancing algorithm is hash')
          end
        end
      end

      context 'when loadbalancing is nil' do
        context 'with hash_header present' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: nil,
                                                hash_header: 'X-User-ID'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('can only be set when load balancing algorithm is hash')
          end
        end
      end

      context 'when loadbalancing is invalid' do
        it 'is invalid' do
          message = RouteOptionsMessage.new({ loadbalancing: 'random' })
          expect(message).not_to be_valid
          expect(message.errors[:loadbalancing]).to include("must be one of 'round-robin, least-connection, hash' if present")
        end
      end
    end

    describe 'type conversion' do
      it 'converts string "1.5" to float 1.5' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: '1.5'
                                          })
        expect(message.hash_balance).to eq(1.5)
      end

      it 'converts string "50" to float 50.0' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: '50'
                                          })
        expect(message.hash_balance).to eq(50.0)
      end

      it 'converts integer 50 to float 50.0' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: 50
                                          })
        expect(message.hash_balance).to eq(50.0)
      end

      it 'keeps float 33.333 as is' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: 33.333
                                          })
        expect(message.hash_balance).to eq(33.333)
      end

      it 'handles nil value' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: nil
                                          })
        expect(message.hash_balance).to be_nil
      end
    end

    describe 'edge cases' do
      it 'accepts hash_balance 0.0 (ignore load)' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: 0.0
                                          })
        expect(message).to be_valid
        expect(message.hash_balance).to eq(0.0)
      end

      it 'accepts hash_balance 0.001' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: 0.001
                                          })
        expect(message).to be_valid
        expect(message.hash_balance).to eq(0.001)
      end

      it 'accepts hash_balance 99.999' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: 99.999
                                          })
        expect(message).to be_valid
        expect(message.hash_balance).to eq(99.999)
      end

      it 'rejects hash_balance 100.001' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: 100.001
                                          })
        expect(message).not_to be_valid
        expect(message.errors[:hash_balance]).to include('must be between 0.0 and 100.0')
      end

      it 'rejects hash_balance -0.001' do
        message = RouteOptionsMessage.new({
                                            loadbalancing: 'hash',
                                            hash_header: 'X-User-ID',
                                            hash_balance: -0.001
                                          })
        expect(message).not_to be_valid
        expect(message.errors[:hash_balance]).to include('must be between 0.0 and 100.0')
      end
    end
  end
end
