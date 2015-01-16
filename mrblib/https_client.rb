Tls.init

class HttpsClient
  GET = 'GET '
  HTTP_1_1 = ' HTTP/1.1'
  CRLF = "\r\n"
  HOST = 'Host: '
  CON_KA = 'Connection: Keep-Alive'
  CONTENT_LENGTH = 'content-length'
  TRANSFER_ENCODING = 'transfer-encoding'
  CHUNKED = 'chunked'
  TRAILER = 'trailer'

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
      return :malformed_url
    end
    @tls_client.connect(url.host, String(url.port))
    if headers
      buf = "#{GET}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}"
      headers.each do |kv|
        buf << "#{kv[0]}: #{kv[1]}#{CRLF}"
      end
      buf << CRLF
      @tls_client.write buf
    else
      @tls_client.write("#{GET}#{url.path}#{HTTP_1_1}#{CRLF}#{HOST}#{url.host}#{CRLF}#{CON_KA}#{CRLF}#{CRLF}")
    end
    buf = @tls_client.read
    phr = Phr.new
    pret = nil
    loop do
      pret = phr.parse_response(buf)
      case pret
      when Fixnum
        break
      when :parser_error
        @tls_client.close
        return pret
      end
      buf << @tls_client.read
    end
    body = buf[pret..-1]
    headers = phr.headers.to_h

    if headers.key? CONTENT_LENGTH
      cl = Integer(headers[CONTENT_LENGTH])
      yield body
      yielded = body.bytesize
      until yielded == cl
        body = @tls_client.read(65_536)
        yield body
        yielded += body.bytesize
      end
    elsif headers.key?(TRANSFER_ENCODING) && headers[TRANSFER_ENCODING].casecmp(CHUNKED) == 0
      decoder = Phr::ChunkedDecoder.new
      unless headers.key? TRAILER
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
        body = @tls_client.read(65_536)
      end
    else
      yield body
      loop do
        yield @tls_client.read(65_536)
      end
    end

    @tls_client.close
    self
  end
end
