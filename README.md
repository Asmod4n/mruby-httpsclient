# mruby-httpsclient

Prerequirements
===============
You need mruby-tls which needs libressl somewhere your compiler can find it, for example on OS X with homebrew you have to add something like this to build_config.rb
```ruby
  conf.gem github: 'Asmod4n/mruby-tls' do |g|
    g.cc.include_paths << '/usr/local/opt/libressl/include'
    g.linker.library_paths << '/usr/local/opt/libressl/lib'
  end
```

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
