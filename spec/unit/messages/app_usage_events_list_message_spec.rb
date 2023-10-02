require 'spec_helper'
require 'messages/app_usage_events_list_message'

module VCAP::CloudController
  RSpec.describe AppUsageEventsListMessage do
    subject { AppUsageEventsListMessage.from_params(params) }
    let(:params) { {} }

    it 'accepts an empty set' do
      expect(subject).to be_valid
    end

    context 'when there are valid params' do
      let(:params) do
        {
          'after_guid' => 'guid1',
          'guids' => 'guid5,guid6'
        }
      end

      it 'accepts the params as valid' do
        expect(subject).to be_valid
      end
    end

    context 'when invalid params are given' do
      let(:params) { { foobar: 'pants' } }

      it 'does not accept any other params' do
        expect(subject).not_to be_valid
        expect(subject.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    context 'validations' do
      context 'when the after_guid filter is provided' do
        let(:params) { { 'after_guid' => 'some-guid' } }

        context 'and the values are invalid' do
          let(:params) { { after_guid: 3 } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:after_guid]).to include('must be an array')
          end
        end

        context 'and more than one guid is given' do
          let(:params) { { after_guid: 'guid1,guid2' } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:after_guid]).to include('filter accepts only one guid')
          end
        end

        it 'sets the message types to the provided values' do
          expect(subject).to be_valid
          expect(subject.after_guid).to eq(['some-guid'])
        end
      end

      context 'when the guids filter is provided' do
        let(:params) { { 'guids' => 'some-guid' } }

        context 'and the values are invalid' do
          let(:params) { { guids: false } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:guids]).to include('must be an array')
          end
        end

        it 'sets the message types to the provided values' do
          expect(subject).to be_valid
          expect(subject.guids).to eq(['some-guid'])
        end
      end

      context 'when the order_by filter is provided' do
        context 'and the value is invalid' do
          let(:params) { { order_by: 'updated_at' } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:order_by]).to include("can only be: 'created_at'")
          end
        end

        context 'and the value is valid' do
          let(:params) { { order_by: 'created_at' } }

          it 'sets the message order_by to the provided value' do
            expect(subject).to be_valid
            expect(subject.order_by).to eq('created_at')
          end
        end
      end
    end
  end
end
