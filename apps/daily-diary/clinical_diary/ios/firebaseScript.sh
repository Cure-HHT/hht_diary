if [ "$CONFIGURATION" == "Debug-dev" ] || [ "$CONFIGURATION" == "Release-dev" ]; then
  cp Runner/dev/GoogleService-Info.plist Runner/GoogleService-Info.plist
elif [ "$CONFIGURATION" == "Debug-test" ] || [ "$CONFIGURATION" == "Release-test" ]; then
  cp Runner/test/GoogleService-Info.plist Runner/GoogleService-Info.plist
elif [ "$CONFIGURATION" == "Debug-uat" ] || [ "$CONFIGURATION" == "Release-uat" ]; then
  cp Runner/uat/GoogleService-Info.plist Runner/GoogleService-Info.plist
elif [ "$CONFIGURATION" == "Debug-prod" ] || [ "$CONFIGURATION" == "Release-prod" ]; then
  cp Runner/prod/GoogleService-Info.plist Runner/GoogleService-Info.plist
fi

