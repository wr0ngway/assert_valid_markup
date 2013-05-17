require 'test/unit'
require 'net/http'
require 'digest/md5'
require 'open-uri'
require 'fileutils'
require 'tempfile'
require 'json'
require 'cgi'

class Test::Unit::TestCase

  @@default_avm_options = {
      :catalog_path => File.expand_path("~/.xml-catalogs"),
      :validation_service => system("xmllint --version > /dev/null 2>&1") ? :local : :w3c,
      :dtd_validate => true
  }

  # Assert that markup (html/xhtml) is valid according the W3C validator web service.
  # By default, it validates the contents of @response.body, which is set after calling
  # one of the get/post/etc helper methods. You can also pass it a string to be validated.
  # Validation errors, if any, will be included in the output. The response from the validator
  # service will be cached in the system temp directory to minimize duplicate calls.
  #
  # For example, if you have a FooController with an action Bar, put this in foo_controller_test.rb:
  #
  #   def test_bar_valid_markup
  #     get :bar
  #     assert_valid_markup
  #   end
  #
  # To use a local w3c-validator instance set following environment varibale as following:
  # ENV['W3C_VALIDATOR_SERVICE']='my-local.server/w3c-validator'
  #
  def assert_valid_markup(fragment=@response.body, options={})
    opts = @@default_avm_options.merge(options)

    # html5 validation is a special case
    opts[:validation_service] = :w3c if fragment =~ /\A\s*<!DOCTYPE html>/

    result = ''
    if opts[:validation_service] == :local
      result = local_validate(fragment, opts[:dtd_validate], opts[:catalog_path])
    else
      result = w3c_validate(fragment, opts[:dtd_validate])
    end
    assert result.empty?, result
  end
  
  # Class-level method to quickly create validation tests for a bunch of actions at once.
  # For example, if you have a FooController with three actions, just add one line to foo_controller_test.rb:
  #
  #   assert_valid_markup :bar, :baz, :qux
  #
  # If you pass :but_first => :something, #something will be called at the beginning of each test case
  def self.assert_valid_markup(*actions)
    options = actions.find { |i| i.kind_of? Hash }
    actions.delete_if { |i| i.kind_of? Hash }
    actions.each do |action|
      toeval = "def test_#{action}_valid_markup\n"
      toeval << "#{options[:but_first].id2name}\n" if options and options[:but_first]
      toeval << "get :#{action}\n"
      toeval << "assert_valid_markup\n"
      toeval << "end\n"
      class_eval toeval
    end
  end

  # Class-level method to to turn on validation for the response from any successful html request via "get"
  def self.assert_all_valid_markup(options={})
    opts = @@default_avm_options.merge(options)
    self.class_eval do
      # automatically check markup for all successfull GETs
      define_method(:get_with_assert_valid_markup) do |*args|
        get_without_assert_valid_markup(*args)
        assert_valid_markup(@response.body, opts) if ! @@skip_validation && @request.format.html? && @response.success?
      end
      alias_method_chain :get, :assert_valid_markup
    end
  end

  @@skip_validation = false

  # Allows one to skip validation for the given block - useful when you use assert_all_valid_markup and need to only
  # skip validation for a handful of tests
  def skip_markup_validation
    begin
      @@skip_validation = true
      yield
    ensure
      @@skip_validation = false
    end
  end
  
  def local_validate(xmldata, dtd_validate, catalog_path)
    catalog_file = "#{catalog_path}/catalog"
    if ! File.exists? catalog_path
      puts "Creating xml catalog at: #{catalog_path}"
      FileUtils.mkdir_p(catalog_path)
      out = `xmlcatalog --noout --create '#{catalog_file}' 2>&1`
      if $? != 0
        puts out
        exit 1
      end
    end
    
    ENV["XML_DEBUG_CATALOG"] = ""
    ENV["SGML_CATALOG_FILES"] = catalog_file
    tmpfile = Tempfile.new('xmllint')
    tmpfile.write(xmldata)
    tmpfile.close
    validation_output = `xmllint --catalogs --memory --noout #{dtd_validate ? '--valid' : ''} #{tmpfile.path} 2>&1`.lines.to_a
    ENV.delete("XML_DEBUG_CATALOG")

    added_to_catalog = false
    last_sysid = ""
    validation_output.each do |line|
      line.chomp!
      if match = line.match(/Resolve: pubID (.*) sysID (.*)/)
        pubid = match[1]
        sysid = match[2]
        localdtd = "#{catalog_path}/#{sysid.split('/').last}"
        if ! File.exists? localdtd
          puts "Adding xml catalog resource\n\tpublic id: '#{pubid}'\n\turi: '#{sysid}'\n\tfile: '#{localdtd}'"
          if sysid =~ /^file:/
            basename = sysid.split('/').last
            dirname = last_sysid.gsub(/\/[^\/]*$/, '')
            sysid = "#{dirname}/#{basename}"
            puts "Using sysid relative to parent: #{sysid}"
          end

          sysid_contents = open(sysid, 'r', 0, 'User-Agent' => 'assert_valid_markup').read()
          open(localdtd, "w") {|f| f.write(sysid_contents)}
          added_to_catalog = true

          out = `xmlcatalog --noout --add 'public' '#{pubid}' 'file://#{localdtd}' '#{catalog_file}' 2>&1`
          if $? != 0
            puts out
            exit 1
          end
        end
        last_sysid = sysid
      end
    end
    if added_to_catalog
      return local_validate(xmldata, dtd_validate, catalog_path)
    else
      validation_failed = validation_output.grep(/^#{Regexp.escape(tmpfile.path)}:/)
      msg = []
      validation_failed.each do |l|
        msg << l.gsub(/^[^:]*:/, "Invalid markup: line ")
        if l =~ /^[^:]*:(\d+)/
          line = $1.to_i
          ((line - 3)..(line + 3)).each do |ln|
            msg << "\t#{ln}: #{xmldata.lines.to_a[ln-1]}"
          end
        end
      end
      return msg.join("\n")
    end
  end

  def w3c_validate(fragment, dtd_validate)
    ENV['W3C_VALIDATOR_SERVICE'] ||= 'validator.w3.org'

    validation_result = ''
    begin
      filename = File.join Dir::tmpdir, 'markup.' + Digest::MD5.hexdigest(fragment).to_s
      if ! ENV['NO_CACHE_VALIDATION']
        response = File.open filename {|f| Marshal.load(f) } unless ENV['NO_CACHE_VALIDATION'] rescue nil
      end
      if ! response
        if defined?(FakeWeb)
          old_net_connect = FakeWeb.allow_net_connect?
          FakeWeb.allow_net_connect = true
        end
        begin
          proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : OpenStruct.new
          response = Net::HTTP.Proxy(proxy.host, proxy.port).start(ENV['W3C_VALIDATOR_SERVICE']).post2('/check', "fragment=#{CGI.escape(fragment)}&output=json")
        ensure
          if defined?(FakeWeb)
            FakeWeb.allow_net_connect = old_net_connect
          end
        end
        File.open filename, 'w+' do |f| Marshal.dump response, f end
      end
      markup_is_valid = response['x-w3c-validator-status']=='Valid'
      if ! markup_is_valid
        doc = JSON.parse(response.body)
        msgs = []
        doc['messages'].each do |m|
          line = m['lastLine']
          msg = "Invalid markup: line #{line}: #{CGI.unescapeHTML(m['message'])}\n"
          ((line - 3)..(line + 3)).each do |ln|
            msg << "\t#{ln}: #{fragment.lines.to_a[ln-1]}"
          end
          msgs << msg
        end
        validation_result = msgs.join("\n")
      end
    rescue SocketError
      # if we can't reach the validator service, just let the test pass
      puts "WARNING: Could not reach w3c validator service"
    end
    return validation_result
  end
end

