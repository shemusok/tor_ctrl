require 'socket'
require 'timeout'

module TorCtrl::PortChooser
  def choose_port base_port, ip = 'localhost', timeout = 1
    (base_port..65535).each do |port|
      return port unless port_open? port, ip, timeout
    end
  end

  def choose_2_ports base_port, ip = 'localhost', timeout = 1
    port1 = choose_port base_port, ip, timeout
    port2 = choose_port port1 + 1, ip, timeout
    [port1, port2]
  end

  def port_open? port, ip = 'localhost', timeout = 1
    Timeout::timeout timeout do
      begin
        TCPSocket.new(ip, port).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      end
    end
  rescue Timeout::Error
    false
  end
end
