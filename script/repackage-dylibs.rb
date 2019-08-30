#!/usr/bin/ruby

# This script looks up an executable's list of shared libraries, copies
# non-standard ones (ie. anything not under /usr or /System/) into the target's
# bundle and updates the executable install_name to point to the "packaged"
# version.

# Usage:
# Add the script as a Run Script build phase in the target using Xcode.

# FIXMEs:
# - only handles dylibs
# - only tested against a framework target
# - doesn't care about codesigning


require 'fileutils'

def err(msg)
  puts "error: " + msg
  exit 1
end

def warn(msg)
  puts "warning: " + msg
end

def note(msg)
  puts msg
end

def exec(command)
  note(command)
  out = `#{command}`
  err "command failed!" if $? != 0
  out
end

envvars = %w(
  TARGET_BUILD_DIR
  EXECUTABLE_PATH
  LIBRARY_SEARCH_PATHS
  FRAMEWORK_SEARCH_PATHS
  FRAMEWORKS_FOLDER_PATH
  SRCROOT
  INFOPLIST_PATH
)

envvars.each do |var|
  Kernel.const_set(var, ENV[var])
end

require 'shellwords'
TARGET_EXECUTABLE_PATH = File.join(TARGET_BUILD_DIR, EXECUTABLE_PATH)
TARGET_FRAMEWORKS_PATH = FRAMEWORKS_FOLDER_PATH ? File.join(TARGET_BUILD_DIR, FRAMEWORKS_FOLDER_PATH) : TARGET_BUILD_DIR
FRAMEWORK_SEARCH_PATH_ARRAY = Shellwords::shellwords(FRAMEWORK_SEARCH_PATHS)
LIBRARY_SEARCH_PATH_ARRAY = Shellwords::shellwords(LIBRARY_SEARCH_PATHS)

def search_library(name)
  name = name.sub("@rpath/", '')
  is_framework = name =~ /\.framework\//
  paths = is_framework ? FRAMEWORK_SEARCH_PATH_ARRAY : LIBRARY_SEARCH_PATH_ARRAY
  paths.each do |path|
    path = File.join(SRCROOT, path) if File.absolute_path(path) != path
    path = File.join(path, name)
    return path if File.exists?(path)
  end
  return nil
end

def extract_link_dependencies(executable)
  puts "extract_link_dependencies: #{executable}"
  unless File.exist?(executable)
    warn "executable not exists: #{executable}"
    return []
  end
  deps = `otool -L #{executable}`

  lines = deps.split("\n").map(&:strip)
  lines.shift
  lines.shift
  lines.map do |dep|
    path, compat, current = /^(.*) \(compatibility version (.*), current version (.*)\)$/.match(dep)[1..3]
    err "Failed to parse #{dep}" if path.nil?
    path = search_library(path) if path =~ /^@rpath\//

    if path.nil? || path =~ /^(\/usr\/lib|\/System\/Library)/ 
      nil
    else
      note "Found link: #{path}"
      path
    end
  end.compact
end

def link_name(path)
  if path =~ /([^\/]+\.framework\/)(Versions\/[^\/]*\/)([^\/]*)$/
    "#{$1}#{$3}"
  elsif path =~ /([^\/]+\.framework\/)([^\/]*)$/
    "#{$1}#{$2}"
  elsif path =~ /([^\/]*)$/
    $1
  else
    path
  end
end

def change_link_path(executable, path)
  name = link_name(path)
  exec("install_name_tool -change #{path} @rpath/#{name} '#{executable}'")
  name
end

def fix_install_id(executable)
  name = link_name(executable)    
  exec("install_name_tool -id @rpath/#{name} '#{executable}'")
  name
end

def copy_dylib(path)
  path = path.sub(/\.framework\/.*/, ".framework")
  packaged_path = File.join(TARGET_FRAMEWORKS_PATH, File.basename(path))

  if File.exist? packaged_path
    note "#{packaged_path} already in Frameworks directory, removing"
    FileUtils.rm_rf packaged_path
  end

  note "Copying #{path} to #{TARGET_FRAMEWORKS_PATH}"
  FileUtils.mkdir(TARGET_FRAMEWORKS_PATH) unless Dir.exist?(TARGET_FRAMEWORKS_PATH)
  FileUtils.cp_r path, TARGET_FRAMEWORKS_PATH
  FileUtils.chmod "u=rw", packaged_path
  packaged_path
end

paths = [TARGET_EXECUTABLE_PATH]


ALL_DEPS = []
def parse(executable)
  paths = extract_link_dependencies(executable)
  paths.select! do |path|
    name = change_link_path(executable, path)
    if ALL_DEPS.include?(File.basename(executable))
      false
    else
      ALL_DEPS << File.basename(executable)
      true
    end
  end

  paths.each do |path|
    note "================ #{File.basename(path)} ================"
    path = copy_dylib(path)
    fix_install_id(path)
    parse(path)
  end
end

note "================ #{File.basename(TARGET_EXECUTABLE_PATH)} ================"
parse(TARGET_EXECUTABLE_PATH)

note "Packaging done"
exit 0
