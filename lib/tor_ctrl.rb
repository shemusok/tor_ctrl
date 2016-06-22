require "tor_ctrl/version"
require 'tor_ctrl/file_locker'
require 'tor_ctrl/port_chooser'
require 'tor_ctrl/tor'

require 'singleton'
require 'active_support/core_ext/hash/deep_merge'

require 'awesome_print'

class TorCtrl
  class PortIsBusy < RuntimeError; end

  include Singleton
  include FileLocker
  include PortChooser

  DEFAULT_TOR_OPTIONS = {
    'CookieAuthentication' => 0,
    'HashedControlPassword' => '16:2975244AF33126EF60F9AD6DE8ABD9058BE214A758C214D95EF8577396',
    'NewCircuitPeriod' => 86400,
    'MaxCircuitDirtiness' => 86400
  }
  DEFAULT_OPTIONS = {
    tmp_dir: '/var/tmp/tor_ctrl',
    lock_file: '/var/tmp/tor_ctrl/lock',
    base_port: 45000,
    host: 'localhost',
    tor: DEFAULT_TOR_OPTIONS,
    shutdown: true
  }

  attr_reader :options
  def init options = {}
    @options = DEFAULT_OPTIONS.deep_merge options
    Dir.mkdir @options[:tmp_dir] unless Dir.exists? @options[:tmp_dir]
    at_exit {self.shutdown} if @options[:shutdown]
    self
  end

  def tors
    @tors ||= []
  end

  def create_one port = 45000, tor_options = {}
    raise PortIsBusy if port_open? port
    ctrl_port = choose_port 55000
    raise PortIsBusy if port_open? ctrl_port
    with_lock options[:lock_file] do
      opts = options[:tor].deep_merge tor_options
      tor = Tor.new port, ctrl_port, opts
      tor.start
      tors << tor
      tor
    end
  end

  def create amount = 1, tor_options = {}
    new_tors = amount.times.collect do
      with_lock options[:lock_file] do
        port, ctrl_port = choose_2_ports options[:base_port], options[:host]
        opts = options[:tor].deep_merge tor_options
        tor = Tor.new port, ctrl_port, opts
        tor.start
        tors << tor
        tor
      end
    end
    return new_tors.first if new_tors.count == 1
    new_tors
  end

  def shutdown
    return if tors.empty?
    with_lock options[:lock_file] do
      while tor = tors.shift
        tor.stop
      end
    end
  end
end

# TorCtrl.instance.init.create
