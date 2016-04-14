require 'json'
require 'tmpdir'
require 'digest/sha1'

module Gif
  class CLI
    def initialize tags, loops, modern
      @tags = tags
      @loops = loops.to_i
      ENV["MODERN_TERMINAL"] = "true" if modern
      @modern = ENV["MODERN_TERMINAL"] if ENV["MODERN_TERMINAL"] == "true"
    end

    def fetch
      Dir.mktmpdir do |tmp|
        Dir.chdir(tmp)
        generate_url
        generate_gifs
      end
    end

    private

    def generate_url
      fetch_url     = "https://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=#{@tags}"
      gif_json      = JSON.parse `curl -s '#{fetch_url}'`
      original_url = gif_json["data"]["image_original_url"]
      fixed_height_url = gif_json["data"]["fixed_height_small_url"]
      @modern ? @gif_url = original_url : @gif_url = fixed_height_url
      @gif_sha      = Digest::SHA1.hexdigest @gif_url
      @resized_sha  = Digest::SHA1.hexdigest @gif_sha
    end

    def create_images
      width  = `tput cols`
      height = `tput lines`
      wh     = [width, "x", height].join.gsub /\n/,""
      suppress_output do
        `gifsicle --colors=256 #{@gif_sha}.gif -o #{@gif_sha}.gif")`
      end
      system "gifsicle --resize-fit #{wh} --unoptimize #{@gif_sha}.gif -o #{@resized_sha}"
      system "gifsicle --explode #{@resized_sha} -o frames.jpg"
    end

    def rename_files
      filenames = Dir.glob "*.jpg.*"
      filenames.each_with_index do |filename, i|
        File.rename filename, "frames-" + i.to_s
      end
    end

    def gif_to_terminal
      frames = `ls -1 frames-* | wc -l`.to_i
      frames.times do |n|
        system "/usr/local/Cellar/imgcat/1.1.0/bin/imgcat -R frames-#{n}"
        sleep 1.0/24
        system "⌘ k"
      end
      @loops -= 1
    end

    def gif_to_modern_terminal
      width  = `tput cols`.to_i
      height = `tput lines`.to_i
      system "imgcat -w #{width} -h #{height} #{@gif_sha}.gif"
    end

    def generate_gifs
      system "curl -s -o #{@gif_sha}.gif #{@gif_url}"
      if @modern
        gif_to_modern_terminal
      else
        create_images
        rename_files
        @loops.times { gif_to_terminal }
      end
    end

    def suppress_output
      begin
        original_stderr = $stderr.clone
        original_stdout = $stdout.clone
        $stderr.reopen(File.new("/dev/null", "w"))
        $stdout.reopen(File.new("/dev/null", "w"))
        retval = yield
      rescue Exception => e
        $stdout.reopen(original_stdout)
        $stderr.reopen(original_stderr)
        raise e
      ensure
        $stdout.reopen(original_stdout)
        $stderr.reopen(original_stderr)
      end
      retval
    end
  end
end
