require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SecurityGroup, type: :model do
    def build_transport_rule(attrs={})
      {
        'protocol' => 'udp',
        'ports' => '8080-9090',
        'destination' => '198.41.191.47/1'
      }.merge(attrs)
    end

    def build_icmp_rule(attrs={})
      {
        'protocol' => 'icmp',
        'type' => 0,
        'code' => 0,
        'destination' => '0.0.0.0/0'
      }.merge(attrs)
    end

    def build_icmpv6_rule(attrs={})
      {
        'protocol' => 'icmpv6',
        'type' => 0,
        'code' => 0,
        'destination' => '::/0'
      }.merge(attrs)
    end

    def build_all_rule(attrs={})
      {
        'protocol' => 'all',
        'destination' => '0.0.0.0/0'
      }.merge(attrs)
    end

    shared_examples 'a transport rule' do
      context 'validates ports' do
        describe 'good' do
          context 'when ports is a range' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '8080-8081') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when ports is a comma separated list' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '8080, 8081') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when ports is a single value' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => ' 8080 ') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end
      end

      context 'validates log' do
        describe 'good' do
          context 'when log is a boolean' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'log' => true) }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when log is not present' do
            let(:rule) { build_transport_rule('protocol' => protocol) }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end

        describe 'bad' do
          context 'when the log is non-boolean' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'log' => 3) }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid log'
            end
          end
        end
      end

      context 'validates destination' do
        context 'good' do
          context 'when it is a valid IP' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when it is a valid CIDR' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/0') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when it is a valid range' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1.-2.2.2.2') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when comma-delimited destinations are enabled' do
            before do
              TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
            end

            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '10.10.10.10,1.1.1.1-2.2.2.2,0.0.0.0/0') }

            it 'allows a destination with a valid IP, range, and CIDR' do
              expect(subject).to be_valid
            end
          end
        end

        context 'bad' do
          context 'when it contains non-CIDR characters' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => 'asdf') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains leading spaces' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => ' 0.0.0.0/0') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains trailing spaces' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/0 ') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains spaces in the list' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0 - 0.0.0.4') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains spaces between ends of a range' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0  - 0.0.0.4') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains a non valid prefix mask' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/33') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains a non IP address' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.257.0.0/20') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it is missing' do
            let(:rule) do
              default_rule = build_transport_rule
              default_rule.delete('destination')
              default_rule
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'destination\''
            end
          end

          context 'when comma-delimited destinations are NOT enabled' do
            context 'the range has more than 2 endpoints' do
              let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1-2.2.2.2-3.3.3.3') }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
              end
            end
          end

          context 'when comma-delimited destinations are enabled' do
            before do
              TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
            end

            context 'and one of the destinations is bogus' do
              let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '10.0.0.0,1.1.1.1-2.2.2.2-3.3.3.3') }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
              end
            end
          end

          context 'when the range is backwards' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '2.2.2.2-1.1.1.1') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when the range has CIDR blocks' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1-2.2.2.2/30') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end
        end
      end

      context 'validates ports' do
        context 'good' do
          context 'when it is a valid CIDR' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/0') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when it is a valid range' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1.-2.2.2.2') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end

        context 'bad' do
          context 'when it contains non-CIDR characters' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => 'asdf') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains a non valid prefix mask' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/33') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains a non IP address' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.257.0.0/20') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it is missing' do
            let(:rule) do
              default_rule = build_transport_rule
              default_rule.delete('destination')
              default_rule
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'destination\''
            end
          end

          context 'when the range has more than 2 endpoints' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1-2.2.2.2-3.3.3.3') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when the range is backwards' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '2.2.2.2-1.1.1.1') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when the range has CIDR blocks' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '1.1.1.1-2.2.2.2/30') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end
        end
      end

      context 'validates description' do
        describe 'good' do
          context 'when description is a string' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'description' => 'this is a description') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'description is not present' do
            let(:rule) { build_transport_rule('protocol' => protocol) }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end

        describe 'bad' do
          context 'description is not a string' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'description' => true) }

            it 'is not valid' do
              expect(subject).not_to be_valid
            end
          end
        end
      end

      context 'when the rule contains extraneous fields' do
        let(:rule) { build_transport_rule('foobar' => 'asdf') }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:rules].length).to eq 1
          expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains the invalid field \'foobar\''
        end
      end
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :spaces }

      describe 'spaces' do
        it { is_expected.to have_associated :spaces }

        it 'can be delete when it has associated spaces' do
          security_group = SecurityGroup.make
          security_group.add_space(Space.make)

          expect { security_group.destroy }.not_to raise_error
        end
      end

      describe 'staging_spaces' do
        it { is_expected.to have_associated :staging_spaces, associated_instance: ->(_) { Space.make } }

        it 'can be delete when it has associated staging_spaces' do
          security_group = SecurityGroup.make
          security_group.add_staging_space(Space.make)

          expect { security_group.destroy }.not_to raise_error
        end
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_uniqueness :name }

      context 'name' do
        subject(:sec_group) { SecurityGroup.make }

        it 'allows standard ascii characters' do
          sec_group.name = "A -_- word 2!?()'\"&+."
          expect do
            sec_group.save
          end.not_to raise_error
        end

        it 'allows backslash characters' do
          sec_group.name = 'a\\word'
          expect do
            sec_group.save
          end.not_to raise_error
        end

        it 'allows unicode characters' do
          sec_group.name = 'Ω∂∂ƒƒß√˜˙∆ß'
          expect do
            sec_group.save
          end.not_to raise_error
        end

        it 'does not allow newline characters' do
          sec_group.name = "one\ntwo"
          expect do
            sec_group.save
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'does not allow escape characters' do
          sec_group.name = "a\e word"
          expect do
            sec_group.save
          end.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'rules' do
        let(:rule) { {} }

        before do
          subject.name = 'foobar'
          subject.rules = [rule]
        end

        context 'is an array of hashes' do
          context 'icmp rule' do
            context 'validates type' do
              context 'good' do
                context 'when the type is a valid 8 bit number' do
                  let(:rule) { build_icmp_rule('type' => 5) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when the type is -1' do
                  let(:rule) { build_icmp_rule('type' => -1) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when the type is non numeric' do
                  let(:rule) { build_icmp_rule('type' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid type'
                  end
                end

                context 'when type cannot be represented in 8 bits' do
                  let(:rule) { build_icmp_rule('type' => 256) }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid type'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_icmp_rule
                    default_rule.delete('type')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'type\''
                  end
                end
              end
            end

            context 'validates code' do
              context 'good' do
                context 'when the type is a valid 8 bit number' do
                  let(:rule) { build_icmp_rule('code' => 5) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when the type is -1' do
                  let(:rule) { build_icmp_rule('code' => -1) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when the type is non numeric' do
                  let(:rule) { build_icmp_rule('code' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid code'
                  end
                end

                context 'when type cannot be represented in 8 bits' do
                  let(:rule) { build_icmp_rule('code' => 256) }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid code'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_icmp_rule
                    default_rule.delete('code')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'code\''
                  end
                end
              end
            end

            context 'validates destination' do
              context 'good' do
                context 'when it is a valid CIDR' do
                  let(:rule) { build_icmp_rule('destination' => '0.0.0.0/0') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when it is a valid IPv6 CIDR' do
                  before do
                    TestConfig.config[:enable_ipv6] = true
                  end

                  let(:rule) { build_icmpv6_rule('destination' => '2001:db8::/32') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when it is a valid range' do
                  let(:rule) { build_icmp_rule('destination' => '1.1.1.1-2.2.2.2') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when it is a valid IPv6 range' do
                  before do
                    TestConfig.config[:enable_ipv6] = true
                  end

                  let(:rule) { build_icmpv6_rule('destination' => '2001:0db8::1-2001:0db8::ff') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when it contains non-CIDR characters' do
                  let(:rule) { build_icmp_rule('destination' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains a non valid prefix mask' do
                  let(:rule) { build_icmp_rule('destination' => '0.0.0.0/33') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains a invalid IP address' do
                  let(:rule) { build_icmp_rule('destination' => '0.257.0.0/20') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_icmp_rule
                    default_rule.delete('destination')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'destination\''
                  end
                end

                context 'when the range has more than 2 endpoints' do
                  let(:rule) { build_icmp_rule('destination' => '1.1.1.1-2.2.2.2-3.3.3.3') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when the range is backwards' do
                  let(:rule) { build_icmp_rule('destination' => '2.2.2.2-1.1.1.1') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when the range has CIDR blocks' do
                  let(:rule) { build_icmp_rule('destination' => '1.1.1.1-2.2.2.2/30') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end
              end
            end

            context 'when the icmp rule contains extraneous fields' do
              let(:rule) { build_icmp_rule(foobar: 'asdf') }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains the invalid field \'foobar\''
              end
            end
          end

          context 'tcp rule' do
            it_behaves_like 'a transport rule' do
              let(:protocol) { 'tcp' }
            end
          end

          context 'udp rule' do
            it_behaves_like 'a transport rule' do
              let(:protocol) { 'udp' }
            end
          end

          context 'all rule' do
            context 'validates destination' do
              context 'good' do
                context 'when it is a valid CIDR' do
                  let(:rule) { build_all_rule('destination' => '0.0.0.0/0') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when it is a valid range' do
                  let(:rule) { build_all_rule('destination' => '1.1.1.1.-2.2.2.2') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when its empty' do
                  let(:rule) { build_all_rule('destination' => '') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains non-CIDR characters' do
                  let(:rule) { build_all_rule('destination' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains a non valid prefix mask' do
                  let(:rule) { build_all_rule('destination' => '0.0.0.0/33') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains a invalid IP address' do
                  let(:rule) { build_all_rule('destination' => '0.257.0.0/20') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_all_rule
                    default_rule.delete('destination')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'destination\''
                  end
                end

                context 'when the range has more than 2 endpoints' do
                  let(:rule) { build_all_rule('destination' => '1.1.1.1-2.2.2.2-3.3.3.3') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when the range is backwards' do
                  let(:rule) { build_all_rule('destination' => '2.2.2.2-1.1.1.1') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when the range has CIDR blocks' do
                  let(:rule) { build_all_rule('destination' => '1.1.1.1-2.2.2.2/30') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end
              end
            end

            context 'validates log' do
              describe 'good' do
                context 'when log is a boolean' do
                  let(:rule) { build_all_rule('log' => true) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when log is not present' do
                  let(:rule) { build_all_rule }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              describe 'bad' do
                context 'when the log is non-boolean' do
                  let(:rule) { build_all_rule('log' => 3) }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid log'
                  end
                end
              end
            end

            context 'when the all rule contains extraneous fields' do
              let(:rule) { build_all_rule({ foobar: 'foobar' }) }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains the invalid field \'foobar\''
              end
            end
          end

          context 'when a rule is not valid' do
            context 'when the protocol is unsupported' do
              let(:rule) { build_transport_rule('protocol' => 'foobar') }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains an unsupported protocol'
              end
            end

            context 'when the protocol is not specified' do
              let(:rule) { {} }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains an unsupported protocol'
              end
            end
          end
        end

        context 'when rules is not JSON' do
          before do
            subject.rules = '{omgbad}'
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors[:rules][0]).to start_with 'value must be an array of hashes'
          end
        end

        context 'when rules is not an array' do
          before do
            subject.rules = { 'valid' => 'json' }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors[:rules][0]).to start_with 'value must be an array of hashes'
          end
        end

        context 'when rules is not an array of hashes' do
          before do
            subject.rules = %w[valid json]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors[:rules][0]).to start_with 'value must be an array of hashes'
          end
        end

        context 'when rules exceeds max number of characters' do
          before do
            stub_const('VCAP::CloudController::SecurityGroup::MAX_RULES_CHAR_LENGTH', 20)
            subject.rules = [build_all_rule] * SecurityGroup::MAX_RULES_CHAR_LENGTH
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors.on(:rules)).to include "length must not exceed #{SecurityGroup::MAX_RULES_CHAR_LENGTH} characters"
          end
        end
      end
    end

    describe '.user_visibility_filter' do
      let(:security_group) { SecurityGroup.make }
      let(:space) { Space.make }
      let(:user) { User.make }

      subject(:filtered_security_groups) do
        SecurityGroup.where(SecurityGroup.user_visibility_filter(user))
      end

      before do
        space.organization.add_user(user)
      end

      it 'includes running security groups associated to spaces where the user is a developer' do
        space.add_developer(user)
        space.add_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes running security groups associated to spaces where the user is a manager' do
        space.add_manager(user)
        space.add_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes running security groups associated to spaces where the user is a auditor' do
        space.add_auditor(user)
        space.add_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes running security groups associated to spaces where the user is an organization manager' do
        space.organization.add_manager(user)
        space.add_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes staging security groups associated to spaces where the user is a developer' do
        space.add_developer(user)
        space.add_staging_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes staging security groups associated to spaces where the user is a manager' do
        space.add_manager(user)
        space.add_staging_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes staging security groups associated to spaces where the user is a auditor' do
        space.add_auditor(user)
        space.add_staging_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes staging security groups associated to spaces where the user is an organization manager' do
        space.organization.add_manager(user)
        space.add_staging_security_group(security_group)
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes security groups that are the running default' do
        security_group.running_default = true
        security_group.save
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'includes security groups that are the staging default' do
        security_group.staging_default = true
        security_group.save
        expect(filtered_security_groups).to contain_exactly(security_group)
      end

      it 'excludes all other security groups' do
        expect(filtered_security_groups).not_to include(security_group)
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :rules, :running_default, :staging_default }
      it { is_expected.to import_attributes :name, :rules, :running_default, :staging_default, :space_guids }
    end
  end
end
