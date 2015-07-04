# mruby-httpsclient

Example
======

```ruby
HttpsClient.new.get("https://github.com/") do |response|
  unless response.body
    puts response.minor_version
    puts response.status
    puts response.msg
    puts response.headers
  else
    print response.body
  end
end
```

The response body is always streamed, if you need to work with the complete body at once you have to stitch is together.
