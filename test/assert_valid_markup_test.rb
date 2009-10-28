require 'test_helper'
require "active_support/core_ext/module"

class DummyControllerTestCase < Test::Unit::TestCase
  def get(body, html, success)
    @request = stub(:format => stub(:html? => html))
    @response = stub(:body => "#{body}", :success? => success)
  end
end

class AssertValidMarkupTest < Test::Unit::TestCase

  VALID = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en"><head><title></title></head><body></body></html>'
  INVALID = '<foo>'

  def teardown
    Object.constants.grep(/^DummyMarkup/).each do |c|
      Object.send(:remove_const, c)
    end
  end


  should "validate markup on simple test" do

    eval <<-CLAZZ
      class ::DummyMarkupTest < Test::Unit::TestCase
        def test_foo
          assert_valid_markup('#{VALID}', :validation_service => :local)
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    DummyMarkupTest.new('test_foo').run(result, &lambda {} )
    assert_equal 1, result.run_count
    assert_equal 1, result.assertion_count
    assert result.passed?
  end

  should "fail to validate for bad markup" do

    eval <<-CLAZZ
      class ::DummyMarkupTest < Test::Unit::TestCase
        def test_foo
          assert_valid_markup('#{INVALID}', :validation_service => :local)
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    DummyMarkupTest.new('test_foo').run(result, &lambda {} )
    assert_equal 1, result.run_count
    assert_equal 1, result.assertion_count
    assert ! result.passed?
  end

  should "validate for action controller response" do
    eval <<-CLAZZ
      class ::DummyMarkupTest < Test::Unit::TestCase
        def test_foo
          @response = mock(:body => '#{VALID}')
          assert_valid_markup
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    DummyMarkupTest.new('test_foo').run(result, &lambda {} )
    assert_equal 1, result.run_count
    assert result.passed?
  end

  should "validate with web service if no xmllint" do

    eval <<-CLAZZ
      class ::DummyMarkupTest < Test::Unit::TestCase
        def test_foo
          assert_valid_markup('#{VALID}', :validation_service => :w3c)
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    DummyMarkupTest.new('test_foo').run(result, &lambda {} )
    assert_equal 1, result.run_count
    assert_equal 1, result.assertion_count
    assert result.passed?
  end

  should "fail validation with web service if no xmllint" do

    eval <<-CLAZZ
      class ::DummyMarkupTest < Test::Unit::TestCase
        def test_foo
          assert_valid_markup('#{INVALID}', :validation_service => :w3c)
         end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    DummyMarkupTest.new('test_foo').run(result, &lambda {} )
    assert_equal 1, result.run_count
    assert_equal 1, result.assertion_count
    assert ! result.passed?
  end

  should "validate action controller tests that call get" do
    eval <<-CLAZZ
      class ::DummyMarkupControllerTest < DummyControllerTestCase
        assert_all_valid_markup

        def test_foo
          get(VALID, true, true)
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    tc = DummyMarkupControllerTest.new('test_foo')
    tc.run(result, &lambda {} )
    assert_equal 1, result.run_count
    assert result.passed?
  end

  should "validate all action controller tests that call get" do
    eval <<-CLAZZ
      class ::DummyMarkupControllerTest < DummyControllerTestCase
        assert_all_valid_markup

        def test_foo
          get(INVALID, true, true)
        end

        def test_bar
          get(INVALID, true, true)
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    tc = DummyMarkupControllerTest.suite
    tc.run(result, &lambda {} )
    assert_equal 2, result.run_count
    assert_equal 2, result.failure_count
    assert ! result.passed?
  end

  should "not validate action controller tests that call get with failure or non-html or skip" do
    eval <<-CLAZZ
      class ::DummyMarkupControllerTest < DummyControllerTestCase
        assert_all_valid_markup

        def test_foo
          get(INVALID, true, false)
        end

        def test_bar
          get(INVALID, false, true)
        end

        def test_baz
          skip_markup_validation do
            get(INVALID, true, true)
          end
        end
      end
    CLAZZ

    result = Test::Unit::TestResult.new
    tc = DummyMarkupControllerTest.suite
    tc.run(result, &lambda {} )
    p result
    assert_equal 3, result.run_count
    assert_equal 0, result.failure_count
    assert result.passed?
  end

end
