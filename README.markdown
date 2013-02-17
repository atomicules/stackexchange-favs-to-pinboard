#StackExchange Favourites to Pinboard

Import all your StackExchange site (Stackoverflow, Super User, Cross Validated, etc) favourites to Pinboard. Because amazingly no-one else seems to have done this. And yes, this is how I write Ruby code, tabs as well - if you think this is bad style you should see my Haskell.

##To Use

Run `ruby /path/to/stackexchange-favs-to-pinboard.rb -i StackExchangeID -t PinboardAPIToken` 

You can get your Pinboard API token on your password tab of the settings page. Your StackExchange ID, is what you get when logged in to stackexchange.com itself - this is probably different from your Stackoverflow ID, etc.

Since it does not overwrite existing bookmarks you can safely run it every so often to bring in new ones. 

##Requirements

Nowt beyond Ruby. I am aware there are Gems for StackExchange, but most of them seem to assume you are targeting just one site (Stackoverflow), not any/all StackExchange sites you may use. There is also at least one really good Gem for Pinboard, but it just seemed overkill for the one API function I wanted to use, plus I don't think it rate limits.
