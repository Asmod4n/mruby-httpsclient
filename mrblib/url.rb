class URL
  HTTPS_SCHEME = 'https://'
  HTTPS_PORT = '443'
  BRACKET_OPEN = '['.ord
  BRACKET_CLOSE = ']'.ord
  SLASH = '/'
  SLASH_BYTE = SLASH.ord
  COLON = ':'
  COLON_BYTE = COLON.ord

  attr_reader :host, :port, :path

  def self.parse(url)
    url = String(url)
    instance = new
    cur_pos = 0
    url_len = url.bytesize

    if url.start_with?(HTTPS_SCHEME)
      instance.instance_variable_set(:@port, HTTPS_PORT)
      cur_pos += HTTPS_SCHEME.bytesize
    else
      raise "Not a https URL"
    end

    if cur_pos == url_len
      raise "Host missing"
    end

    if url[cur_pos] == BRACKET_OPEN
      cur_pos += 1
      if ((idx = url.index(BRACKET_CLOSE, cur_pos)) == nil)
        raise "Invalid IPv6 Address"
      else
        instance.instance_variable_set(:@host, url[cur_pos, idx - cur_pos])
        cur_pos = idx + 1
      end
    else
      token_pos = cur_pos
      url[cur_pos, url_len - cur_pos].bytes.each do |token|
        if token == SLASH_BYTE || token == COLON_BYTE
          break
        end
        token_pos += 1
      end
      instance.instance_variable_set(:@host, url[cur_pos, token_pos - cur_pos])
      cur_pos = token_pos

      if cur_pos == url_len
        instance.instance_variable_set(:@path, SLASH)
        return instance
      end
    end

    if url[cur_pos] == COLON
      cur_pos += 1
      if((idx = url.index(SLASH, cur_pos)) == nil)
        port = url[cur_pos, url_len - cur_pos]
        if Integer(port) >= 65536
          raise "Port too large"
        end
        instance.instance_variable_set(:@port, port)
        instance.instance_variable_set(:@path, SLASH)
        return instance
      else
        port = url[cur_pos, idx - cur_pos]
        if Integer(port) >= 65536
          raise "Port too large"
        end
        instance.instance_variable_set(:@port, port)
        cur_pos = idx
      end
    end

    instance.instance_variable_set(:@path, url[cur_pos, url_len - cur_pos])
    instance
  end
end
