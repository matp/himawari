#!/usr/bin/env ruby

require 'chunky_png'
require 'open-uri'
require 'json'
require 'time'

module Himawari
  class << self
    def download_image_to(filename, **options)
      download_image(**options).save(filename)
    end

    def download_image(quality: 1, size: 550, time: latest)
      chunks = chunks(quality: quality, size: size, time: time)

      # Compose output image.
      output = ChunkyPNG::Image.new(size * quality, size * quality)
      [*(0...quality)].product([*(0...quality)]).each do |x, y|
        output.compose!(chunks.next, x * size, y * size)
      end

      output
    end

    def chunks(quality: 1, size: 550, time: latest)
      unless [1, 2, 4, 8, 16, 20].include?(quality)
        raise ArgumentError, 'invalid quality'
      end

      # Download individual chunks.
      Enumerator.new do |yielder|
        [*(0...quality)].product([*(0...quality)]).map do |x, y|
          open_with_retry(URI.join(URL, "#{quality}d/", "#{size}/",
            "#{time.strftime('%Y/%m/%d/%H%M%S')}_#{x}_#{y}.png")) do |file|
            yielder << ChunkyPNG::Image.from_io(file)
          end
        end
      end
    end

    def latest
      open_with_retry(URI.join(URL, 'latest.json')) do |file|
        json = JSON.parse(file.read, symbolize_names: true)
        Time.parse(json[:date])
      end
    end

    private

      URL = 'http://himawari8-dl.nict.go.jp/himawari8/img/D531106/'

      def open_with_retry(target)
        open(target) {|file| yield file }
      rescue Net::OpenTimeout, Net::ReadTimeout
        retry
      end
  end
end

if __FILE__ == $0
  require 'optparse'
  require 'optparse/time'

  # Parse command line options.
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS...] [FILE]"

    opts.on('-q', '--quality QUALITY', Integer,
      'image quality (1,2,4,8,16,20), default: 1') do |quality|
      options[:quality] = quality
    end
    opts.on('-s', '--size SIZE', Integer,
      'image chunk size, default: 550') do |size|
      options[:size] = size
    end
    opts.on('-t', '--time TIME', Time,
      'image capture time, default: latest') do |time|
      options[:time] = time
    end
    opts.on_tail('-h', '--help', 'show this help message') do
      puts opts
      exit
    end
  end

  parser.parse!(ARGV)

  # Start image download.
  Himawari.download_image_to(ARGV.shift || 'output.png', **options)
end
