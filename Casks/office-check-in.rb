cask "office-check-in" do
  version "0.3.3"
  sha256 "03a6bf17474c9fa530c15875452265451c6f488793425485741d7e436bb1f73e"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v#{version}/OfficeCheckIn-#{version}.zip"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
