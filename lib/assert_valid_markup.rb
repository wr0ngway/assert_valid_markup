require 'test/unit'
require 'net/http'
require 'digest/md5'

class Test::Unit::TestCase

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
    filename = File.join Dir::tmpdir, 'markup.' + MD5.md5(fragment).to_s
    begin
      response = File.open filename do |f| Marshal.load(f) end
  	rescue
  	  response = Net::HTTP.start('validator.w3.org').post2('/check', "fragment=#{CGI.escape(fragment)}&output=xml")
      File.open filename, 'w+' do |f| Marshal.dump response, f end
  	end
  	markup_is_valid = response['x-w3c-validator-status']=='Valid'
  	message = markup_is_valid ? '' :  XmlSimple.xml_in(response.body)['messages'][0]['msg'].collect{ |m| "Invalid markup: line #{m['line']}: #{CGI.unescapeHTML(m['content'])}" }.join("\n")
  	assert markup_is_valid, message
  end
  
  # Class-level method to quickly create validation tests for a bunch of actions at once.
  # For example, if you have a FooController with three actions, just add one line to foo_controller_test.rb:
  #
  #   assert_valid_markup :bar, :baz, :qux
  #
  def self.assert_valid_markup(*actions)
    actions.each do |action|
      class_eval <<-EOF
        def test_#{action}_valid_markup
          get :#{action}
          assert_valid_markup
        end
      EOF
    end
  end
  
end