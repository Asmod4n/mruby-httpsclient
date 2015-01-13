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
    pret = nil
    loop do
      @tls_client.read buf
      pret = phr.parse_response(buf)
      break if pret.is_a?(Fixnum)
      next if pret == :incomplete
      return pret if pret == :parser_error
    end
    body = buf[pret..-1]
    headers = phr.headers.to_h

    if headers.key? 'Content-Length'
      cl = Integer(headers['Content-Length'])
      offset = 0
      loop do
        yield body[offset..-1]
        break if body.bytesize == cl
        @tls_client.read body
        offset += body.bytesize
      end
    elsif headers.key?('Transfer-Encoding') && headers['Transfer-Encoding'].casecmp('chunked') == 0
      offset = 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? 'Trailer'
        decoder.consume_trailer(true)
      end
      loop do
        case decoder.decode_chunked(body)
        when Fixnum
          yield body[offset..-1]
          break
        when :incomplete
          yield body[offset..-1]
          offset += body.bytesize
        when :parser_error
          return :parser_error
        end
        @tls_client.read body
      end
    else
      yield body
      loop do
        body = ""
        @tls_client.read body
        yield body
      end
    end

    @tls_client.close
  rescue Tls::Error
  end
end
