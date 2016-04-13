require 'tor_ctrl'
require 'thread'

class TorCtrl::Tor
  attr_reader :port
  attr_reader :ctrl_port
  attr_reader :options
  def initialize port, ctrl_port, options = TorCtrl::DEFAULT_TOR_OPTIONS
    @port = port
    @ctrl_port = ctrl_port
    @options = options
  end

  def to_s
    "socks5://localhost:#{port}"
  end

  def ctrl
    @ctrl ||= TorCtrl.instance
  end

  def pid_file
    @pid_file ||= "#{data_directory}.pid"
  end

  def log_file
    @log_file ||= "#{data_directory}/log"
  end

  def data_directory
    @data_directory ||= "#{ctrl.options[:tmp_dir]}/#{port}"
  end

  def cmd
    @cmd ||= %W<
      tor
      --SocksPort #{port}
      --ControlPort #{ctrl_port}
      --PidFile #{pid_file}
      --DataDirectory #{data_directory}
      --Log err\ file\ #{log_file}
    > + options.collect {|k,v| ["--#{k}", v.to_s]}.flatten
  end

  def running?
    ctrl.port_open? port
  end

  def pid
    return @pid if @pid
    raise "pid file '#{pid_file}' not exists for tor launched with '#{cmd.join ' '}'" unless File.exists? pid_file
    @pid = File.read(pid_file).chomp.to_i
  end

  def start
    puts "starting tor with cmd: '#{cmd.join ' '}'"
    # @pid = Process.spawn(*cmd, {[:out, :err] => [log_file, 'w']}) # TODO: raise on shit
    @pid = Process.spawn(*cmd, {[:out, :err] => [log_file, 'w']}) # TODO: raise on shit
    16.times do
      sleep 1
      if running?
        puts "tor started with cmd '#{cmd.join ' '}'"
        return self
      end
    end
    Process.kill 'TERM', pid
    Process.wait pid
    raise "failed to start tor with cmd '#{cmd.join ' '}'"
  end

  def stop
    Process.kill 'TERM', pid
    Process.wait pid
    puts "tor stoped - cmd '#{cmd.join ' '}'"
  end

  def hup
    Process.kill 'HUP', pid
    puts "tor hupped - cmd '#{cmd.join ' '}'"
  end

  def restart
    stop
    start
  end
end
