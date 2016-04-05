require 'json'
require 'digest/sha1'

module Gif
  class CLI
    def search(tags)
      fetch_url = "https://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=#{tags}"
      raw = `curl '#{fetch_url}'`
      gif_json = JSON.parse(raw)
      gif_url = gif_json["data"]["image_original_url"]
      gif_sha = Digest::SHA1.hexdigest(gif_url)

      `curl -o #{gif_sha}.gif #{gif_url}`
      `convert #{gif_sha}.gif frames.jpg`

      width = `tput cols`.to_i / 3
      frames = `ls -1 *.jpg | wc -l`.to_i
      frames.times do |n|
        system "imgcat --width #{width} frames-#{n}.jpg"
        `rm frames-#{n}.jpg`
        system "⌘ k"
      end

      `rm #{gif_sha}.gif`
    end
  end
end
