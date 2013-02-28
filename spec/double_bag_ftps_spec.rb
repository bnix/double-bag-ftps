require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

shared_examples_for "DoubleBagFTPS" do
  it "connects to a remote host" do
    lambda {@ftp.connect(HOST)}.should_not raise_error
  end

  it "logs in with a user name and password" do
    @ftp.connect(HOST)
    lambda {@ftp.login(USR, PASSWD)}.should_not raise_error
  end

  it "can open a secure data channel" do
    @ftp.connect(HOST)
    @ftp.login(USR, PASSWD)
    @ftp.send(:transfercmd, 'nlst').should be_an_instance_of OpenSSL::SSL::SSLSocket
  end

  it "can retrieve a file" do
    Dir.mktmpdir do |temp_dir|
      @ftp.connect HOST
      @ftp.login USR, PASSWD
      filename = @ftp.nlst.first
      filename.should_not be_nil
      local_path = File.join(temp_dir, filename)
      @ftp.get(filename, local_path)
      File.exists?(local_path).should be_true
    end
  end

  it "prevents setting the FTPS mode while connected" do
    @ftp.connect(HOST)
    lambda {@ftp.ftps_mode = DoubleBagFTPS::IMPLICIT}.should raise_error RuntimeError
  end

  it "prevents setting the FTPS mode to an unrecognized value" do
    lambda {@ftp.ftps_mode = 'dummy value'}.should raise_error ArgumentError
  end

end

describe DoubleBagFTPS do
  context "implicit" do
    before(:each) do
      @ftp = DoubleBagFTPS.new
      @ftp.ftps_mode = DoubleBagFTPS::IMPLICIT
      @ftp.passive = true
      @ftp.ssl_context = DoubleBagFTPS.create_ssl_context(:verify_mode => OpenSSL::SSL::VERIFY_NONE)
    end

    after(:each) do
      @ftp.close unless @ftp.welcome.nil?
    end

    it "uses an SSLSocket when first connected" do
      @ftp.connect(HOST)
      @ftp.instance_eval {def socket; @sock; end}
      @ftp.socket.should be_an_instance_of OpenSSL::SSL::SSLSocket
    end

    it_should_behave_like "DoubleBagFTPS"
  end

  context "explicit" do
    before(:each) do
      @ftp = DoubleBagFTPS.new
      @ftp.ftps_mode = DoubleBagFTPS::EXPLICIT
      @ftp.passive = true
      @ftp.ssl_context = DoubleBagFTPS.create_ssl_context(:verify_mode => OpenSSL::SSL::VERIFY_NONE)
    end

    after(:each) do
      @ftp.close unless @ftp.welcome.nil?
    end

    it "does not use an SSLSocket when first connected" do
      @ftp.connect(HOST)
      @ftp.instance_eval {def socket; @sock; end}
      @ftp.socket.should_not be_an_instance_of OpenSSL::SSL::SSLSocket
    end

    it_should_behave_like "DoubleBagFTPS"
  end
end
