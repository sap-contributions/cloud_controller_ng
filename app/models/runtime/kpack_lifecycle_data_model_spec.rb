require 'spec_helper'

module VCAP::CloudController
  RSpec.describe KpackLifecycleDataModel do
    subject(:lifecycle_data) { KpackLifecycleDataModel.new }

    describe '#to_hash' do
      let(:expected_lifecycle_data) do
        { buildpacks: buildpacks || [], stack: 'cflinuxfs3' }
      end
      let(:buildpacks) { [buildpack] }
      let(:buildpack) { 'ruby' }
      let(:stack) { 'cflinuxfs3' }

      before do
        Buildpack.make(name: 'ruby')
        lifecycle_data.stack = stack
        lifecycle_data.buildpacks = buildpacks
        lifecycle_data.save
      end

      it 'returns the lifecycle data as a hash' do
        expect(lifecycle_data.to_hash).to eq expected_lifecycle_data
      end

      context 'when the user has not specified a buildpack' do
        let(:buildpacks) { nil }

        it 'returns the lifecycle data as a hash' do
          expect(lifecycle_data.to_hash).to eq expected_lifecycle_data
        end
      end
    end
  end
end
