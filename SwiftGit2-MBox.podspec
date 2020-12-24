Pod::Spec.new do |spec|
  spec.name         = "SwiftGit2-MBox"
  spec.module_name  = "SwiftGit2"
  spec.version      = "1.0.1"
  spec.summary      = "SwiftGit2 for MBox."
  spec.description  = <<-DESC
  A fork from SwiftGit2 and develop for MBox
                   DESC

  spec.homepage     = "https://github.com/MBoxSpace/SwiftGit2"
  spec.license      = "MIT"
  spec.author             = { "Whirlwind James" => "whirlwindjames@foxmail.com" }
  spec.platform     = :macos, "10.15"
  spec.source       = { :git => "https://github.com/MBoxSpace/SwiftGit2.git", :tag => "v#{spec.version}" }
  spec.swift_versions = "5.3.2"
  spec.source_files  = "libSSH2/*.swift", "SwiftGit2/*.{swift,h,m}", "SwiftGit2/**/*.swift"
  spec.vendored_libraries = "External/output/*/lib/*.dylib"
  spec.vendored_frameworks = "External/output/libgit2/git2.framework"
end
