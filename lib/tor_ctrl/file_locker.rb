
module FileLocker
  def stamp
    @stamp ||= "#{Thread.current.object_id}@#{$$}"
  end

  def with_lock file
    open(file, 'w') do |f|
      begin
        flock f do |f|
          f.puts stamp
          f.flush
          yield if block_given?
        end
      rescue => e
        if e.message == 'failed to lock file'
          raise $!, "#{stamp}: failed to lock file '#{file}'", $!.backtrace
        else
          raise $!, "#{stamp}: #{$!}", $!.backtrace
        end
      end
    end
  end

  protected
    def flock file, mode = File::LOCK_EX
      success = file.flock mode
      if success
        begin
          yield file if block_given?
        ensure
          file.flock File::LOCK_UN
        end
      else
        raise "failed to lock file"
      end
    end
end
