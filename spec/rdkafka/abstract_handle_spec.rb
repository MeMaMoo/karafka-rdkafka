# frozen_string_literal: true

describe Rdkafka::AbstractHandle do
  let(:response) { 0 }
  let(:result) { -1 }

  context "A subclass that does not implement the required methods" do

    class BadTestHandle < Rdkafka::AbstractHandle
      layout :pending, :bool,
             :response, :int
    end

    it "raises an exception if operation_name is called" do
      expect {
        BadTestHandle.new.operation_name
      }.to raise_exception(RuntimeError, /Must be implemented by subclass!/)
    end

    it "raises an exception if create_result is called" do
      expect {
        BadTestHandle.new.create_result
      }.to raise_exception(RuntimeError, /Must be implemented by subclass!/)
    end
  end

  class TestHandle < Rdkafka::AbstractHandle
    layout :pending, :bool,
           :response, :int,
           :result, :int

    def operation_name
      "test_operation"
    end

    def create_result
      self[:result]
    end
  end

  subject do
    TestHandle.new.tap do |handle|
      handle[:pending] = pending_handle
      handle[:response] = response
      handle[:result] = result
    end
  end

  describe ".register and .remove" do
    let(:pending_handle) { true }

    it "should register and remove a delivery handle" do
      Rdkafka::AbstractHandle.register(subject)
      removed = Rdkafka::AbstractHandle.remove(subject.to_ptr.address)
      expect(removed).to eq subject
      expect(Rdkafka::AbstractHandle::REGISTRY).to be_empty
    end
  end

  describe "#pending?" do
    context "when true" do
      let(:pending_handle) { true }

      it "should be true" do
        expect(subject.pending?).to be true
      end
    end

    context "when not true" do
      let(:pending_handle) { false }

      it "should be false" do
        expect(subject.pending?).to be false
      end
    end
  end

  describe "#wait" do
    context 'when pending_handle true' do
      let(:pending_handle) { true }

      it "should wait until the timeout and then raise an error" do
        expect(Kernel).not_to receive(:warn)
        expect {
          subject.wait(max_wait_timeout: 0.1)
        }.to raise_error Rdkafka::AbstractHandle::WaitTimeoutError, /test_operation/
      end
    end

    context 'when pending_handle false' do
      let(:pending_handle) { false }

      it 'should show a deprecation warning when wait_timeout is set' do
        expect(Kernel).to receive(:warn).with(Rdkafka::AbstractHandle::WAIT_TIMEOUT_DEPRECATION_MESSAGE)
        subject.wait(wait_timeout: 0.1)
      end

      context "without error" do
        let(:result) { 1 }

        it "should return a result" do
          expect(Kernel).not_to receive(:warn)
          wait_result = subject.wait
          expect(wait_result).to eq(result)
        end

        it "should wait without a timeout" do
          expect(Kernel).not_to receive(:warn)
          wait_result = subject.wait(max_wait_timeout: nil)
          expect(wait_result).to eq(result)
        end
      end

      context "with error" do
        let(:response) { 20 }

        it "should raise an rdkafka error" do
          expect(Kernel).not_to receive(:warn)
          expect {
            subject.wait
          }.to raise_error Rdkafka::RdkafkaError
        end
      end
    end
  end
end
