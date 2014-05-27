require 'spec_helper'

describe FilterHelper do
  let(:site)    { build(:site) }
  let(:hostname){ site.default_host.hostname }
  let(:mapping) { build :mapping, site: site }

  describe '#filter_by_type_path' do
    subject { helper.filter_by_type_path('redirect') }
    let(:page){2}
    let(:type){''}
    before do
      helper.stub(:params).and_return({page: page, type: type})
    end

    context 'without any parameters' do
      before do
        helper.stub(:params).and_return({})
      end
      it { should eql({type: 'redirect'}) }
    end

    context 'with a page parameter' do
      it { should eql({type: 'redirect'}) }
    end

    context 'with existing other parameters' do
      before do
        helper.stub(:params).and_return({tagged: 'a,b'})
      end
      it { should eql({tagged: 'a,b', type: 'redirect'}) }
    end

    context 'with type already present' do
      let(:type){'archive'}
      it { should eql({type: 'redirect'}) }
    end
  end

  describe '#remove_filter_by_type_path' do
    subject { helper.remove_filter_by_type_path }
    let(:page){2}
    let(:type){'redirect'}
    before do
      helper.stub(:params).and_return({page: page, type: type})
    end

    context 'without any parameters' do
      before do
        helper.stub(:params).and_return({})
      end
      it { should eql({}) }
    end

    context 'with a page and type parameter' do
      it { should eql({}) }
    end

    context 'with existing other parameters' do
      before do
        helper.stub(:params).and_return({tagged: 'a,b', type: 'redirect'})
      end
      it { should eql({tagged: 'a,b'}) }
    end
  end
end
