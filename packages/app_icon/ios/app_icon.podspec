Pod::Spec.new do |s|
  s.name             = 'app_icon'
  s.version          = '0.0.1'
  s.summary          = 'Switches the iOS home-screen icon.'
  s.homepage         = 'https://github.com/gillsaab786/torrent-search-engine-ipa'
  s.license          = { :type => 'MIT' }
  s.author           = { 'gillsaab786' => 'noreply@github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
end
