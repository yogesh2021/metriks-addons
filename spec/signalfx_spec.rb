require 'webmock/rspec'
require 'metriks'
require 'metriks-addons/signalfx_reporter'

describe "Smoke test" do
  before(:all) do
    stub_request(:any, "http://localhost:4242")
  end

  before(:each) do
    @registry = Metriks::Registry.new
    @reporter = MetriksAddons::SignalFxReporter.new(
      'http://localhost:4242',
      "123456789",
      "ABCD",
      {:env => "test"},
      { :registry => @registry, :batch_size => 3})
  end

  after(:each) do
    @reporter.stop
    @registry.stop
  end

  it "meter" do
    @registry.meter('meter.testing').mark
    datapoints = @reporter.get_datapoints
    expect(datapoints[:counter].size).to eql(2)
    expect(datapoints[:counter][0][:metric]).to eql("meter.testing.count")
    expect(datapoints[:counter][0][:value]).to eql(1)
    expect(datapoints[:counter][0][:dimensions]).to include(:env => "test")
    expect(datapoints[:counter][0][:timestamp]).not_to be_nil

    expect(datapoints[:counter][1][:metric]).to eql("meter.testing.mean_rate")
    expect(datapoints[:counter][1][:value]).not_to be_nil
    expect(datapoints[:counter][1][:dimensions]).to include(:env => "test")
    expect(datapoints[:counter][1][:timestamp]).not_to be_nil
  end

  it "counter" do
    @registry.counter('counter.testing').increment
    datapoints = @reporter.get_datapoints
    expect(datapoints[:counter].size).to eql(1)
    expect(datapoints[:counter][0][:metric]).to eql("counter.testing.count")
    expect(datapoints[:counter][0][:value]).to eql(1)
    expect(datapoints[:counter][0][:dimensions]).to include(:env => "test")
    expect(datapoints[:counter][0][:timestamp]).not_to be_nil
  end

  it "timer" do
    @registry.timer('timer.testing').update(1.5)
    datapoints = @reporter.get_datapoints
    expect(datapoints[:counter].size).to eql(1)
    expect(datapoints[:gauge].size).to eql(3)
    expect(datapoints[:counter][0][:metric]).to eql("timer.testing.count")
    expect(datapoints[:counter][0][:value]).to eql(1)
    expect(datapoints[:counter][0][:dimensions]).to include(:env => "test")
    expect(datapoints[:counter][0][:timestamp]).not_to be_nil

    expect(datapoints[:gauge][0][:metric]).to eql("timer.testing.min")
    expect(datapoints[:gauge][0][:value]).not_to be_nil
    expect(datapoints[:gauge][0][:dimensions]).to include(:env => "test")
    expect(datapoints[:gauge][0][:timestamp]).not_to be_nil

    expect(datapoints[:gauge][1][:metric]).to eql("timer.testing.max")
    expect(datapoints[:gauge][1][:value]).not_to be_nil
    expect(datapoints[:gauge][1][:dimensions]).to include(:env => "test")
    expect(datapoints[:gauge][1][:timestamp]).not_to be_nil

    expect(datapoints[:gauge][2][:metric]).to eql("timer.testing.mean")
    expect(datapoints[:gauge][2][:value]).not_to be_nil
    expect(datapoints[:gauge][2][:dimensions]).to include(:env => "test")
    expect(datapoints[:gauge][2][:timestamp]).not_to be_nil
  end

  it "gauge" do
    @registry.gauge('gauge.testing') { 123 }
    datapoints = @reporter.get_datapoints
    expect(datapoints[:gauge].size).to eql(1)
    expect(datapoints[:gauge][0][:metric]).to eql("gauge.testing.value")
    expect(datapoints[:gauge][0][:value]).to eql(123)
    expect(datapoints[:gauge][0][:dimensions]).to include(:env => "test")
    expect(datapoints[:gauge][0][:timestamp]).not_to be_nil
  end
end

describe "Rest Client" do
  before(:each) do
    @registry = Metriks::Registry.new
    @reporter = MetriksAddons::SignalFxReporter.new(
      'http://localhost:4242/api/datapoint',
      "123456789",
      "ABCD",
      {:env => "test"},
      { :registry => @registry, :batch_size => 3})
    stub_request(:post, "http://localhost:4242/api/datapoint?orgid=ABCD").
      with(:body => /^\{.*\}$/).
      to_return(:status => 200, :body => "", :headers => {})
  end

  it "Send metricwise" do
    for i in 0..2 do
      @registry.counter("counter.testing.#{i}").increment
    end
    @registry.gauge("gauge.testing")
    @reporter.submit @reporter.get_datapoints
    expect(a_request(:post, "http://localhost:4242/api/datapoint?orgid=ABCD")).to have_been_made
  end
end
