# IRCodeSignatureIntrospection

Introspect code signature embedded in an IPA package so you know that your submission works correctly with APNs before it fails in the field.  Evadne Wu at Iridia, 2011.  Code is under the new BSD license.


## Using `codesign-introspection` from the Terminal

	$ codesign-introspection.rb myPackage.ipa
	$ codesign-introspection.rb myPackage.ipa --json | myOtherScript

	
## Using `codesign-introspection` from Xcode

**Don’t** run this script as a Run Script Build Phase in your app’s target, because code signing happens *after* all the work in the target has finished.  Instead, roll an aggregate target, and on your own, call `xcodebuild` into your project again, on the target that builds the app.  Then, invoke the script as if you would invoke it from the terminal.
