cask "office-check-in-local" do
  version "0.1.0"
  sha256 :no_check

  url "file://#{File.expand_path("../dist/OfficeCheckIn-#{version}.zip", __dir__)}"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
