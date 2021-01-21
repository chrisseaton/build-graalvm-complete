#!/usr/bin/env ruby

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
    path_extra = '/Contents/Home'
  else
    path_extra = ''
  end

  if tarball.include?('java8')
    jre_extra = '/jre'
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

  setup_commands = []

  phase1.each do |i|
    puts "Installing #{i}..."
    system "#{complete}#{path_extra}/bin/gu", 'install', '-L', i, exception: true

    case i
    when /espresso-.*/
      rebuildable = 'java'
      # When rebuilding with espresso we need to add it to the classpath manually, according to post-install instructions
      rebuild_extra.push '-cp', "#{complete}#{path_extra}#{jre_extra}/lib/graalvm/lib-espresso.jar"
    when /llvm-.*/
      rebuildable = 'llvm'
    when /python-.*/
      rebuildable = 'python'
    when /ruby-.*/
      # Ruby has a post-install hook according to the post-install instructions
      setup_commands.push "`dirname \"$0\"`#{jre_extra}/languages/ruby/lib/truffle/post_install_hook.sh"
      rebuildable = 'ruby'
    else
      rebuildable = nil
    end

    rebuildables.push rebuildable if rebuildable
  end

  if installables.any? { |i| i =~ /native-image-*./ }
    rebuildables.each do |r|
      puts "Rebuilding #{r}"
      case r
      when 'java'
        # https://github.com/oracle/graal/issues/3134#issuecomment-763599584
        system "#{complete}#{path_extra}/bin/native-image", '--macro:espresso-library', *rebuild_extra, exception: true
      else
        system "#{complete}#{path_extra}/bin/gu", 'rebuild-images', r, *rebuild_extra, exception: true
      end
    end
  end

  phase2.each do |i|
    puts "Installing #{i}..."
    system "#{complete}#{path_extra}/bin/gu", 'install', '-L', i, exception: true
  end

  Dir.glob('*.zip') do |zip|
    puts "Extracting #{zip}..."
    system 'unzip', zip, '-d', "#{complete}#{path_extra}"
  end

  setup_file = "#{complete}#{path_extra}/setup.sh"
  File.open(setup_file, 'w') do |setup|
    setup.puts '#!/usr/bin/env bash'
    setup.puts 'set -euxo pipefail'
    if setup_commands.empty?
      # So people aren't confused by nothing appears to be done
      setup.push 'Done!'
    else
      setup_commands.each do |c|
        setup.puts c
      end
    end
  end
  FileUtils.chmod('+x', setup_file)

  system 'tar', '-zcf', "../#{complete}.tar.gz", complete, exception: true
end
