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
    gem.add_dependency "json"
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


task :changelog do

  changelog_file = 'CHANGELOG'
  entries = ""

  # Get a list of current tags
  tags = `git tag -l`.split

  # If we already have a changelog, make the last tag be the
  # last one in the changelog, and the next one be the one
  # following that in the tag list
  if File.exist?(changelog_file)
    entries = File.read(changelog_file)
    head = entries.split.first
    if head =~ /\d\.\d\.\d/
      last_tag = "v#{head}"
      idx = tags.index(last_tag)
      current_tag = tags[idx + 1]
    end
  end

  # Figure out last/current tags and do some validation
  last_tag ||= tags[-2]
  current_tag ||= tags[-1]

  if last_tag.nil? && current_tag.nil?
    puts "Cannot generate a changelog without first tagging your repository"
    puts "Tags should be in the form vN.N.N"
    exit
  end

  if last_tag == current_tag
    puts "Nothing to do for equal revisions: #{last_tag}..#{current_tag}"
    exit
  end


  # Generate changelog from repo
  log=`git log --pretty='format:%s <%h> [%cn]' #{last_tag}..#{current_tag}`

  # Strip out maintenance entries
  log = log.to_a.delete_if {|l| l =~ /^Regenerated gemspec/ || l =~ /^Version bump/ || l =~ /^Updated changelog/ }

  # Write out changelog file
  File.open(changelog_file, 'w') do |out|
    out.puts current_tag.gsub(/^v/, '')
    out.puts "-----"
    out.puts "\n"
    out.puts log
    out.puts "\n"
    out.puts entries
  end

  # Commit and push
  sh "git ci -m'Updated changelog' #{changelog_file}"
  sh "git push"
end

task :my_release => ['release', 'changelog', 'gemcutter:release'] do
end

