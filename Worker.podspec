Pod::Spec.new do |s|
  s.name         = "Worker"
  s.version      = "0.1"
  s.summary      = ""
  s.description  = <<-DESC
    Your description here.
  DESC
  s.homepage     = "https://uberbruns@github.com/uberbruns/Worker"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Karsten Bruns" => "karsten@bruns.me" }
  s.social_media_url   = ""
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://uberbruns@github.com/uberbruns/Worker.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
end
