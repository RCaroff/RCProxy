#
# Be sure to run `pod lib lint RCProxy.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RCProxy'
  s.version          = '3.1.0'
  s.summary          = 'A lightweight inapp HTTP requests logger for your iOS and tvOS apps.'
  s.swift_version    = '5.0'
# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
RCProxy will log all your HTTP requests inapp, with an expand / collapse JSON UI that will make debug even more easy. No more external proxy needed, you can implement it with only two lines of code. You will also be able to share curl requests and json responses easily. Your requests can be stored in a long-life database (for logging background requests for example), or just for a user session.
                       DESC

  s.homepage         = 'https://github.com/RCaroff/RCProxy'
  s.screenshots     = 'https://github.com/user-attachments/assets/4f473b6c-cc93-4aaa-a50b-9cca4fb34b9f', 'https://github.com/user-attachments/assets/29b548ec-75bc-454a-9896-c6fa68bdf6c4'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'RCaroff' => 'rcaroff@icloud.com' }
  s.source           = { :git => 'https://github.com/RCaroff/RCProxy.git', :tag => s.version }

  s.ios.deployment_target = '15.0'
  s.tvos.deployment_target = '15.0'

  s.source_files = 'Sources/**/*.swift'
  s.resources = "Sources/RCProxy/Resources/*.xcdatamodeld"
  s.frameworks = 'SwiftUI', 'CoreData'

end
