require 'spec_helper'
require 'socket'

def port_in_use?(port, host='127.0.0.1')
  s = TCPServer.new host, port
  s.close
  false
rescue Errno::EADDRINUSE
  true
end

def port_alive?(port, host='127.0.0.1')
  s = TCPSocket.new host, port
  s.close
  false
rescue Errno::ECONNREFUSED
  true
end

describe Rbuv::Tcp do
  it { is_expected.to be_a_kind_of Rbuv::Stream }

  let(:loop) { Rbuv::Loop.new }

  it "#bind" do
    expect(port_in_use?(60000)).to be false

    loop.run do
      skip "this spec does't pass on linux machines, see #1 on github"
      begin
        tcp = Rbuv::Tcp.new(loop)
        tcp.bind '127.0.0.1', 60000

        expect(port_in_use?(60000)).to be true
      ensure
        tcp.close
      end

      expect(port_in_use?(60000)).to be false
    end
  end

  context "#listen" do
    it "when address not in use" do
      expect(port_in_use?(60000)).to be false

      loop.run do
        begin
          tcp = Rbuv::Tcp.new(loop)
          tcp.bind '127.0.0.1', 60000
          tcp.listen(10) { Rbuv.stop_loop }

          expect(port_in_use?(60000)).to be true
        ensure
          tcp.close
        end

        expect(port_in_use?(60000)).to be false
      end
    end

    it "when address already in use" do
      expect(port_in_use?(60000)).to be false

      loop.run do
        begin
          s = TCPServer.new '127.0.0.1', 60000

          tcp = Rbuv::Tcp.new(loop)
          tcp.bind '127.0.0.1', 60000
          expect { tcp.listen(10) {} }.to raise_error
        ensure
          s.close
          tcp.close
        end
      end
    end

    it "should call the on_connection callback when connection coming" do
      on_connection = double
      expect(on_connection).to receive(:call).once

      loop.run do
        tcp = Rbuv::Tcp.new(loop)
        tcp.bind '127.0.0.1', 60000

        tcp.listen(10) do
          on_connection.call
          tcp.close
        end

        sock = TCPSocket.new '127.0.0.1', 60000
        sock.close
      end
    end
  end

  context "#accept" do
    context "with a client as a paramenter" do
      it "does not raise an error" do
        expect(port_in_use?(60000)).to be false

        loop.run do
          tcp = Rbuv::Tcp.new(loop)
          tcp.bind '127.0.0.1', 60000

          sock = nil

          tcp.listen(10) do |s|
            c = Rbuv::Tcp.new(loop)
            expect { s.accept(c) }.not_to raise_error
            sock.close
            tcp.close
          end

          sock = TCPSocket.new '127.0.0.1', 60000
        end
      end
    end

    context "with no parameters" do
      it "returns a Rbuv::Tcp" do
        expect(port_in_use?(60000)).to be false

        loop.run do
          tcp = Rbuv::Tcp.new(loop)
          tcp.bind '127.0.0.1', 60000

          sock = nil

          tcp.listen(10) do |s|
            client = s.accept
            expect(client).to be_a Rbuv::Tcp
            sock.close
            tcp.close
          end

          sock = TCPSocket.new '127.0.0.1', 60000
        end
      end

      it "does not return self" do
        expect(port_in_use?(60000)).to be false

        loop.run do
          tcp = Rbuv::Tcp.new(loop)
          tcp.bind '127.0.0.1', 60000

          sock = nil

          tcp.listen(10) do |s|
            client = s.accept
            expect(client).not_to be s
            sock.close
            tcp.close
          end

          sock = TCPSocket.new '127.0.0.1', 60000
        end
      end
    end
  end

  context "#close" do
    it "affect #closing?" do
      loop.run do
        tcp = Rbuv::Tcp.new(loop)
        tcp.close do
          expect(tcp.closing?).to be true
        end
        expect(tcp.closing?).to be true
      end
    end

    it "call once" do
      on_close = double
      expect(on_close).to receive(:call).once

      loop.run do
        tcp = Rbuv::Tcp.new(loop)

        tcp.close do
          on_close.call
        end
      end
    end

    it "call multi-times" do
      on_close = double
      expect(on_close).to receive(:call).once

      no_on_close = double
      expect(no_on_close).not_to receive(:call)

      loop.run do
        tcp = Rbuv::Tcp.new(loop)

        tcp.close do
          on_close.call
        end

        tcp.close do
          no_on_close.call
        end
      end
    end # context "#close"

    context "#connect" do
      it "when server does not exist" do
        loop.run do
          c = Rbuv::Tcp.new(loop)
          c.connect('127.0.0.1', 60000) do |client, error|
            expect(error).to be_a_kind_of Rbuv::Error
            c.close
          end
        end
      end

      it "when server exists" do
        s = TCPServer.new '127.0.0.1', 60000
        s.listen 10

        on_connect = double
        expect(on_connect).to receive(:call).once

        loop.run do
          c = Rbuv::Tcp.new(loop)
          c.connect('127.0.0.1', 60000) do
            on_connect.call
            c.close
            s.close
          end
        end
      end
    end

  end
end
