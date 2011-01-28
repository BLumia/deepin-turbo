#!/usr/bin/ruby
# Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies).
# All rights reserved.
# Contact: Nokia Corporation (directui@nokia.com)
#
# This file is part of applauncherd.
#
# If you have questions regarding the use of this file, please contact
# Nokia at directui@nokia.com.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation
# and appearing in the file LICENSE.LGPL included in the packaging
# of this file.
#
#  * Description: Performance Test for applauncherd 
#   
#  * Objectives: test the startup time for applications
#    

#require 'tdriver'
require 'date'
require 'test/unit'
require 'optparse'

class TC_PerformanceTests < Test::Unit::TestCase
  COUNT = 3
  PIXELCHANGED_BINARY= '/usr/bin/fala_pixelchanged' 
  TEST_SCRIPT_LOCATION = '/usr/share/applauncherd-testscripts'
  GET_COORDINATES_SCRIPT="#{TEST_SCRIPT_LOCATION}/get-coordinates.rb"
  PIXELCHANGED_LOG = '/tmp/fala_pixelchanged.log'
  FALA_GETTIME_BINARY = '/usr/bin/fala_gettime_ms'
  MATTI_LOCATION='/usr/lib/qt4/plugins/testability/libtestability.so'
  TEMPORARY_MATTI_LOCATION='/root/libtestability.so'
  TESTAPP_LOG = '/tmp/testapp.log'

  @start_time = 0
  @end_time = 0
  @app_from_cache = 0
  @win_from_cache = 0
  @pos = 0
  @options = {}  
 

  $path = string = `echo $PATH `
  
  # method called before any test case
  def setup

     optparse = OptionParser.new do|opts|
      options = {}  
      # Set a banner, displayed at the top
      # of the help screen.
      opts.banner = "Usage: get-coordinates.rb [options] "
      
      options[:application] = nil
      opts.on( '-a', '--application APP', 'Application name in application grid' ) do|app|
        options[:application] = app
      end

      options[:binary] = nil
      opts.on( '-b', '--binary BINARY', 'Name of the application binary which is used when killing the application' ) do|binary|
        options[:binary] = binary
      end

      options[:command] = nil
      opts.on( '-c', '--command_line COMMAND', 'Start application from witc COMMAND from command line instead of grid.' ) do|command|
        options[:command] = command
      end

      options[:limit] = nil
      opts.on( '-l', '--limit MILLISECONDS', 'Time limit in milliseconds. Slower startup will make test to fail.' ) do|milliseconds|
        options[:limit] = milliseconds.to_i
      end

      options[:pre_step] = nil
      opts.on( '-p', '--pre_step PRE_STEP', 'Command to be executed everytime before starting the application' ) do|pre_step|
        options[:pre_step] = pre_step
      end
      
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit 0
      end
      @options=options
    end


    optparse.parse!
 

    if @options[:application] == nil &&  @options[:command] == nil
      puts "Application not defined!" 
      exit 1
    end

    if @options[:binary] == nil
      puts "Binary of the application not defined!" 
      exit 1
    end


    if @options[:command] != nil
      puts "#{@options[:command]}" 
    end

    if @options[:pre_step] != nil
      puts "#{@options[:pre_step]}" 
    end

    if $path.include?("scratchbox")
      puts "Inside SB, Do Nothing to unlock"
    else
      system "mcetool --set-tklock-mode=unlocked"
      system "mcetool --set-inhibit-mode=stay-on"
    end        

    system("initctl restart xsession/mthome")
    system "mv #{MATTI_LOCATION} #{TEMPORARY_MATTI_LOCATION}"
    system("initctl restart xsession/applauncherd")
    sleep(10)
  end
  

        
  # method called after any test case for cleanup purposes
  def teardown
    puts "exit from teardown"
    system "mv #{TEMPORARY_MATTI_LOCATION} #{MATTI_LOCATION}"
    if @options[:application] != nil     
      system("initctl restart xsession/mthome")
      sleep(10)
    end
  end
  
  def open_Apps(appName)
    
    #Remove the Log file if it exists
    if FileTest.exists?(PIXELCHANGED_LOG)
      system "rm #{PIXELCHANGED_LOG}"
    end
    if FileTest.exists?(TESTAPP_LOG)
      system "rm #{TESTAPP_LOG}"
    end
    # Kill the binary if alive
    system "pkill #{@options[:binary]}"
    sleep(2)

    if @options[:command] != nil
      # execute the optional command if available
      if @options[:pre_step] != nil 
        puts "pre_step: #{@options[:pre_step]}"
        system "#{@options[:pre_step]}"
      end


      # Check the avarage system load is under 0.3
      system "/usr/bin/waitloadavg.rb -l 0.3 -p 1.0 -t 100 -d"
      start_command ="`#{PIXELCHANGED_BINARY} -t 20x20 -t 840x466 -q >> #{PIXELCHANGED_LOG} &`; #{FALA_GETTIME_BINARY} \"Started from command line\" >>  #{PIXELCHANGED_LOG}; #{@options[:command]} &"
      puts "start command: #{start_command}"
      system "#{start_command}"
      sleep (4)
      puts "pkill \"#{@options[:binary]}\""
      system "pkill \"#{@options[:binary]}\""

    else
     # execute the optional command if available
      if @options[:pre_step] != nil 
        puts "pre_step: #{@options[:pre_step]}"
        system "#{@options[:pre_step]}"
      end
        
      @pos = `#{GET_COORDINATES_SCRIPT} -a #{@options[:application]}`
      puts "original: #{@pos}"
      @pos = @pos.split("\n")[-1]
 
      system "/usr/bin/waitloadavg.rb -l 0.3 -p 1.0 -t 50 -d"
      cmd = "#{PIXELCHANGED_BINARY} -c #{@pos} -t 20x20 -t 840x466 -f #{PIXELCHANGED_LOG} -q"
      puts cmd
      system cmd
      sleep (4)
      # Raise meegotouchhome to the top.
      #Workaround for keeping the window stack in shape.
      system "#{GET_COORDINATES_SCRIPT} -g"

      system "pkill #{@options[:binary]}"
    end

  end
  
  def read_file(appName)
    #Reading the log file to get the time
    
    lines = File.open(PIXELCHANGED_LOG).readlines().collect { |x| x.split(" ")[0].to_i }
    lines_app = File.open(TESTAPP_LOG).readlines().collect { |x| x.split(" ")[0].to_i }
    
    #app_from_cache value
    @app_from_cache = lines_app[2] - lines_app[1]   
    puts "App from cache #{@app_from_cache}\n"
    @win_from_cache = lines_app[3] - lines_app[2]   
    puts "Window from cache #{@win_from_cache}\n"
    # First line tells when the button is released
    @start_time = lines[0]
    puts "Started: #{lines[0]}"
    # Second one when the first pixel has changed its color
    @end_time = lines[1]
    puts "Pixel changed: #{lines[1]}"
    return @app_from_cache, @win_from_cache
  end
  
  
  def measure_time
    #Measuring the Startup Time for applications
    app_t = @end_time - @start_time
    return app_t
  end
  
  def test_performance
    wL = []
    list = []
    wLsum = 0
    app_cache_sum = 0
    win_cache_sum = 0 
    #Run Application with invoker
    for i in 1..COUNT
      print "Now Launching  #{@options[:application]} %d times\n" %i
      open_Apps(@options[:application])
      sleep (5)
      list.push(read_file(@options[:application]))
      wL.push(measure_time)
    end
    
    
    print "\n\nStartup time in milliseconds\n"
    print "Application: #{@options[:application]} \n"
    if @options[:limit] != nil
      print "Time limit: #{@options[:limit]} \n"
    end 
    
    #Printing the data
    for i in 0..COUNT-1
      print "%d \n" %[wL[i]]
      wLsum = wLsum + wL[i]
      app_cache_sum = app_cache_sum + list[i][0]
      win_cache_sum = win_cache_sum + list[i][1]
    end
    print "\nAverage: \n"
    print "%d\n" %[wLsum/COUNT]
    print "\nAverage: Application from cache \n"
    print "%d\n" %[app_cache_sum/COUNT]
    print "\nAverage: Window from cache \n"
    print "%d\n" %[win_cache_sum/COUNT]

    if @options[:limit] != nil
      assert((wLsum/COUNT) < @options[:limit], "Application: #{@options[:application]} avarage startup was slower than #{@options[:limit]} ms")
    end
    
  end
end



