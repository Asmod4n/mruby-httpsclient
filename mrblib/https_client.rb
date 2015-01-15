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
      yielded = body.bytesize
      until yielded == cl
        body = @tls_client.read(1_048_576)
        yield body
        yielded += body.bytesize
      end
    elsif headers.key?('Transfer-Encoding') && headers['Transfer-Encoding'].casecmp('chunked') == 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? 'Trailer'
        decoder.consume_trailer(true)
      end
      loop do
        pret = decoder.decode_chunked(body) do |body|
          yield body
        end
        case pret
        when Fixnum
          break
        when :parser_error
          @tls_client.close
          return pret
        end
        body = @tls_client.read(1_048_576)
      end
    else
      yield body
      loop do
        yield @tls_client.read(1_048_576)
      end
    end

    @tls_client.close
    self
  end
end
