#encoding: utf-8
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
require 'ostruct'

Encoding.default_external = 'UTF-8'

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

envvars = %w(
  TARGET_BUILD_DIR
  EXECUTABLE_PATH
  LIBRARY_SEARCH_PATHS
  FRAMEWORK_SEARCH_PATHS
  FRAMEWORKS_FOLDER_PATH
  SRCROOT
  FULL_PRODUCT_NAME
)

envvars.each do |var|
  Kernel.const_set(var, ENV[var])
end

require 'shellwords'
TARGET_EXECUTABLE_PATH = File.join(TARGET_BUILD_DIR, EXECUTABLE_PATH)
TARGET_FRAMEWORKS_PATH = FRAMEWORKS_FOLDER_PATH ? File.join(TARGET_BUILD_DIR, FRAMEWORKS_FOLDER_PATH) : TARGET_BUILD_DIR
FRAMEWORK_SEARCH_PATH_ARRAY = Shellwords::shellwords(FRAMEWORK_SEARCH_PATHS)
LIBRARY_SEARCH_PATH_ARRAY = Shellwords::shellwords(LIBRARY_SEARCH_PATHS)
NAME = File.basename(TARGET_EXECUTABLE_PATH, '.*')

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

TODO_DEPS = []
COPIED_DEPS = []

def extract_link_dependencies(executable)
  unless File.exist?(executable)
    warn "executable not exists: #{executable}"
    return []
  end
  deps = `otool -L #{executable}`

  lines = deps.split("\n").map(&:strip)
  lines.shift
  # lines.shift
  lines.map do |dep|
    path, compat, current = /^(.*) \(compatibility version (.*), current version (.*)\)$/.match(dep)[1..3]
    err "Failed to parse #{dep}" if path.nil?

    name = File.basename(path)

    dep = OpenStruct.new
    dep.is_self = (File.basename(path) == File.basename(executable))
    dep.executable = executable
    dep.install_name = path
    dep.current_version = current
    dep.compat_version = compat
    dep.type = path =~ /\.framework\// ? ".framework" : File.extname(path)
    dep.name = name
    dep.is_packaged = false
    dep.path = if path =~ /^@rpath/
      search_library(path)
    else
      dep.install_name
    end
    if dep.path.nil?
      nil
    else
      dep.library_path = dep.path.sub(/\.framework\/.*/, ".framework")
      dep
    end
  end.compact
end

def repackage_dependency(dep)
  return if dep.is_self or dep.path =~ /^(\/usr\/lib|\/System\/Library)/

  note "==================== Packaging #{dep.name} for #{File.basename(dep.executable)} ===================="

  FileUtils.mkdir(TARGET_FRAMEWORKS_PATH) unless Dir.exist?(TARGET_FRAMEWORKS_PATH)

  install_name = if dep.type == ".framework"
      dep.path.sub(/.*\/(.*?.framework)/, '\1')
    else
      dep.name
    end
  packaged_path = File.join(TARGET_FRAMEWORKS_PATH, install_name)

  case dep.type
  when ".dylib", ".framework"
    unless COPIED_DEPS.include?(dep.name)
      if File.exist? packaged_path
        note "#{packaged_path} already in Frameworks directory, removing"
        FileUtils.rm_rf packaged_path
      end
      note "Copying #{dep.library_path} to #{TARGET_FRAMEWORKS_PATH}"
      `rsync -av --copy-links "#{dep.library_path}" "#{TARGET_FRAMEWORKS_PATH}"`
      COPIED_DEPS << dep.name

      TODO_DEPS.concat extract_link_dependencies(packaged_path)

      FileUtils.chmod "u=rw", packaged_path
      fix_install_id(packaged_path, install_name)
    end

    unless dep.is_packaged

      cmd = "install_name_tool -change #{dep.install_name} @rpath/#{install_name} #{dep.executable}"
      note cmd
      out = `#{cmd}`
      if $? != 0
        err "install_name_tool failed with error #{$?}:\n#{out}"
      end

      dep.path = packaged_path
      dep.install_name = "@rpath/#{install_name}"
      dep.is_packaged = true
    end
  else
    warn "Unhandled type #{dep.type} for #{dep.path}, ignoring"
  end
end

def fix_install_id(path, name)
  note "Fixing #{path} install_name: @rpath/#{name}"
  cmd = "install_name_tool -id @rpath/#{name} #{path}"
  note cmd
  out = `#{cmd}`
  if $? != 0
    err "install_name_tool failed with error #{$?}:\n#{out}"
  end
end

TODO_DEPS.concat extract_link_dependencies(TARGET_EXECUTABLE_PATH)
while (dep = TODO_DEPS.shift) do
  repackage_dependency dep
end

note "Packaging done"
exit 0
