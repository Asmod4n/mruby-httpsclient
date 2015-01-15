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
    @tls_client.write("GET #{url.path} HTTP/1.1\r\nHost: #{url.host}\r\nConnection: Keep-Alive\r\n\r\n")
    buf = ""
    phr = Phr.new
    pret = nil
    loop do
      buf << @tls_client.read
      pret = phr.parse_response(buf)
      case pret
      when Fixnum
        break
      when :incomplete
        next
      when :parser_error
        @tls_client.close
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
        body << @tls_client.read
        b = body[size..-1]
        yield b
        size += b.bytesize
        yielded += size
        if size >= 1_048_576
          body = ""
          size = 0
        end
      end
    elsif headers.key?('Transfer-Encoding') && headers['Transfer-Encoding'].casecmp('chunked') == 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? 'Trailer'
        decoder.consume_trailer(true)
      end
      yielded = 0
      size = 0
      loop do
        pret = decoder.decode_chunked(body[size..-1]) do |body|
          yield body
        end
        case pret
        when Fixnum
          break
        when :incomplete
          size += body.bytesize
          yielded += size
          if size >= 1_048_576
            body = ""
            size = 0
          end
        when :parser_error
          @tls_client.close
          return pret
        end
        body << @tls_client.read
      end
    else
      yield body
      size = body.bytesize
      yielded = size
      loop do
        body << @tls_client.read
        b = body[size..-1]
        yield b
        size += b.bytesize
        yielded += size
        if size >= 1_048_576
          body = ""
          size = 0
        end
      end
    end

    @tls_client.close
    self
  end
end
