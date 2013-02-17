#StackExchange Favs to Pinboard
require 'open-uri'
require 'json'
require 'optparse'
require 'cgi'

optparse = OptionParser.new do |opts|
	opts.on('-i', '--id ID', "Stackexchange ID") { |i| StackID = i }
	opts.on('-t', '--token TOKEN', "Pinboard API Token") { |t| Token = t }
end
optparse.parse!

def get_sites(id)
	response = open("https://api.stackexchange.com/2.1/users/#{id}/associated")
	parsed = parse(response)
end

def parse(response) 
	#From: Garth, http://stackoverflow.com/a/1366187/208793
	gz = Zlib::GzipReader.new(StringIO.new(response.string))
	parsed = JSON.parse(gz.read)
end

def get_favs(site, id)
	response = open("https://api.stackexchange.com/2.1/users/#{id}/favorites?order=desc&sort=activity&site=#{site}")
	parsed = parse(response)
end

def pinboard_add(auth_token, url, description, replace, tags)
	attempts = 1
	posted = false
	until ($rate_limit > 60) | (attempts > 3) | posted 
		response = open(URI.encode("https://api.pinboard.in/v1/posts/add?auth_token=#{auth_token}&url=#{url}&description=#{description}&replace=#{replace}&tags=#{tags}").gsub("'", "%27"))
		#Bit of a hacky kludge. For some reason URI.encode doesn't catch apostrophes.
		if (response.status[0] == "200") & response.string.include?("done")
			puts "Added #{url}"
			posted = true
		elsif (response.status[0] == "200") & response.string.include?("exists")
			puts "Skipping #{url}, already exists"
			posted = true
		elsif response.status[0] == "429"
			# 429 Too Many Requests, increase rate limit
			$rate_limit *= 2
			puts "Rate Limit increased to #{$rate_limit} seconds"
		end
		attempts += 1
		#Rate limit as per Pinboard API requirements
		sleep $rate_limit
	end
	if $rate_limit > 60
		puts "Rate limit has exceeded 60 secs, let's try again another time"
		quit
	elsif attempts > 3
		puts "Failed 3 times to save #{url}, bombing out"
		quit
	end
end

if defined?(StackID) and defined?(Token)
	$rate_limit = 3
	parsed = get_sites(StackID)
	parsed["items"].each do |site|
		favs = get_favs(site["site_url"].sub("http://", "").sub(".stackexchange", "").sub(".com", ""), site["user_id"])
		favs["items"].each do |fav|
			title = fav["title"]
			tags = fav["tags"]
			link = fav["link"]
			pinboard_add(Token, link, CGI.unescape_html(title), "no", tags.join(", ")+", stackexchangefavs")
			#Need to unescape so can URI encode
		end
	end
end
