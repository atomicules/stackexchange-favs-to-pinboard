#StackExchange Favs to Pinboard
require 'open-uri'
require 'json'
require 'optparse'
require 'cgi'
require 'logger'


optparse = OptionParser.new do |opts|
	opts.on('-i', '--id ID', "Stackexchange ID") { |i| StackID = i }
	opts.on('-u', '--user USER', "Pinboard username") { |u| User = u }
	opts.on('-t', '--token TOKEN', "Pinboard API Token") { |t| Token = t }
end
optparse.parse!


def get_sites(id)
	response = open("https://api.stackexchange.com/2.2/users/#{id}/associated")
	parsed = parse(response.read)
end


def parse(response_string)
	#Seems like Ruby automatically handles gzip compression now. No need to decompress.
	parsed = JSON.parse(response_string)
end


def get_favs(site, id)
	puts "Fetching favs for #{site}"
	has_more = true
	items = []
	page = 1
	while has_more
		response = open("https://api.stackexchange.com/2.2/users/#{id}/favorites?order=desc&sort=added&pageSize=100&page=#{page}&site=#{site}")
		#Use response.read not .string as some returns are large enough to go to a temp file
		parsed = parse(response.read)
		items += parsed["items"]
		has_more = parsed["has_more"]
		page += 1
	end
	puts "#{items.length} favs"
	items
end


class Pinboard
	@@logger = Logger.new(STDOUT)
	@@logger.level = Logger::INFO
	@@rate_limit = 3
	Api_url = "https://api.pinboard.in/v1/"


	def initialize(user, token)
		@user = user
		@token = token
	end


	def add(url, description, extended=nil, tags=nil, replace="no")
		attempts = 1
		posted = false
		#At minimum must have url and description
		array_parameters = "&url=#{CGI.escape(url)}&description=#{CGI.escape(description)}"
		#Could loop through the below
		unless extended.nil?
			array_parameters += "&extended=#{CGI.escape(extended)}"
		end
		unless tags.nil?
			#TODO: Need to check whether tags_escaped will work
			array_parameters += "&tags=#{CGI.escape(tags)}"
		end
		until (@@rate_limit > 60) | (attempts > 3) | posted 
			response = open("#{Api_url}posts/add?auth_token=#{@user}:#{@token}"+array_parameters+"&replace=#{replace}&format=json")
			@@logger.debug(response.string)
			@@logger.debug(response.status)
			response_json = JSON.parse(response.string)
			if (response.status[0] == "200") & (response_json["result_code"] == "done")
				@@logger.info("Added #{url}")
				posted = true
			elsif (response.status[0] == "200") & (response_json["result_code"] == "item already exists")
				@@logger.info("Skipping #{url}, already exists")
				posted = true
			elsif response.status[0] == "429"
				# 429 Too Many Requests, increase rate limit
				@@rate_limit *= 2
				@@logger.warn("Rate Limit increased to #{$rate_limit} seconds")
			end
			attempts += 1
			#Rate limit as per Pinboard API requirements
			sleep @@rate_limit
		end
		if @@rate_limit > 60
			@@logger.error("Rate limit has exceeded 60 secs, let's try again another time")
		elsif attempts > 3
			@@logger.error("Failed 3 times to save #{url}, bombing out")
		end
		posted
	end
end


if defined?(StackID) and defined?(User) and defined?(Token)
	cache_file = ENV["HOME"]+"/.stackexchange_favs_to_pinboard"
	pb = Pinboard.new(User, Token)
	if File.exists?(cache_file)
		cache = JSON.parse(File.read(cache_file))
	else
		cache = {}
	end
	parsed = get_sites(StackID)
	parsed["items"].each do |site|
		favs = get_favs(site["site_url"].sub("http://", "").sub("https://", "").sub(".stackexchange", "").sub(".com", ""), site["user_id"])
		#Don't make more than 30 requests per second
		sleep (1.0/30)
		favs.each do |fav|
			title = fav["title"]
			tags = fav["tags"]
			link = fav["link"]
			#Check cache to see if already added to pinboard
			unless cache.has_key?(link)
				#Need to unescape so can re-escape in Pinboard code
				#Still want no default replace, just in case cache doesn't exist
				pb.add(link, CGI.unescape_html(title), nil, tags.join(", ")+", stackexchangefavs", "no")
				#Add to cache. Should check for success really
				cache[link] = true
			end
		end
	end
	#Write out cache
	File.open(cache_file, "w") do |file|
		file << cache.to_json
	end
end
