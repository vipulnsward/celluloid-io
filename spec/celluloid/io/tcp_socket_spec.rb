require 'spec_helper'

describe Celluloid::IO::TCPSocket do
  let(:payload) { 'ohai' }

  context "inside Celluloid::IO" do
    it "connects to TCP servers" do
      server = ::TCPServer.new example_addr, example_port
      thread = Thread.new { server.accept }
      socket = within_io_actor { Celluloid::IO::TCPSocket.new example_addr, example_port }
      peer = thread.value

      peer << payload
      within_io_actor { socket.read(payload.size) }.should eq payload

      server.close
      socket.close
      peer.close
    end

    it "should be evented" do
      with_connected_sockets do |subject|
        within_io_actor { subject.evented? }.should be_true
      end
    end

    it "read complete payload when nil size is given to #read" do
      with_connected_sockets do |subject, peer|
        peer << payload
        within_io_actor { subject.read(nil) }.should eq payload
      end
    end

    it "read complete payload when no size is given to #read" do
      with_connected_sockets do |subject, peer|
        peer << payload
        within_io_actor { subject.read }.should eq payload
      end
    end

    it "reads data" do
      with_connected_sockets do |subject, peer|
        peer << payload
        within_io_actor { subject.read(payload.size) }.should eq payload
      end
    end

    it "reads data in ASCII-8BIT encoding" do
      with_connected_sockets do |subject, peer|
        peer << payload
        within_io_actor { subject.read(payload.size).encoding }.should eq Encoding::ASCII_8BIT
      end
    end

    it "reads partial data" do
      with_connected_sockets do |subject, peer|
        peer << payload * 2
        within_io_actor { subject.readpartial(payload.size) }.should eq payload
      end
    end

    it "reads partial data in ASCII-8BIT encoding" do
      with_connected_sockets do |subject, peer|
        peer << payload * 2
        within_io_actor { subject.readpartial(payload.size).encoding }.should eq Encoding::ASCII_8BIT
      end
    end

    it "writes data" do
      with_connected_sockets do |subject, peer|
        within_io_actor { subject << payload }
        peer.read(payload.size).should eq payload
      end
    end

    it "raises Errno::ECONNREFUSED when the connection is refused" do
      expect {
        within_io_actor { ::TCPSocket.new(example_addr, example_port) }
      }.to raise_error(Errno::ECONNREFUSED)
    end

    context "readpartial" do
      it "raises EOFError when reading from a closed socket" do
        with_connected_sockets do |subject, peer|
          peer.close
          expect {
            within_io_actor { subject.readpartial(payload.size) }
          }.to raise_error(EOFError)
        end
      end

      it "raises IOError when active sockets are closed across threads" do
	      pending "not implemented"

        with_connected_sockets do |subject, peer|
          actor = ExampleActor.new
          begin
            read_future = actor.future.wrap do
              subject.readpartial(payload.size)
            end
            sleep 0.1
            subject.close
            expect { read_future.value 0.25 }.to raise_error(IOError)
          ensure
            actor.terminate if actor.alive?
          end
        end
      end

      it "raises IOError when partial reading from a socket the peer closed" do
        with_connected_sockets do |subject, peer|
          actor = ExampleActor.new
          begin
            actor.async.wrap { sleep 0.01; peer.close }
            expect do
              within_io_actor { subject.readpartial(payload.size) }
            end.to raise_error(IOError)
          ensure
            actor.terminate if actor.alive?
          end
        end
      end
    end
  end

  context "outside Celluloid::IO" do
    it "connects to TCP servers" do
      server = ::TCPServer.new example_addr, example_port
      thread = Thread.new { server.accept }
      socket = Celluloid::IO::TCPSocket.new example_addr, example_port
      peer = thread.value

      peer << payload
      socket.read(payload.size).should eq payload

      server.close
      socket.close
      peer.close
    end

    it "should be blocking" do
      with_connected_sockets do |subject|
        subject.should_not be_evented
      end
    end

    it "reads data" do
      with_connected_sockets do |subject, peer|
        peer << payload
        subject.read(payload.size).should eq payload
      end
    end

    it "reads partial data" do
      with_connected_sockets do |subject, peer|
        peer << payload * 2
        subject.readpartial(payload.size).should eq payload
      end
    end

    it "writes data" do
      with_connected_sockets do |subject, peer|
        subject << payload
        peer.read(payload.size).should eq payload
      end
    end
  end
end
