# mruby-httpsclient

Example
======

Simple GET

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

Simple POST

```ruby
body = "hello world"
HttpsClient.new.post("https://github.com", body) do |response|
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

POST a Enumerable
```ruby
body = ["hello", "world"]
HttpsClient.new.post("https://github.com", body) do |response|
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

POST a Fiber
```ruby
body = Fiber.new do
  Fiber.yield "hello"
  Fiber.yield "world"
end
HttpsClient.new.post("https://github.com", body) do |response|
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

The response body is always streamed, if you need to work with the complete body at once you have to stitch it together.
