require 'test/unit'
require 'net/http'
require 'digest/md5'
require 'open-uri'
require 'FileUtils'

class Test::Unit::TestCase
  
  @@catalog_path = File.expand_path("~/.xml-catalogs")
  @@use_local_validation = system("xmllint --version > /dev/null 2>&1")
  
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
  def assert_valid_markup(fragment=@response.body)
    if  @@use_local_validation
      result = local_validate(fragment) 
      assert result.empty?, result.collect {|l| l.gsub(/^[^:]*:/, "Invalid markup: line ")}.join("\n")
    else
      begin
        filename = File.join Dir::tmpdir, 'markup.' + Digest::MD5.hexdigest(fragment).to_s
        begin
          response = File.open filename do |f| Marshal.load(f) end
      	rescue
      	  response = Net::HTTP.start('validator.w3.org').post2('/check', "fragment=#{CGI.escape(fragment)}&output=xml")
          File.open filename, 'w+' do |f| Marshal.dump response, f end
      	end
      	markup_is_valid = response['x-w3c-validator-status']=='Valid'
      	message = markup_is_valid ? '' :  XmlSimple.xml_in(response.body)['messages'][0]['msg'].collect{ |m| "Invalid markup: line #{m['line']}: #{CGI.unescapeHTML(m['content'])}" }.join("\n")
      	assert markup_is_valid, message
      rescue SocketError
        # if we can't reach the validator service, just let the test pass
        assert true
      end
    end
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

  def local_validate(xmldata)
    catalog_file = "#{@@catalog_path}/catalog"
    if ! File.exists? @@catalog_path
      puts "Creating xml catalog at: #{@@catalog_path}"
      FileUtils.mkdir_p(@@catalog_path)
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
    validation_output = `xmllint --catalogs --memory --noout --valid #{tmpfile.path} 2>&1`
    ENV.delete("XML_DEBUG_CATALOG")

    validation_output.each do |line|
      line.chomp!
      if match = line.match(/Resolve: pubID (.*) sysID (.*)/)
        pubid = match[1]
        sysid = match[2]
        localdtd = "#{@@catalog_path}/#{sysid.split('/').last}"
        if ! File.exists? localdtd
          puts "Adding xml catalog resource\n\tpublic id: '#{pubid}'\n\turi: '#{sysid}'\n\tfile: '#{localdtd}'"
          open(localdtd, "w") {|f| f.write(open(sysid).read())}
          out = `xmlcatalog --noout --add 'public' '#{pubid}' 'file:/#{localdtd}' '#{catalog_file}' 2>&1`
          if $? != 0
            puts out
            exit 1
          end
        end
      end
    end
    validation_failed = validation_output.grep(/^#{Regexp.escape(tmpfile.path)}:/)
    return validation_failed
  end
  
end