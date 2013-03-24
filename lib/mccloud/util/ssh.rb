module Mccloud
  module Util

    class Ssh
    def self.when_ssh_login_works(ip="localhost", options = {  } , &block)

      defaults={ :port => '22', :timeout => 20000 , :user => 'vagrant', :password => 'vagrant'}

      options=defaults.merge(options)

      puts
      puts "Waiting for ssh login on #{ip} with user #{options[:user]} to sshd on port => #{options[:port]} to work (Timeout in #{options[:timeout]} seconds)"

      begin
        Timeout::timeout(options[:timeout]) do
          connected=false
          while !connected do
            begin
              print "."
              Net::SSH.start(ip, options[:user], { :port => options[:port] , :password => options[:password], :paranoid => false, :timeout => options[:timeout] ,:keys => options[:keys] }) do |ssh|
                block.call(ip);
                puts ""
                return true
              end
            rescue Net::SSH::AuthenticationFailed,Net::SSH::Disconnect,Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNABORTED, Errno::ECONNRESET, Errno::ENETUNREACH
              sleep 5
            end
          end
        end
      rescue Timeout::Error
        raise 'ssh timeout'
      end
      puts ""
      return false
    end


    def self.transfer_file(host,filename,destination = '.' , options = {})

      unless File.exists?(filename)
        raise Mccloud::Error,"Can't transfer #{filename}: does not exist"
      end

      Net::SSH.start( host,options[:user],options ) do |ssh|
        puts "Transferring #{filename} to #{destination} "
        ssh.scp.upload!( filename, destination ) do |ch, name, sent, total|
          #   print "\r#{destination}: #{(sent.to_f * 100 / total.to_f).to_i}%"
          print "."

        end
      end
      puts
    end


    #we need to try the actual login because vbox gives us a connect
    #after the machine boots
    def self.execute_when_tcp_available(ip="localhost", options = { } , &block)

      defaults={ :port => 22, :timeout => 20000 , :pollrate => 5}

      options=defaults.merge(options)

      begin
        Timeout::timeout(options[:timeout]) do
          connected=false
          while !connected do
            begin
              #puts "trying connection"
              s = TCPSocket.new(ip, options[:port])
              s.close
              block.call(ip);
              return true
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH,Errno::ETIMEDOUT
              sleep options[:pollrate]
            end
          end
        end
      rescue Timeout::Error
        raise 'timeout connecting to port'
      end

      return false
    end

    def self.ssh(host ,user , options = { :progress => "on" } ,command=nil ,exitcode=0)

      defaults= { :port => "22",  :user => "root", :paranoid => false }
      options=defaults.merge(options)
      @pid=""
      @stdin=command
      @stdout=""
      @stderr=""
      @status=-99999

      puts "Executing command: #{command}"

      Net::SSH.start(host, user, options) do |ssh|

        # open a new channel and configure a minimal set of callbacks, then run
        # the event loop until the channel finishes (closes)
        channel = ssh.open_channel do |ch|

          #request pty for sudo stuff and so
          ch.request_pty do |ch, success|
            raise "Error requesting pty" unless success
          end


          ch.exec "#{command}" do |ch, success|
            raise "could not execute command" unless success



            # "on_data" is called when the process writes something to stdout
            ch.on_data do |c, data|
              @stdout+=data

              puts data

            end

            # "on_extended_data" is called when the process writes something to stderr
            ch.on_extended_data do |c, type, data|
              @stderr+=data

              puts data

            end

            #exit code
            #http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/a806b0f5dae4e1e2
            channel.on_request("exit-status") do |ch, data|
              exit_code = data.read_long
              @status=exit_code
              if exit_code > 0
                puts "ERROR: exit code #{exit_code}"
              else
                #puts "Successfully executed"
              end
            end

            channel.on_request("exit-signal") do |ch, data|
              puts "SIGNAL: #{data.read_long}"
            end

            ch.on_close {
              #puts "done!"
            }
            #status=ch.exec "echo $?"
          end
        end
        channel.wait
      end


      if (@status.to_s != exitcode.to_s )
        if (exitcode=="*")
          #its a test so we don't need to worry
        else
          puts "Exitcode = #{exitcode} - #{@status.to_s}"
          raise "Exitcode was not what we expected"
        end

      end

    end

  end #Class

   end #Module

end #Module
