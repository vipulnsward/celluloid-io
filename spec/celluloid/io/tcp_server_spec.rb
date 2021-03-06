require 'spec_helper'

describe Celluloid::IO::TCPServer do
  describe "#accept" do
    let(:payload) { 'ohai' }

    context "inside Celluloid::IO" do
      it "should be evented" do
        with_tcp_server do |subject|
          within_io_actor { subject.evented? }.should be_true
        end
      end

      it "accepts a connection and returns a Celluloid::IO::TCPSocket" do
        with_tcp_server do |subject|
          thread = Thread.new { TCPSocket.new(example_addr, example_port) }
          peer = within_io_actor { subject.accept }
          peer.should be_a Celluloid::IO::TCPSocket

          client = thread.value
          client.write payload
          peer.read(payload.size).should eq payload
        end
      end

      context "outside Celluloid::IO" do
        it "should be blocking" do
          with_tcp_server do |subject|
            subject.should_not be_evented
          end
        end

        it "accepts a connection and returns a Celluloid::IO::TCPSocket" do
          with_tcp_server do |subject|
            thread = Thread.new { TCPSocket.new(example_addr, example_port) }
            peer   = subject.accept
            peer.should be_a Celluloid::IO::TCPSocket

            client = thread.value
            client.write payload
            peer.read(payload.size).should eq payload
          end
        end
      end
    end
  end
end
