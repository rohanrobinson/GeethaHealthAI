#!/bin/zsh
# Regenerates the Clinical Health Records screenshots sent to App Review, plus
# the captioned PDF, into ios/AppReview/clinical-health-records-flow/.
#
#   ios/AppReview/capture-chr-flow.sh
#
# Runs on a dedicated "Geetha Health Review" simulator, created on first use,
# so no other simulator is touched. It is not erased between runs: erasing
# makes iOS redo its first-boot setup, which loads the Mac enough for taps to
# time out. The test copes with whatever state the simulator is already in.
# Takes about five minutes; pass --fresh to erase it first anyway.
set -euo pipefail
setopt null_glob  # an empty output folder is not an error

here=${0:A:h}
ios=${here:h}
out=$here/clinical-health-records-flow
device_name="Geetha Health Review"
bundle_id=com.geethahealth.GeethaHealth

udid=$(xcrun simctl list devices | grep -F "$device_name (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
if [[ -z $udid ]]; then
  udid=$(xcrun simctl create "$device_name" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro)
fi

xcrun simctl shutdown $udid 2>/dev/null || true
[[ ${1:-} == --fresh ]] && xcrun simctl erase $udid
trap 'xcrun simctl shutdown $udid 2>/dev/null || true' EXIT
xcrun simctl boot $udid
xcrun simctl bootstatus $udid -b >/dev/null
# iOS keeps setting itself up for a while after boot, and Health can stop
# responding to taps until that settles.
sleep 60
# Health asks for location when searching providers; granting it up front
# keeps that alert out of the way of the test.
xcrun simctl privacy $udid grant location com.apple.Health

# Each test gets a fresh install: uninstalling is what resets the HealthKit
# grant, so the full permission sheet appears again.
run_test() {
  xcrun simctl uninstall $udid $bundle_id 2>/dev/null || true
  TEST_RUNNER_REVIEW_SHOTS_DIR=$out xcodebuild test -quiet \
    -project $ios/GeethaHealth.xcodeproj -scheme GeethaHealth \
    -destination "id=$udid" \
    -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600 \
    -only-testing:GeethaHealthUITests/HealthRecordsReviewScreenshots/$1
}

rm -f $out/*.png $out/*.pdf
# The test drives Apple's Health app, which now and then stops responding;
# one retry from a clean install gets past that.
for test in testCaptureGrantFlow testCaptureDeclinePath; do
  run_test $test || { echo "$test failed; retrying once"; run_test $test; }
done

swift $here/make-pdf.swift $out/GeethaHealth-CHR-Flow.pdf $here/captions.txt $out/*.png
echo "Wrote $(ls $out/*.png | wc -l | tr -d ' ') screenshots and GeethaHealth-CHR-Flow.pdf to $out"
