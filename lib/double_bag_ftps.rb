require 'net/ftp'
begin
  require 'openssl'
rescue LoadError
end

class DoubleBagFTPS < Net::FTP
  FTPS_EXPLICIT = :explicit
  FTPS_IMPLICIT = :implicit
  FTPS_IMPLICIT_PORT = 990

  # The form of FTPS that should be used. Either FTPS_EXPLICIT or FTPS_IMPLICIT.
  # Defaults to FTPS_EXPLICIT.
  attr_reader :ftps_mode

  # The OpenSSL::SSL::SSLContext to use for creating all OpenSSL::SSL::SSLSocket objects.
  attr_accessor :ssl_context

  def initialize(host = nil, user = nil, passwd = nil, acct = nil, ftps_mode = FTPS_EXPLICIT, ssl_context_params = {})
    raise ArgumentError unless valid_ftps_mode?(ftps_mode)
    @ftps_mode = ftps_mode
    @ssl_context = DoubleBagFTPS.create_ssl_context(ssl_context_params)
    super(host, user, passwd, acct)
  end

  def DoubleBagFTPS.open(host, user = nil, passwd = nil, acct = nil, ftps_mode = FTPS_EXPLICIT, ssl_context_params = {})
    if block_given?
      ftps = new(host, user, passwd, acct, ftps_mode, ssl_context_params)
      begin
        yield ftps
      ensure
        ftps.close
      end
    else
      new(host, user, passwd, acct, ftps_mode, ssl_context_params)
    end
  end

  #
  # Allow @ftps_mode to be set when @sock is not connected
  #
  def ftps_mode=(ftps_mode)
    if @sock.kind_of?(NullSocket) || @sock.closed?
      raise ArgumentError unless valid_ftps_mode?(ftps_mode)
      @ftps_mode = ftps_mode
    else
      raise 'Cannot set ftps_mode while connected'
    end
  end

  #
  # Establishes the command channel.
  # Override parent to record host name for verification, and allow default implicit port.
  #
  def connect(host, port = ftps_implicit? ? FTPS_IMPLICIT_PORT : FTP_PORT)
    @hostname = host
    super
  end

  def login(user = 'anonymous', passwd = nil, acct = nil, auth = 'TLS')
    if ftps_explicit?
      synchronize do
        sendcmd('AUTH ' + auth) # Set the security mechanism
        @sock = ssl_socket(@sock)
      end
    end
    
    super(user, passwd, acct)
    voidcmd('PBSZ 0') # The expected value for Protection Buffer Size (PBSZ) is 0 for TLS/SSL 
    voidcmd('PROT P') # Set data channel protection level to Private
  end

  #
  # Override parent to allow an OpenSSL::SSL::SSLSocket to be returned
  # when using implicit FTPS
  #
  def open_socket(host, port, defer_implicit_ssl = false)
    if defined? SOCKSSocket and ENV["SOCKS_SERVER"]
      @passive = true
      sock = SOCKSSocket.open(host, port)
    else
      sock = TCPSocket.open(host, port)
    end
    return (!defer_implicit_ssl && ftps_implicit?) ? ssl_socket(sock) : sock
  end
  private :open_socket

  #
  # Override parent to support ssl sockets
  #
  def transfercmd(cmd, rest_offset = nil)
    if @passive
      host, port = makepasv

      if @resume and rest_offset
        resp = sendcmd('REST ' + rest_offset.to_s)
        if resp[0] != ?3
          raise FTPReplyError, resp
        end
      end
      conn = open_socket(host, port, true)
      resp = sendcmd(cmd)
      # skip 2XX for some ftp servers
      resp = getresp if resp[0] == ?2
      if resp[0] != ?1
        raise FTPReplyError, resp
      end
      conn = ssl_socket(conn) # SSL connection now possible after cmd sent
    else
      sock = makeport
      if @resume and rest_offset
        resp = sendcmd('REST ' + rest_offset.to_s)
        if resp[0] != ?3
          raise FTPReplyError, resp
        end
      end
      resp = sendcmd(cmd)
      # skip 2XX for some ftp servers
      resp = getresp if resp[0] == ?2
      if resp[0] != ?1
        raise FTPReplyError, resp
      end

      temp_ssl_sock = ssl_socket(sock)
      conn = temp_ssl_sock.accept
      temp_ssl_sock.close
    end
    return conn
  end
  private :transfercmd

  def ftps_explicit?; @ftps_mode == FTPS_EXPLICIT end
  def ftps_implicit?; @ftps_mode == FTPS_IMPLICIT end

  def valid_ftps_mode?(mode)
    mode == FTPS_EXPLICIT || mode == FTPS_IMPLICIT
  end
  private :valid_ftps_mode?

  #
  # Returns a connected OpenSSL::SSL::SSLSocket
  #
  def ssl_socket(sock)
    raise 'SSL extension not installed' unless defined?(OpenSSL)
    sock = OpenSSL::SSL::SSLSocket.new(sock, @ssl_context)
    sock.sync_close = true
    sock.connect
    print "get: #{sock.peer_cert.to_text}" if @debug_mode
    unless @ssl_context.verify_mode == OpenSSL::SSL::VERIFY_NONE
      sock.post_connection_check(@hostname)
    end
    return sock
  end
  private :ssl_socket

  def DoubleBagFTPS.create_ssl_context(params = {})
    raise 'SSL extension not installed' unless defined?(OpenSSL)
    context = OpenSSL::SSL::SSLContext.new
    context.set_params(params)
    return context
  end
  
end
