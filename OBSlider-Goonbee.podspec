Pod::Spec.new do |s|
  s.name          = 'OBSlider-Goonbee'
  s.version       = '1.1.1'
  s.license       = 'MIT'
  s.summary       = 'Fork of Ole Bergman\'s UISlider.'
  s.homepage      = 'https://github.com/lmirosevic/OBSlider'
  s.author        = { 'Luka Mirosevic' => 'luka@goonbee.com' }
  s.source        = { :git => 'https://github.com/lmirosevic/OBSlider.git', :tag => s.version.to_s }
  s.description   = 'OBSlider is a UISlider subclass that adds variable scrubbing speeds as seen in the Music app on iOS. While scrubbing the slider, the user can slow down the scrubbing speed by moving the finger up or down (away from the slider). The distance thresholds and slowdown factors can be freely configured by the developer.'
  s.platform      = :ios, '5.0'
  s.source_files  = 'OBSlider/**/*.{h,m}'
  s.requires_arc  = true

  s.dependency 'GBToolbox'
end
