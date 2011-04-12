#!/usr/bin/env ruby
# encoding: utf-8

# Codesign Introspection
# Evadne Wu at Iridia Productions, 2011

# usage: codesign-introspect <an IPA package or an .app>

require 'optparse'
require 'pp'
require 'pathname'
require 'fileutils'
require 'etc.so'
require 'tmpdir'
require 'rubygems'
require 'zip/zip'
require 'find'
require 'plist'
require 'open3'
require 'json'


CI = {}
CI[:verbose] = false
CI[:usesJSONOutput] = false
# CI[:temporaryPathNames] = []
CI[:temporaryDirectory] = Dir.mktmpdir
CI[:errors] = []
CI[:results] = {}

CITemporaryUnzippedRepresentationOfFile = lambda { |aPathName| 
	
		destination = nil	
		tempDirectory = CI[:temporaryDirectory]

		destination = File.absolute_path(aPathName.basename(), tempDirectory)
		# puts "Unzipping contents of path #{aPathName} to tempDirectory #{tempDirectory} destination #{destination}"
		
		Zip::ZipFile.open(aPathName) { |zipFile| zipFile.each { |file|
			
			filePath = File.join(destination, file.name)
			FileUtils.mkdir_p(File.dirname(filePath))
			zipFile.extract(file, filePath) unless File.exist?(filePath)

		}}
	
		returnedPathName = Pathname.new(destination)
		return returnedPathName
	
}










(OptionParser.new { |options|

	options.banner = "Usage: codesign-introspection <options> <path to an .ipa or .app package> \n "
	options.on('-v', '--verbose', 'Outputs more information') { CI[:verbose] = true }
	options.on('--[no-]json', 'Toggles between JSON and ordinary output — defaults to line-by-line, but JSON output is more descriptive.') { |usesJSONOutput| CI[:usesJSONOutput] = usesJSONOutput }

}).parse!

ARGV.each { |aPath|
	
	results = { :errors => [] };
	
	operatedFile = (Pathname.new(aPath))
	operatedPackage = nil
	fileExtensionString = operatedFile.extname.to_s

	fileExists = operatedFile.exist?
	raise "File #{aPath} => #{operatedFile} does not even exist." unless fileExists

	fileAcceptable = !!(/^\.(ipa|app)$/i =~ fileExtensionString)
	raise "File #{aPath} => #{operatedFile} is not recognized." unless fileAcceptable
	
	fileIsPackage = !!(/^\.ipa$/i =~ fileExtensionString)	
	if fileIsPackage
		
		operatedPackage = CITemporaryUnzippedRepresentationOfFile.call(operatedFile)
		operatedFile = Pathname.new(Dir.glob(File.join(operatedPackage.realpath(), "Payload", "*.app"))[0])		
		
	end
	
	results[:entitlements] = Dir.mktmpdir { |tempDirectory|
		
		returnedEntitlements = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
		
		Open3.popen3("codesign -dvvvv --entitlements - \"#{operatedFile.realpath().to_s}\"") {|stdin, stdout, stderr, wait_thr|

			startPushing = false
			
			stdout.each { |line| 
				
				startPushing = line.start_with? "<!DOCTYPE" if (!startPushing)
				returnedEntitlements.push(line) if startPushing
				
			} 
			
		}
		
		Plist::parse_xml(returnedEntitlements.join(""))

	}
	
	unless ["production", "development"].include? results[:entitlements]["aps-environment"]
	results[:errors].push("Bad entitlements.  No aps-environment entitlement string found in package.  Make sure that Entitlements.plist exists for your build configuration, and aps-environment is correctly configured for the application."); end
	
	CI[:results][aPath] = results;

}





FileUtils.remove_entry_secure CI[:temporaryDirectory]

if (CI[:usesJSONOutput])

	puts CI[:results].to_json

else
	
	CI[:results].each { |aPath, theResults| 
		
		puts "File: #{aPath}"
		theResults[:errors].each { |errorString| puts "Error: #{errorString}" }
		
	}
	
end


exit (CI[:errors].empty? ? 0 : 1)





