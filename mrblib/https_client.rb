Tls.init

class HttpsClient
  GET = 'GET '
  HTTP_1_1 = ' HTTP/1.1'
  CRLF = "\r\n"
  HOST = 'Host: '
  CON_KA = 'Connection: Keep-Alive'
  KV_DELI = ': '
  CONTENT_LENGTH = 'Content-Length'
  CONTENT_LENGTH_D = CONTENT_LENGTH.downcase
  TRANSFER_ENCODING = 'Transfer-Encoding'
  TRANSFER_ENCODING_D = TRANSFER_ENCODING.downcase
  CHUNKED = 'chunked'
  TRAILER = 'Trailer'
  TRAILER_D = TRAILER.downcase
  HEAD = 'HEAD '
  POST = 'POST '
  FINAL_CHUNK = "0#{CRLF}#{CRLF}"

  Response = Struct.new(:minor_version, :status, :msg, :headers, :body)

  def initialize(options = {})
    @tls_config = options.fetch(:tls_config) do
      Tls::Config.new
    end
    @tls_client = options.fetch(:tls_client) do
      Tls::Client.new @tls_config
    end
  end

  def get(url, headers = nil)
    url = URL.parse(url)
    unless url.is_a? URL
      return url
    end
    buf = nil
    if headers
      buf = "#{GET}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}"
      headers.each do |kv|
        buf << "#{kv[0]}#{KV_DELI}#{kv[1]}#{CRLF}"
      end
      buf << CRLF
    else
      buf = "#{GET}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}#{CRLF}"
    end
    @tls_client.connect(url.host, String(url.port))
    @tls_client.write(buf)
    buf = @tls_client.read
    phr = Phr.new
    pret = nil
    response = nil
    loop do
      pret = phr.parse_response(buf)
      case pret
      when Fixnum
        response = Response.new(phr.minor_version,
          phr.status, phr.msg, phr.headers)
        yield response
        break
      when :parser_error
        @tls_client.close
        return pret
      end
      buf << @tls_client.read
    end
    response.body = String(buf[pret..-1])
    headers = phr.headers.to_h

    if headers.key? CONTENT_LENGTH_D
      cl = Integer(headers[CONTENT_LENGTH_D])
      yield response
      yielded = response.body.bytesize
      until yielded == cl
        response.body = @tls_client.read(65_536)
        yield response
        yielded += response.body.bytesize
      end
    elsif headers.key?(TRANSFER_ENCODING_D) && headers[TRANSFER_ENCODING_D].casecmp(CHUNKED) == 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? TRAILER_D
        decoder.consume_trailer(true)
      end
      loop do
        pret = decoder.decode_chunked(response.body) do |body|
          response.body = body
          yield response
        end
        case pret
        when Fixnum
          break
        when :parser_error
          @tls_client.close
          return pret
        end
        response.body = @tls_client.read(65_536)
      end
    else
      yield response
      loop do
        response.body = @tls_client.read(65_536)
        yield response
      end
    end

    @tls_client.close
    self
  end

  def head(url, headers = nil)
    url = URL.parse(url)
    unless url.is_a? URL
      return url
    end
    buf = nil
    if headers
      buf = "#{HEAD}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}"
      headers.each do |kv|
        buf << "#{kv[0]}#{KV_DELI}#{kv[1]}#{CRLF}"
      end
      buf << CRLF
    else
      buf = "#{HEAD}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}#{CRLF}"
    end
    @tls_client.connect(url.host, String(url.port))
    @tls_client.write(buf)
    buf = @tls_client.read
    phr = Phr.new
    loop do
      pret = phr.parse_response(buf)
      case pret
      when Fixnum
        yield Response.new(phr.minor_version,
          phr.status, phr.msg, phr.headers)
        break
      when :parser_error
        @tls_client.close
        return pret
      end
      buf << @tls_client.read
    end

    @tls_client.close
    self
  end

  def post(url, body, headers = nil)
    url = URL.parse(url)
    unless url.is_a? URL
      return url
    end

    buf = nil
    if headers
      buf = "#{POST}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}"
      headers.each do |kv|
        buf << "#{kv[0]}#{KV_DELI}#{kv[1]}#{CRLF}"
      end
    else
      buf = "#{POST}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}"
    end

    case body
    when String
      buf << "#{CONTENT_LENGTH}#{KV_DELI}#{body.bytesize}#{CRLF}#{CRLF}"
      @tls_client.connect(url.host, String(url.port))
      @tls_client.write(buf)
      @tls_client.write(body)
    when Array
      buf << "#{TRANSFER_ENCODING}#{KV_DELI}#{CHUNKED}#{CRLF}#{CRLF}"
      @tls_client.connect(url.host, String(url.port))
      @tls_client.write(buf)
      body.each do |chunk|
        ch = String(chunk)
        next if ch.bytesize == 0
        @tls_client.write("#{ch.bytesize.to_s(16)}#{CRLF}#{ch}#{CRLF}")
      end
      @tls_client.write(FINAL_CHUNK)
    when Fiber
      buf << "#{TRANSFER_ENCODING}#{KV_DELI}#{CHUNKED}#{CRLF}#{CRLF}"
      @tls_client.connect(url.host, String(url.port))
      @tls_client.write(buf)
      while body.alive? && chunk = body.resume
        ch = String(chunk)
        next if ch.bytesize == 0
        @tls_client.write("#{ch.bytesize.to_s(16)}#{CRLF}#{ch}#{CRLF}")
      end
      @tls_client.write(FINAL_CHUNK)
    else
      raise ArgumentError, "Cannot handle #{body.class}"
    end

    buf = @tls_client.read
    phr = Phr.new
    pret = nil
    response = nil
    loop do
      pret = phr.parse_response(buf)
      case pret
      when Fixnum
        response = Response.new(phr.minor_version,
          phr.status, phr.msg, phr.headers)
        yield response
        break
      when :parser_error
        @tls_client.close
        return pret
      end
      buf << @tls_client.read
    end
    response.body = String(buf[pret..-1])
    headers = phr.headers.to_h

    if headers.key? CONTENT_LENGTH_D
      cl = Integer(headers[CONTENT_LENGTH_D])
      yield response
      yielded = response.body.bytesize
      until yielded == cl
        response.body = @tls_client.read(65_536)
        yield response
        yielded += response.body.bytesize
      end
    elsif headers.key?(TRANSFER_ENCODING_D) && headers[TRANSFER_ENCODING_D].casecmp(CHUNKED) == 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? TRAILER_D
        decoder.consume_trailer(true)
      end
      loop do
        pret = decoder.decode_chunked(response.body) do |body|
          response.body = body
          yield response
        end
        case pret
        when Fixnum
          break
        when :parser_error
          @tls_client.close
          return pret
        end
        response.body = @tls_client.read(65_536)
      end
    else
      yield response
      loop do
        response.body = @tls_client.read(65_536)
        yield response
      end
    end

    @tls_client.close
    self
  end
end
