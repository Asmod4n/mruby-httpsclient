Tls.init

class HttpsClient
  def initialize(options = {})
    @tls_config = options.fetch(:tls_config) do
      Tls::Config.new
    end
    @tls_client = options.fetch(:tls_client) do
      Tls::Client.new @tls_config
    end
  end

  def get(url)
    url = URL.parse(url)
    @tls_client.connect(url.host, String(url.port))
    request = "GET #{url.path} HTTP/1.1\r\nHost: #{url.host}\r\nConnection: Keep-Alive\r\n\r\n"
    written = @tls_client.write(request)
    until written == request.bytesize
      written += @tls_client.write(request)
    end
    buf = ""
    phr = Phr.new
    rret = nil
    pret = nil
    loop do
      rret = @tls_client.read buf
      pret = phr.parse_response(buf)
      case pret
      when Fixnum
        break
      when :incomplete
        next
      when :parser_error
        return pret
      end
    end
    body = buf[pret..-1]
    headers = phr.headers.to_h

    if headers.key? 'Content-Length'
      cl = Integer(headers['Content-Length'])
      yield body
      size = body.bytesize
      yielded = size
      until yielded == cl
        rret = @tls_client.read body
        yield body[size..-1]
        size += rret
        yielded += size
        if size > 1_048_576
          body = ""
          size = 0
        end
      end
    elsif headers.key?('Transfer-Encoding') && headers['Transfer-Encoding'].casecmp('chunked') == 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? 'Trailer'
        decoder.consume_trailer(true)
      end
      offset = 0
      loop do
        case decoder.decode_chunked(body)
        when Fixnum
          b = body[offset..-1]
          yield b if b.bytesize > 0
          break
        when :incomplete
          b = body[offset..-1]
          yield b if b.bytesize > 0
          offset += b.bytesize
        when :parser_error
          return :parser_error
        end
        rret = @tls_client.read body
      end
    else
      yield body
      size = body.bytesize
      yielded = size
      loop do
        rret = @tls_client.read body
        yield body[size..-1]
        size += rret
        yielded += size
        if size > 1_048_576
          body = ""
          size = 0
        end
      end
    end

    @tls_client.close
    self
  end
end
