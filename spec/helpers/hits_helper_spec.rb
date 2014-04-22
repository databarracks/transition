require 'spec_helper'

describe HitsHelper do
  describe '#link_to_hit' do
    let(:hit) { build :hit }
    specify { helper.link_to_hit(hit).should =~ %r(<a href="http://.*example\.gov\.uk/article/123">/article/123</a>) }
  end

  describe '#any_totals_for' do
    let(:all_cats)  { View::Hits::Category.all }
    let(:some_totals) { all_cats.map { |cat| cat.tap {|c| c.points = [build(:daily_hit_total)] } } }
    let(:no_totals)   { all_cats.map { |cat| cat.tap {|c| c.points = [] } } }

    context 'there are totals' do
      it 'is true' do
        helper.any_totals_for?(some_totals).should be_true
      end
    end

    context 'there are no totals' do
      it 'is false' do
        helper.any_totals_for?(no_totals).should be_false
      end

      it 'is false' do
        helper.any_totals_for?(nil).should be_false
      end
    end
  end

  describe '#google_data_table' do
    let(:archives) { [
      build(:daily_hit_total, total_on: '2012-12-31', count: 3, http_status: 410),
      build(:daily_hit_total, total_on: '2012-12-30', count: 1000, http_status: 410)
    ] }

    let(:errors) { [
      build(:daily_hit_total, total_on: '2012-12-31', count: 3, http_status: 404),
      build(:daily_hit_total, total_on: '2012-12-30', count: 4, http_status: 404)
    ] }

    let(:redirects) { [
      build(:daily_hit_total, total_on: '2012-12-30', count: 4, http_status: 301)
    ] }

    let(:categories) {
      [
        View::Hits::Category['archives'].tap { |c| c.points = archives },
        View::Hits::Category['errors'].tap { |c| c.points = errors },
        View::Hits::Category['redirects'].tap { |c| c.points = redirects }
      ]
    }

    let(:live_site_that_transitioned_on_2012_12_30) do
       site = build(:site, launch_date: Date.new(2012,12,30))
       site.hosts << build(:host, cname: 'redirector-cdn.production.govuk.service.gov.uk')
       site.save
       site
    end

    subject(:array) { helper.google_data_table(categories, live_site_that_transitioned_on_2012_12_30) }

    it { should be_a(String) }
    it { should include('{"label":"Date","type":"date"}') }
    it { should include('{"label":"Archives","type":"number"},{"label":"Errors","type":"number"},{"label":"Redirects","type":"number"}') }
    it { should_not include('nil') }

    describe 'it includes a normal data row' do
      it { should include('{"c":[{"v":"Date(2012, 11, 31)"},{"v":""},{"v":3,"f":"3"},{"v":3,"f":"3"},{"v":0,"f":"0"}]}') }
    end

    describe 'it includes an annotation on the transition date' do
      it { should include('{"c":[{"v":"Date(2012, 11, 30)"},{"v":"Transition"},{"v":1000,"f":"1,000"},{"v":4,"f":"4"},{"v":4,"f":"4"}]}') }
    end
  end
end
