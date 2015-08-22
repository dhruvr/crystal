require "spec"
require "socket"

describe "UNIXSocket" do
  it "sends and receives messages" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      server.addr.family.should eq("AF_UNIX")
      server.addr.path.should eq(path)

      UNIXSocket.open(path) do |client|
        client.addr.family.should eq("AF_UNIX")
        client.addr.path.should eq(path)

        server.accept do |sock|
          sock.addr.family.should eq("AF_UNIX")
          sock.addr.path.should eq("")

          sock.peeraddr.family.should eq("AF_UNIX")
          sock.peeraddr.path.should eq("")

          client << "ping"
          sock.read(4).should eq("ping")
          sock << "pong"
          client.read(4).should eq("pong")
        end
      end
    end
  end

  it "creates a pair of sockets" do
    UNIXSocket.pair do |left, right|
      left.addr.family.should eq("AF_UNIX")
      left.addr.path.should eq("")

      left << "ping"
      right.read(4).should eq("ping")
      right << "pong"
      left.read(4).should eq("pong")
    end
  end

  it "tests read and write timeouts" do
    UNIXSocket.pair do |left, right|
# BUG: shrink the socket buffers first
      left.write_timeout = 0.0001
      right.read_timeout = 0.0001
      buf = ("a" * 4096).to_slice

      expect_raises(IO::Timeout, "write timed out") do
        loop { left.write buf }
      end

      expect_raises(IO::Timeout, "read timed out") do
        loop { right.read buf }
      end
    end
  end


  it "creates the socket file" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do
      File.exists?(path).should be_true
    end
  end
end

describe "TCPSocket" do
  it "sends and receives messages" do
    TCPServer.open("::", 12345) do |server|
      server.addr.family.should eq("AF_INET6")
      server.addr.ip_port.should eq(12345)
      server.addr.ip_address.should eq("::")

      TCPSocket.open("localhost", 12345) do |client|
        # The commented lines are actually dependant on the system configuration,
        # so for now we keep it commented. Once we can force the family
        # we can uncomment them.

        # client.addr.family.should eq("AF_INET")
        # client.addr.ip_address.should eq("127.0.0.1")

        sock = server.accept

        # sock.addr.family.should eq("AF_INET6")
        # sock.addr.ip_port.should eq(12345)
        # sock.addr.ip_address.should eq("::ffff:127.0.0.1")

        # sock.peeraddr.family.should eq("AF_INET6")
        # sock.peeraddr.ip_address.should eq("::ffff:127.0.0.1")

        client << "ping"
        sock.read(4).should eq("ping")
        sock << "pong"
        client.read(4).should eq("pong")
      end
    end
  end

  it "fails when connection is refused" do
    expect_raises(Errno, "Error connecting to 'localhost:12345': Connection refused") do
      TCPSocket.new("localhost", 12345)
    end
  end

  it "fails when host doesn't exist" do
    expect_raises(SocketError, /^getaddrinfo: (.+ not known|no address .+|Non-recoverable failure in name resolution)$/i) do
      TCPSocket.new("localhostttttt", 12345)
    end
  end
end

describe "UDPSocket" do
  it "sends and receives messages" do
    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::", 12346)

    server.addr.family.should eq("AF_INET6")
    server.addr.ip_port.should eq(12346)
    server.addr.ip_address.should eq("::")

    client = UDPSocket.new(Socket::Family::INET)
    client.connect("localhost", 12346)

    client.addr.family.should eq("AF_INET")
    client.addr.ip_address.should eq("127.0.0.1")
    client.peeraddr.family.should eq("AF_INET")
    client.peeraddr.ip_port.should eq(12346)
    client.peeraddr.ip_address.should eq("127.0.0.1")

    client << "message"
    server.read(7).should eq("message")

    client.close
    server.close
  end
end
