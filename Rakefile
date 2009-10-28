require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "assert_valid_markup"
    gem.summary = %Q{Fork of assert_valid_markup, sped up by using xmllint locally rather than hitting w3c service}
    gem.description = %Q{Also contains some conveniences such as a flag to clear w3c cache at runtime, and some other cleanups}
    gem.email = "wr0ngway@yahoo.com"
    gem.homepage = "http://github.com/wr0ngway/assert_valid_markup"
    gem.authors = ["Matt Conway"]
    gem.add_development_dependency "mocha"
    gem.add_development_dependency "shoulda"
    gem.add_development_dependency "activesupport"
    gem.add_dependency "xml-simple"
    gem.files =  FileList["[A-Z][A-Z]*", "init.rb", "{lib,rails}/**/*"]    
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "assert_valid_markup #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
