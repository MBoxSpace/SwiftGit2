Pod::Spec.new do |spec|
  spec.name         = "SwiftGit2-MBox"
  spec.version      = "0.0.1"
  spec.summary      = "SwiftGit2 for MBox."
  spec.description  = <<-DESC
  A fork from SwiftGit2 and develop for MBox
                   DESC

  spec.homepage     = "https://github.com/dijkst/SwiftGit2-MBox"
  spec.license      = "MIT"
  spec.author             = { "Whirlwind James" => "whirlwindjames@foxmail.com" }
  spec.platform     = :macos, "10.15"
  spec.source       = { :git => "https://github.com/dijkst/SwiftGit2-MBox.git", :tag => "#{spec.version}" }
  spec.swift_versions = "5.3.2"
  spec.source_files  = "libSSH2/*.swift", "SwiftGit2/*.{swift,h,m}", "SwiftGit2/**/*.swift"
  spec.vendored_libraries = "External/output/*/lib/*.dylib"
  spec.vendored_frameworks = "External/output/libgit2/git2.framework"
end
