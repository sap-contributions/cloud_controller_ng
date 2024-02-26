require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IncludeSpaceDecorator do
    subject(:decorator) { IncludeSpaceDecorator }
    let(:space1) { Space.make(name: 'first-space') }
    let(:space2) { Space.make(name: 'second-space') }
    let(:apps) { [AppModel.make(space: space1), AppModel.make(space: space2), AppModel.make(space: space1)] }

    before do
      allow(Permissions).to receive(:new).and_return(double(can_read_globally?: true))
    end

    it 'decorates the given hash with spaces from apps' do
      undecorated_hash = { foo: 'bar' }
      hash = subject.decorate(undecorated_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to contain_exactly(Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash)
    end

    it 'does not overwrite other included fields' do
      undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
      hash = subject.decorate(undecorated_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to contain_exactly(Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash)
      expect(hash[:included][:monkeys]).to match_array(%w[zach greg])
    end

    describe '.match?' do
      it 'matches include arrays containing "space"' do
        expect(decorator).to be_match(%w[potato space turnip])
      end

      it 'matches include arrays containing "space.organization"' do
        expect(decorator).to be_match(['potato', 'space.organization', 'turnip'])
      end

      it 'does not match other include arrays' do
        expect(decorator).not_to be_match(%w[potato turnip])
      end
    end
  end
end
