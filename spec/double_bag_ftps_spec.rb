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

  it "prevents setting the FTPS mode while connected" do
    @ftp.connect(HOST)
    lambda {@ftp.ftps_mode = 'dummy value'}.should raise_error
  end

  it "prevents setting the FTPS mode to an unrecognized value" do
    lambda {@ftp.ftps_mode = 'dummy value'}.should raise_error
  end

end

describe DoubleBagFTPS do
  context "implicit" do
    before(:each) do
      @ftp = DoubleBagFTPS.new
      @ftp.ftps_mode = DoubleBagFTPS::FTPS_IMPLICIT
      @ftp.passive = true
      @ftp.ssl_context = DoubleBagFTPS.create_ssl_context(:verify_mode => OpenSSL::SSL::VERIFY_NONE)
    end

    after(:each) do
      @ftp.close unless @ftp.welcome.nil?
    end

    it_should_behave_like "DoubleBagFTPS"
  end

  context "explicit" do
    before(:each) do
    	@ftp = DoubleBagFTPS.new
    	@ftp.ftps_mode = DoubleBagFTPS::FTPS_EXPLICIT
      @ftp.passive = true
    	@ftp.ssl_context = DoubleBagFTPS.create_ssl_context(:verify_mode => OpenSSL::SSL::VERIFY_NONE)
    end

    after(:each) do
    	@ftp.close unless @ftp.welcome.nil?
    end

    it_should_behave_like "DoubleBagFTPS"
  end
end