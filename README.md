# mruby-httpsclient

Example
======

```ruby
client = HttpsClient.new
client.get("https://www.google.com/") do |response|
  puts response.minor_version
  puts response.status
  puts response.msg
  puts response.headers
  puts response.body
  break
end
```

The response body is always streamed, if you need to work with the complete body at once you have to stich is together yourself.
