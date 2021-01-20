#!/usr/bin/env ruby

# The purpose of this script is to build a 'complete' GraalVM. That is a build
# of GraalVM with everything installed an all native-images rebuilt to include
# all the languages.

# You should have a directory called something like
# graalvm-ce-java8-darwin-amd64-21.0.0 that contains the tarball and whatever
# installables and other tools you want. You need to download these yourself.
# For example:

#   % ls graalvm-ce-java8-darwin-amd64-21.0.0/*
#   graalvm-ce-java8-darwin-amd64-21.0.0/c1visualizer-1.7.zip
#   graalvm-ce-java8-darwin-amd64-21.0.0/espresso-installable-java8-darwin-amd64-21.0.0.jar
#   graalvm-ce-java8-darwin-amd64-21.0.0/graalvm-ce-java8-darwin-amd64-21.0.0.tar.gz
#   graalvm-ce-java8-darwin-amd64-21.0.0/llvm-toolchain-installable-java8-darwin-amd64-21.0.0.jar
#   graalvm-ce-java8-darwin-amd64-21.0.0/native-image-installable-svm-java8-darwin-amd64-21.0.0.jar
#   graalvm-ce-java8-darwin-amd64-21.0.0/python-installable-svm-java8-darwin-amd64-21.0.0.jar
#   graalvm-ce-java8-darwin-amd64-21.0.0/ruby-installable-svm-java8-darwin-amd64-21.0.0.jar
#   graalvm-ce-java8-darwin-amd64-21.0.0/wasm-installable-svm-java8-darwin-amd64-21.0.0.jar

# Then run this tool. This will probbaly take a very long time to run as it's
# compiling the universe multiple times.

#   % ruby build-graalvm-complete/build-graalvm-complete.rb graalvm-ce-java8-darwin-amd64-21.0.0
#   ...

# Now you'll have a complete tarball with all installables installed, and all
# native images rebuilt.

#   % du -h graalvm-ce-java8-darwin-amd64-21.0.0-complete.tar.gz
#   784M	graalvm-ce-java8-darwin-amd64-21.0.0-complete.tar.gz
#   % tar -zxf graalvm-ce-java8-darwin-amd64-21.0.0-complete.tar.gz
#   % ./graalvm-ce-java8-darwin-amd64-21.0.0-complete/Contents/Home/bin/polyglot --version:graalvm
#   GraalVM CE Native Polyglot Engine Version 21.0.0
#   Java Version 1.8.0_282
#   Java VM Version GraalVM 21.0.0 Java 8 CE
#   GraalVM Home .../graalvm-ce-java8-darwin-amd64-21.0.0-complete/Contents/Home
#     Installed Languages:
#       Java       version 1.8|11
#       JavaScript version 21.0.0
#       LLVM       version 10.0.0
#       Python     version 3.8.5
#       Ruby       version 2.7.2
#   ...

# Check you understand the licences before you use or redistribute it! I think
# you should not make it available publicly, but not I'm not a lawyer.

# MIT licence. By Chris Seaton.

require 'fileutils'

dir, *rest = ARGV
raise 'expecting a directory containing the GraalVM tarball and installables' if dir.nil?
raise 'not expecting more arguments than a directory' unless rest.empty?

Dir.chdir(dir) do
  tarball, *rest = Dir.glob('graalvm-*.tar.gz')
  raise 'could not find the tarball' if tarball.nil?
  raise 'multiple tarballs found' unless rest.empty?

  puts "Extracting #{tarball}..."
  system 'tar', '-zxf', tarball, exception: true

  extracted, *rest = Dir.glob('graalvm-*').filter { |d| File.directory?(d) }
  raise 'could not find the extracted directory' if extracted.nil?
  raise 'multiple extracted directories found' unless rest.empty?

  complete = "#{File.basename(dir)}-complete"
  FileUtils.mv extracted, complete

  if RUBY_PLATFORM.include?('darwin')
    puts 'Need sudo for xattr:'
    system 'sudo', 'xattr', '-r', '-d', 'com.apple.quarantine', complete, exception: true
    path_extra = 'Contents/Home/'
  else
    path_extra = ''
  end

  if tarball.include?('java8')
    jre_extra = 'jre/'
  else
    jre_extra = ''
  end

  installables = Dir.glob('*.jar')

  # native-image and llvm need to be installed before some languages
  installables.sort_by! do |x|
    case x
    when /native-image-*./
      "0-#{x}"
    when /llvm-*./
      "1-#{x}"
    else x
    end
  end

  rebuildables = ['polyglot', 'libpolyglot']
  rebuild_extra = []

  # phase1 installables can go into native images, phase2 installables cannot,
  # so they must be installed after native images are rebuilt
  phase2, phase1 = installables.partition do |i|
    # https://github.com/oracle/graal/issues/3135
    i =~ /wasm-.*/
  end

  phase1.each do |i|
    puts "Installing #{i}..."
    system "#{complete}/#{path_extra}bin/gu", 'install', '-L', i, exception: true

    case i
    when /espresso-.*/
      rebuildable = 'java'
      # When rebuilding with espresso we need to add it to the classpath manually, according to post-install instructions
      rebuild_extra.push '-cp', "#{complete}/#{path_extra}#{jre_extra}/lib/graalvm/lib-espresso.jar"
    when /llvm-.*/
      rebuildable = 'llvm'
    when /python-.*/
      rebuildable = 'python'
    when /ruby-.*/
      # Ruby has a post-install hook according to the post-install instructions
      puts 'Rebuilding Ruby C extensions...'
      system "#{complete}/#{path_extra}#{jre_extra}/languages/ruby/lib/truffle/post_install_hook.sh", exception: true
      rebuildable = 'ruby'
    else
      rebuildable = nil
    end

    rebuildables.push rebuildable if rebuildable
  end

  rebuildables.each do |r|
    puts "Rebuilding #{r}"
    case r
    when 'java'
      # https://github.com/oracle/graal/issues/3134#issuecomment-763599584
      system "#{complete}/#{path_extra}bin/native-image", '--macro:espresso-library', *rebuild_extra, exception: true
    else
      system "#{complete}/#{path_extra}bin/gu", 'rebuild-images', r, *rebuild_extra, exception: true
    end
  end

  phase2.each do |i|
    puts "Installing #{i}..."
    system "#{complete}/#{path_extra}bin/gu", 'install', '-L', i, exception: true
  end

  Dir.glob('*.zip') do |zip|
    puts "Extracting #{zip}..."
    system 'unzip', zip, '-d', complete
  end

  system 'tar', '-zcf', "../#{complete}.tar.gz", complete, exception: true
end
